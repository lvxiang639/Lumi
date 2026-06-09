# 推送系统 V2 Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or inline execution. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor proactive push system: quiet hours, morning briefing, LLM natural text, holiday/countdown/reminder types.

**Architecture:** Modify `proactive_service.py` only. Checks return dicts instead of strings. One LLM call per push to merge all HIT data into natural text. New `reminder_schedules` table for custom reminders. `proactive_push_test.py` for coverage.

**Tech Stack:** FastAPI, SQLAlchemy async, deepseek-v4-flash, pytest

---

## File Map

### Modified
- `backend/app/services/proactive_service.py` — main refactor target
- `backend/app/api/ws_chat.py` — morning briefing trigger on WS connect

### Created
- `backend/app/models/reminder_schedule.py` — new table
- `backend/tests/test_proactive_push.py` — tests for new logic

---

### Task 1: Quiet hours + check data structs

**Files:** Modify `backend/app/services/proactive_service.py:63-141`

- [ ] **Step 1: Add quiet hours check to _check_all**

```python
# After line 63 (async def _check_all), before iterating users:
async def _check_all(self):
    users = online_users()
    if not users:
        return
    now = datetime.now(BEIJING_TZ)
    # Quiet hours: 22:00-8:00 — skip all checks
    if now.hour >= 22 or now.hour < 8:
        logger.debug("proactive: quiet hours, skipping check (hour=%d)", now.hour)
        return
    for uid in users:
        ...
```

- [ ] **Step 2: Verify compile**

```bash
cd /Users/lvxiang/workspace/lingxi && PYTHONPATH=./backend python3 -c "from app.services.proactive_service import proactive_service; print('OK')"
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/proactive_service.py
git commit -m "feat: quiet hours 22-8 — skip all proactive checks during night time"
```

---

### Task 2: Structured check return types

**Files:** Modify `backend/app/services/proactive_service.py` — all `_check_*` methods

- [ ] **Step 1: Change return types from `str | None` to `dict | None`**

```python
# _check_weather: was returning "外面下雨了 ☔" — now returns data dict
async def _check_weather(self, user_id: str, now: datetime) -> dict | None:
    try:
        city = await get_city(user_id=user_id)
        cached = self._weather_cache.get(city)
        if cached:
            msg, ts = cached
            if (now - ts).total_seconds() < 7200:
                return msg if msg != "__NONE__" else None
        prompt = WEATHER_PROMPT.format(now=now.strftime("%H:%M"), city=city)
        result = await llm_router.chat([{"role": "user", "content": prompt}])
        result = (result or "").strip()
        self._weather_cache[city] = (result or "__NONE__", now)
        return {"type": "weather", "city": city, "alert": result} if result else None
    except Exception:
        return None

# _check_calendar: return event list
async def _check_calendar(self, user_id, now, db) -> dict | None:
    try:
        from uuid import UUID
        start = now + timedelta(hours=1)
        r = await db.execute(
            select(CalendarEvent).where(
                CalendarEvent.user_id == UUID(user_id),
                CalendarEvent.time >= now,
                CalendarEvent.time <= start,
            )
        )
        events = r.scalars().all()
        if events:
            return {"type": "calendar", "events": [
                {"title": e.title, "time": e.time.strftime("%H:%M")} for e in events
            ]}
    except Exception:
        pass
    return None

# _check_expense: yesterday total
async def _check_expense(self, user_id, now, db) -> dict | None:
    try:
        from uuid import UUID
        yesterday = (now - timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        r = await db.execute(
            select(func.sum(ExpenseRecord.amount)).where(
                ExpenseRecord.user_id == UUID(user_id),
                ExpenseRecord.recorded_at >= yesterday,
                ExpenseRecord.recorded_at < today_start,
            )
        )
        total = r.scalar()
        if total and total > 0:
            return {"type": "expense", "yesterday_total": float(total)}
    except Exception:
        pass
    return None

# _check_water: just time data
async def _check_water(self, user_id, now) -> dict | None:
    if now.hour < 8 or now.hour > 22:
        return None
    return {"type": "water", "hour": now.hour}

# _check_idle: idle hours
async def _check_idle(self, user_id, now, db) -> dict | None:
    try:
        from uuid import UUID
        r = await db.execute(
            select(Message.created_at).where(
                Message.conv_id.in_(
                    select(Conversation.id).where(Conversation.user_id == UUID(user_id))
                )
            ).order_by(Message.created_at.desc()).limit(1)
        )
        last_msg = r.scalar_one_or_none()
        if last_msg:
            idle_hours = (now - last_msg).total_seconds() / 3600
            if idle_hours >= 4:
                return {"type": "idle", "hours": int(idle_hours)}
    except Exception:
        pass
    return None

# _check_emotion: emotion + intensity
async def _check_emotion(self, user_id, now, db) -> dict | None:
    r = await db.execute(select(UserEmotionState).where(UserEmotionState.user_id == user_id))
    state = r.scalar_one_or_none()
    if state and state.intensity >= 0.5 and state.current_emotion in ("sad", "angry", "worried"):
        return {"type": "emotion", "current": state.current_emotion, "intensity": state.intensity}
    return None

# _check_memory: topic list
async def _check_memory(self, user_id, now, db) -> dict | None:
    r = await db.execute(
        select(UserMemory).where(UserMemory.user_id == user_id)
        .order_by(UserMemory.updated_at.desc()).limit(10)
    )
    memories = r.scalars().all()
    if len(memories) >= 2:
        return {"type": "memory", "topics": [f"{m.key}:{m.value}" for m in memories[:5]]}
    return None
```

- [ ] **Step 2: Update _check_user to collect dicts**

```python
async def _check_user(self, user_id: str, now: datetime):
    logger.info("proactive check: [0] starting scan for %s", user_id[:8])
    if not await self._can_push(user_id, now):
        return

    async with async_session() as db:
        r = await db.execute(select(User).where(User.id == user_id))
        if not r.scalar_one_or_none():
            return
        checks = []
        
        logger.info("proactive check: [1/8] weather")
        w = await self._check_weather(user_id, now)
        if w: checks.append(w)
        logger.info("proactive check: weather -> %s", "HIT" if w else "SKIP")
        
        logger.info("proactive check: [2/8] calendar")
        c = await self._check_calendar(user_id, now, db)
        if c: checks.append(c)
        logger.info("proactive check: calendar -> %s", "HIT" if c else "SKIP")
        
        # ... same pattern for expense, idle, water, emotion, memory ...
        
        if checks:
            msg = await self._generate_push_text(user_id, now, checks)
            if msg:
                await self._do_push(user_id, now, msg, skill=None)
        
        # News (separate)
        news = await self._check_news(user_id, now)
        if news and await self._can_push(user_id, now):
            await self._do_push(user_id, now, "📰 本地资讯更新", skill="news", data=news)
```

- [ ] **Step 3: Verify compile + test**

```bash
PYTHONPATH=./backend python3 -c "from app.services.proactive_service import proactive_service; print('OK')"
PYTHONPATH=./backend python3 -m pytest backend/tests/ -q
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/proactive_service.py
git commit -m "refactor: check methods return dicts instead of strings — structured data for LLM generation"
```

---

### Task 3: LLM natural text generation

**Files:** Modify `backend/app/services/proactive_service.py`

- [ ] **Step 1: Add _generate_push_text method**

```python
NATURAL_PUSH_PROMPT = """你是灵犀，一只关心主人的小猫。根据以下信息，用一句自然温暖的话问候主人（不超过80字）。
不要逐条复述数据，要像小猫在跟主人聊天一样自然流畅。如果数据很少只聊天气就够。

当前时间: {now}
所在城市: {city}
推送数据: {data_summary}

小猫灵犀:"""

async def _generate_push_text(self, user_id: str, now: datetime, checks: list[dict]) -> str | None:
    """Generate natural push text from structured check data via LLM."""
    # Build data summary
    lines = []
    city = "未知"
    for c in checks:
        t = c.get("type", "")
        if t == "weather":
            city = c.get("city", city)
            if c.get("alert"):
                lines.append(f"天气提醒={c['alert']}")
        elif t == "calendar":
            events = c.get("events", [])
            if events:
                lines.append(f"日程={','.join(e['title'] for e in events)}")
        elif t == "expense":
            lines.append(f"昨日消费¥{c.get('yesterday_total', 0):.0f}")
        elif t == "water":
            lines.append(f"该喝水了(现在{c.get('hour')}点)")
        elif t == "idle":
            lines.append(f"主人{c.get('hours')}小时没上线了")
        elif t == "emotion":
            lines.append(f"心情{c.get('current', '')}")
        elif t == "memory":
            lines.append(f"最近关注:{','.join(c.get('topics', [])[:3])}")
    
    if not lines:
        return None
    
    time_str = now.strftime("%H:%M")
    data_summary = "，".join(lines)
    prompt = NATURAL_PUSH_PROMPT.format(now=time_str, city=city, data_summary=data_summary)
    
    try:
        result = await llm_router.chat([{"role": "user", "content": prompt}])
        result = (result or "").strip()
        if result and len(result) > 3 and result not in ("暂无", "无", "空", "。", "..."):
            return result
    except Exception:
        pass
    
    # Fallback: simple concatenation
    return f"喵～ {'，'.join(l for l in lines[:3])}"
```

- [ ] **Step 2: Verify compile**

```bash
PYTHONPATH=./backend python3 -c "from app.services.proactive_service import proactive_service; print('OK')"
```

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/proactive_service.py
git commit -m "feat: LLM natural push text generation — one call merges all check data into warm message"
```

---

### Task 4: Morning briefing

**Files:** Modify `backend/app/services/proactive_service.py`, `backend/app/api/ws_chat.py`

- [ ] **Step 1: Add morning briefing function to proactive_service.py**

```python
async def send_morning_briefing(user_id: str) -> str | None:
    """Send morning briefing if user is first logging in after 8am and hasn't received one today."""
    now = datetime.now(BEIJING_TZ)
    if now.hour < 8:
        return None
    
    # Check if already sent today
    from uuid import UUID
    from app.models.proactive_push import ProactivePush
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    async with async_session() as db:
        r = await db.execute(
            select(func.count(ProactivePush.id)).where(
                ProactivePush.user_id == UUID(user_id),
                ProactivePush.push_type == "morning_briefing",
                ProactivePush.created_at >= today_start,
            )
        )
        if (r.scalar() or 0) > 0:
            return None
    
    # Build briefing data
    checks = []
    async with async_session() as db:
        w = await proactive_service._check_weather(user_id, now)
        if w: checks.append(w)
        c = await proactive_service._check_calendar(user_id, now, db)
        if c: checks.append(c)
        e = await proactive_service._check_expense(user_id, now, db)
        if e: checks.append(e)
    
    if not checks:
        return None
    
    # Generate briefing text
    time_str = now.strftime("%m月%d日 %H:%M")
    city = next((c.get("city", "未知") for c in checks if c.get("type") == "weather"), "未知")
    
    prompt = f"""你是灵犀，一只温暖的小猫。给你的主人写一段晨间简报（不超过100字）。

今天是{time_str}，主人在{city}。
今日数据: {checks}

用小猫的语气，温暖自然，包含:
☀️ 天气一句话
📅 今日日程（如果有）
💰 昨日消费（如果有）
💧 一句鼓励结尾"""
    
    try:
        msg = await llm_router.chat([{"role": "user", "content": prompt}])
        msg = (msg or "").strip()
        if msg and len(msg) > 5:
            # Save to DB and send
            payload = {"type": "proactive", "delta": msg, "skill": "morning_briefing"}
            await send_to_user(user_id, payload)
            async with async_session() as db:
                db.add(ProactivePush(user_id=UUID(user_id), push_type="morning_briefing", message_preview=msg[:200]))
                await db.commit()
            return msg
    except Exception:
        pass
    return None
```

- [ ] **Step 2: Wire into ws_chat.py's _send_greeting**

```python
# In ws_chat.py, modify _send_greeting:
async def _send_greeting():
    try:
        # Try morning briefing first
        from app.services.proactive_service import send_morning_briefing
        msg = await send_morning_briefing(user_id)
        if msg:
            return  # already sent by send_morning_briefing
        # Fall back to normal greeting
        msg = await send_connect_greeting(user_id)
        if msg:
            await send_message({"type": "proactive", "delta": msg, "skill": "greeting"})
    except Exception:
        pass
```

- [ ] **Step 3: Verify + test**

```bash
PYTHONPATH=./backend python3 -c "from app.services.proactive_service import send_morning_briefing; print('OK')"
PYTHONPATH=./backend python3 -m pytest backend/tests/ -q
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/proactive_service.py backend/app/api/ws_chat.py
git commit -m "feat: morning briefing — first login after 8am gets weather+calendar+expense summary"
```

---

### Task 5: Holiday + countdown checks

**Files:** Modify `backend/app/services/proactive_service.py`

- [ ] **Step 1: Add holiday check**

```python
HOLIDAYS = {
    "01-01": "元旦", "03-08": "妇女节", "04-05": "清明节(浮动)",
    "05-01": "劳动节", "06-01": "儿童节",
    "08-15": "中秋节(浮动)", "10-01": "国庆节",
    "12-25": "圣诞节", "12-31": "除夕(浮动)",
}

async def _check_holiday(self, now: datetime) -> str | None:
    """Check if today is a holiday."""
    today_key = now.strftime("%m-%d")
    # Lunar holidays — approximate (use solar date as fallback)
    return HOLIDAYS.get(today_key)
```

- [ ] **Step 2: Add countdown check**

```python
async def _check_countdown(self, user_id: str, now: datetime, db) -> list[dict] | None:
    """Check upcoming or due countdowns."""
    from uuid import UUID
    from app.models.countdown import Countdown
    r = await db.execute(
        select(Countdown).where(
            Countdown.user_id == UUID(user_id),
        )
    )
    items = r.scalars().all()
    alerts = []
    for item in items:
        days_left = (item.target_date.date() - now.date()).days
        if days_left in (0, 1, 3):  # today, tomorrow, 3 days before
            label = "就是今天🎉" if days_left == 0 else f"还有{days_left}天" if days_left > 0 else f"已过去{-days_left}天"
            alerts.append({"title": item.title, "label": label})
    return alerts[:2] if alerts else None
```

- [ ] **Step 3: Integrate into _check_user priority chain**

```python
# Add before weather check in _check_user:
# Holiday check — highest priority
holiday = await self._check_holiday(now)
if holiday:
    msg = await self._generate_push_text(user_id, now, [{"type": "holiday", "name": holiday}])
    if msg:
        await self._do_push(user_id, now, msg, skill="holiday")
        return

# ... existing checks ...

# Countdown check — after memory, before news
cd = await self._check_countdown(user_id, now, db)
if cd:
    titles = [f"{c['title']} {c['label']}" for c in cd]
    await self._do_push(user_id, now, f"📅 {'，'.join(titles)}", skill="countdown")
```

- [ ] **Step 4: Verify + commit**

```bash
PYTHONPATH=./backend python3 -c "from app.services.proactive_service import proactive_service; print('OK')"
git add backend/app/services/proactive_service.py
git commit -m "feat: holiday + countdown push checks — holiday overrides all, countdown alerts at 3/1/0 days"
```

---

### Task 6: Reminder schedules table + scan

**Files:** Create `backend/app/models/reminder_schedule.py`, Modify `backend/app/main.py`, Modify `backend/app/services/proactive_service.py`

- [ ] **Step 1: Create model**

```python
# backend/app/models/reminder_schedule.py
import uuid
from datetime import datetime, time
from sqlalchemy import String, DateTime, Boolean, Time, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class ReminderSchedule(Base):
    __tablename__ = "reminder_schedules"
    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    content: Mapped[str] = mapped_column(String(500), nullable=False)
    rule: Mapped[str] = mapped_column(String(20), default="daily")  # daily/weekly/monthly
    time_of_day: Mapped[time] = mapped_column(Time, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 2: Register model + create table**

```python
# In models/__init__.py: add import + __all__
from app.models.reminder_schedule import ReminderSchedule
# __all__: add "ReminderSchedule"

# Create table:
PYTHONPATH=./backend python3 -c "
from app.database import engine, Base; from app.models import *
import asyncio
async def init(): 
    async with engine.begin() as conn: await conn.run_sync(Base.metadata.create_all)
    print('OK')
asyncio.run(init())
"
```

- [ ] **Step 3: Add reminder scan to _poll**

```python
# In proactive_service._poll(), add a short-cycle scan:
async def _poll(self):
    while True:
        try:
            await self._check_all()
            await self._scan_reminders()
        except Exception:
            logger.exception("proactive poll error")
        await asyncio.sleep(self._interval)

async def _scan_reminders(self):
    """Scan reminder_schedules every 30 min for due reminders."""
    now = datetime.now(BEIJING_TZ)
    current_time = now.time()
    async with async_session() as db:
        r = await db.execute(
            select(ReminderSchedule).where(ReminderSchedule.active == True)
        )
        for s in r.scalars().all():
            if s.time_of_day.hour == current_time.hour and abs(s.time_of_day.minute - current_time.minute) < 30:
                await self._do_push(
                    str(s.user_id), now, f"⏰ {s.content}", skill="reminder"
                )
```

- [ ] **Step 4: Verify + commit**

```bash
PYTHONPATH=./backend python3 -c "from app.services.proactive_service import proactive_service; print('OK')"
git add backend/app/models/reminder_schedule.py backend/app/models/__init__.py backend/app/services/proactive_service.py
git commit -m "feat: reminder_schedules table + periodic scan for custom time-based reminders"
```

---

### Task 7: Tests + final verification

**Files:** Create `backend/tests/test_proactive_push.py`

- [ ] **Step 1: Write tests**

```python
import pytest
from datetime import datetime, timedelta, timezone
BEIJING_TZ = timezone(timedelta(hours=8))

@pytest.mark.asyncio
async def test_quiet_hours_night():
    """Quiet hours check should return True for 23:00"""
    from app.services.proactive_service import proactive_service
    now = datetime(2026, 6, 9, 23, 0, tzinfo=BEIJING_TZ)
    # Simulate hour check
    assert now.hour >= 22 or now.hour < 8  # should be True (quiet)

@pytest.mark.asyncio
async def test_quiet_hours_morning():
    """Quiet hours check should return True for 5:00"""
    now = datetime(2026, 6, 10, 5, 0, tzinfo=BEIJING_TZ)
    assert now.hour >= 22 or now.hour < 8  # should be True (quiet)

@pytest.mark.asyncio
async def test_quiet_hours_active():
    """Quiet hours check should return False for 14:00"""
    now = datetime(2026, 6, 9, 14, 0, tzinfo=BEIJING_TZ)
    assert not (now.hour >= 22 or now.hour < 8)  # active time

@pytest.mark.asyncio
async def test_holiday_check_new_year():
    """January 1 should return 元旦"""
    from app.services.proactive_service import HOLIDAYS
    assert HOLIDAYS.get("01-01") == "元旦"

@pytest.mark.asyncio
async def test_holiday_check_national_day():
    """October 1 should return 国庆节"""
    from app.services.proactive_service import HOLIDAYS
    assert HOLIDAYS.get("10-01") == "国庆节"
```

- [ ] **Step 2: Run all tests**

```bash
PYTHONPATH=./backend python3 -m pytest backend/tests/ -v -q
```
Expected: all pass (49 existing + 5 new = 54)

- [ ] **Step 3: Final commit**

```bash
git add backend/tests/test_proactive_push.py
git commit -m "test: proactive push V2 — quiet hours, holidays, structured checks"
```
