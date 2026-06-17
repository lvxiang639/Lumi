"""
Proactive care — the cat checks on the user periodically.

Runs every 30 minutes (configurable) and checks:
1. Weather alert (rain/snow)
2. Upcoming calendar event within next hour
3. Unlogged expenses yesterday
4. Long idle time (user hasn't messaged in 4+ hours)
5. Memory-triggered conversation starter
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from sqlalchemy import select, func, desc

from app.config import settings
from app.database import async_session
from app.models import (
    User, CalendarEvent, ExpenseRecord, Conversation, Message, UserMemory,
    UserEmotionState,
)
from app.services.llm_service import llm_router
from app.services.connection_manager import send_to_user, online_users
from app.services.location_service import get_city

logger = logging.getLogger("proactive")

BEIJING_TZ = timezone(timedelta(hours=8))

HOLIDAYS = {
    "01-01": "元旦", "02-14": "情人节", "03-08": "妇女节",
    "05-01": "劳动节", "06-01": "儿童节",
    "10-01": "国庆节", "12-25": "圣诞节",
}

WEATHER_PROMPT = """当前时间: {now}，用户所在城市: {city}。
请用一句话（不超过30字）提醒用户天气注意事项。语气亲切可爱（像一只小猫）。
如果天气没什么特别的，返回空。如果有雨雪大风高温等需要提醒，请简短提醒。
例如: "外面要下雨了，出门记得带伞哦 ☔" """

CALENDAR_PROMPT = """当前时间: {now}。
用户即将有以下日程: {events}
请用一句话（不超过25字）温柔提醒。如果没有紧急事件返回空。"""

MEMORY_PROMPT = """你是一只关心主人的小猫。根据以下关于用户的信息，想一个自然的关心话题（不超过30字）。
不要刻意复述记忆，而是用记忆自然引出话题。如果没什么特别的话题返回空。

用户信息: {memories}

小猫的关心:"""



NATURAL_PUSH_PROMPT = """你是灵犀，一只关心主人的小猫。根据以下信息，用一句自然温暖的话问候主人（不超过80字）。
不要逐条复述数据，要像小猫在跟主人聊天一样自然流畅。

当前时间: {now}
所在城市: {city}
推送数据: {data_summary}

小猫灵犀:"""

DAILY_TOPIC_PROMPT = """生成一个有趣的每日话题（20字以内），可以引发用户思考和分享。话题要轻松自然，像朋友聊天。不要涉及政治敏感话题。
例如: "今天最让你开心的一件小事是什么？" "如果明天是世界末日，你会怎么过？" "你最近单曲循环的一首歌是？"

每日话题:"""

CONTENT_CARD_PROMPT = """生成一张每日内容卡片，包含以下五项（每行一项，格式: emoji 标题: 内容）：
1. 🔮 今日运势: 一句简短有趣的运势（15字以内，随机生成，轻松幽默）
2. 😂 每日一笑: 一个简短笑话（30字以内，轻松不低俗）
3. 💡 冷知识: 一个有趣的冷知识（20字以内，要出乎意料）
4. 🛠️ 生活小贴士: 一个实用小技巧（20字以内）
5. 🌟 今日一言: 一句正能量名言（20字以内，标注出处）

内容卡片:"""

# ── Proactive service ──


class ProactiveService:
    def __init__(self):
        self._task: asyncio.Task | None = None
        self._interval = settings.notification_check_interval * 180  # ~3 hours
        self._news_cache: dict[str, tuple[list[dict], datetime]] = {}  # city → (items, time)
        self._weather_cache: dict[str, tuple[str, datetime]] = {}  # city → (summary, time)
        self._memory_cache: dict[str, tuple[str, datetime]] = {}  # user_id → (topic, time)

    async def _poll(self):
        while True:
            try:
                await self._check_all()
                await push_daily_content()
                await push_morning_briefing()
                await push_interest_content()
                # Chinese literature is now part of daily_content (poetry/idiom/history entries)
            except Exception:
                logger.exception("proactive poll error")
            await asyncio.sleep(self._interval)

    async def _check_all(self):
        users = online_users()
        if not users:
            return

        now = datetime.now(BEIJING_TZ)
        # Quiet hours: 22:00-8:00 — skip all checks
        if now.hour >= 22 or now.hour < 8:
            logger.debug("proactive: quiet hours (hour=%d), skipping all checks", now.hour)
            return
        for uid in users:
            try:
                await self._check_user(uid, now)
            except Exception:
                logger.exception("proactive check failed for user=%s", uid[:8])

    async def _check_water(self, user_id: str, now: datetime) -> dict | None:
        """Remind to drink water during daytime. Returns structured data."""
        if now.hour < 8 or now.hour > 22:
            return None
        return {"type": "water", "hour": now.hour}

    async def _check_user(self, user_id: str, now: datetime):
        """Consolidated check — build one combined message (max 1 push per cycle)."""
        logger.info("proactive check: [0] starting scan for %s", user_id[:8])
        if not await self._can_push(user_id, now):
            logger.info("proactive check: throttled (cooldown/limit) for %s", user_id[:8])
            return

        async with async_session() as db:
            r = await db.execute(select(User).where(User.id == user_id))
            if not r.scalar_one_or_none():
                return

            # Holiday check — highest priority
            holiday = await self._check_holiday(now)
            if holiday:
                logger.info("proactive check: HOLIDAY → %s", holiday.get("name"))
                msg = await self._generate_push_text(user_id, now, [holiday])
                if msg:
                    await self._do_push(user_id, now, msg, skill="holiday")
                return

            checks = []

            logger.info("proactive check: [1/8] weather for %s", user_id[:8])
            w = await self._check_weather(user_id, now)
            logger.info("proactive check: weather -> %s", "HIT" if w else "SKIP")
            if w: checks.append(w)

            logger.info("proactive check: [2/8] calendar for %s", user_id[:8])
            c = await self._check_calendar(user_id, now, db)
            logger.info("proactive check: calendar -> %s", "HIT" if c else "SKIP")
            if c: checks.append(c)

            logger.info("proactive check: [3/8] expense for %s", user_id[:8])
            e = await self._check_expense(user_id, now, db)
            logger.info("proactive check: expense -> %s", "HIT" if e else "SKIP")
            if e: checks.append(e)

            logger.info("proactive check: [4/8] idle for %s", user_id[:8])
            idle = await self._check_idle(user_id, now, db)
            logger.info("proactive check: idle -> %s", "HIT" if idle else "SKIP")
            if idle: checks.append(idle)

            logger.info("proactive check: [5/8] water for %s", user_id[:8])
            water = await self._check_water(user_id, now)
            logger.info("proactive check: water -> %s", "HIT" if water else "SKIP")
            if water: checks.append(water)

            logger.info("proactive check: [6/8] emotion for %s", user_id[:8])
            emo = await self._check_emotion(user_id, now, db)
            logger.info("proactive check: emotion -> %s", "HIT" if emo else "SKIP")
            if emo: checks.append(emo)

            logger.info("proactive check: [7/8] memory for %s", user_id[:8])
            mem = await self._check_memory(user_id, now, db)
            logger.info("proactive check: memory -> %s", "HIT" if mem else "SKIP")
            if mem: checks.append(mem)

            # Countdown check
            cd = await self._check_countdown(user_id, now, db)
            if cd:
                for item in cd:
                    checks.append({"type": "countdown", "title": item["title"], "label": item["label"]})

            # Book recommendation
            book = await self._check_book_recommendation(user_id, now, db)
            logger.info("proactive check: book -> %s", "HIT" if book else "SKIP")
            if book: checks.append(book)

            # Practice push (study weak points)
            practice = await self._check_practice_push(user_id, now, db)
            logger.info("proactive check: practice -> %s", "HIT" if practice else "SKIP")
            if practice: checks.append(practice)

            logger.info("proactive check: %d checks hit for %s", len(checks), user_id[:8])
            if checks:
                msg = await self._generate_push_text(user_id, now, checks)
                if msg:
                    await self._do_push(user_id, now, msg, skill=None)

            logger.info("proactive check: [8/8] news for %s", user_id[:8])
            news = await self._check_news(user_id, now)
            logger.info("proactive check: news -> %s", f"{len(news)} items" if news else "SKIP")
            if news:
                # Only push news if user hasn't received news today
                today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                if not await self._has_push_type(user_id, "news", today_start):
                    await self._do_push(user_id, now, "📰 本地资讯更新", skill="news", data=news)

    async def _generate_push_text(self, user_id: str, now: datetime, checks: list[dict]) -> str | None:
        """Generate natural push text from structured check data via LLM."""
        lines = []
        city = "Unknown"
        for c in checks:
            t = c.get("type", "")
            if t == "weather":
                city = c.get("city", city)
                if c.get("alert"): lines.append(f"天气提醒={c['alert']}")
            elif t == "calendar":
                events = c.get("events", [])
                if events: lines.append(f"日程={','.join(e['title'] for e in events)}")
            elif t == "expense":
                lines.append(f"昨日消费¥{c.get('yesterday_total', 0):.0f}")
            elif t == "water":
                lines.append(f"该喝水了")
            elif t == "idle":
                lines.append(f"主人{c.get('hours', 0)}小时没上线了")
            elif t == "emotion":
                lines.append(f"心情{c.get('current', '')}")
            elif t == "memory":
                topics = c.get('topics', [])
                if topics: lines.append(f"最近关注:{','.join(topics[:3])}")
            elif t == "holiday":
                lines.append(f"今天是{c.get('name', '')}🎉")
            elif t == "book_recommend":
                lines.append(f"📚 书籍推荐")
            elif t == "countdown":
                lines.append(f"倒数日:{c.get('title', '')}{c.get('label', '')}")
            elif t == "practice":
                lines.append(f"有{c.get('questions', [])} 道练习题待完成")
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
        return "喵～ " + "，".join(lines[:3])

    async def _can_push(self, user_id: str, now: datetime) -> bool:
        """DB-backed throttle: max 1 push per 2 hours, max 3 per day."""
        from uuid import UUID
        from app.models.proactive_push import ProactivePush
        uid = UUID(user_id)
        async with async_session() as db:
            # Check 2-hour cooldown
            two_hours_ago = now - timedelta(hours=2)
            r = await db.execute(
                select(func.count(ProactivePush.id)).where(
                    ProactivePush.user_id == uid,
                    ProactivePush.created_at >= two_hours_ago,
                )
            )
            if (r.scalar() or 0) > 0:
                return False
            # Check daily limit (3 per day)
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            r = await db.execute(
                select(func.count(ProactivePush.id)).where(
                    ProactivePush.user_id == uid,
                    ProactivePush.created_at >= today_start,
                )
            )
            if (r.scalar() or 0) >= 3:
                return False
        return True

    async def _has_push_type(self, user_id: str, push_type: str, since: datetime) -> bool:
        """Check if a specific push_type already exists for user since given time."""
        from uuid import UUID
        from app.models.proactive_push import ProactivePush
        uid = UUID(user_id)
        async with async_session() as db:
            r = await db.execute(
                select(func.count(ProactivePush.id)).where(
                    ProactivePush.user_id == uid,
                    ProactivePush.push_type == push_type,
                    ProactivePush.created_at >= since,
                )
            )
            return (r.scalar() or 0) > 0

    async def _do_push(self, user_id: str, now: datetime, msg: str,
                       skill: str | None = None, data: dict | None = None):
        """Send push and persist record to DB."""
        payload = {"type": "proactive", "delta": msg}
        if skill: payload["skill"] = skill
        if data: payload["data"] = data
        await send_to_user(user_id, payload)

        # Persist to DB — frontend polls /api/push/poll every 15min for missed pushes
        from uuid import UUID
        from app.models.proactive_push import ProactivePush
        async with async_session() as db:
            db.add(ProactivePush(
                user_id=UUID(user_id),
                push_type=skill or "proactive",
                message_preview=msg[:200],
            ))
            await db.commit()
        logger.info("proactive push to %s: %s", user_id[:8], msg[:50])

    async def _check_weather(self, user_id: str, now: datetime) -> dict | None:
        """Check weather with 2-hour cache per city to reduce LLM cost."""
        try:
            city = await get_city(user_id=user_id)
            cached = self._weather_cache.get(city)
            if cached:
                data, ts = cached
                if (now - ts).total_seconds() < 7200:  # 2 hour cache
                    return data if data else None
            prompt = WEATHER_PROMPT.format(now=now.strftime("%H:%M"), city=city)
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            data = {"type": "weather", "city": city, "alert": result} if result else None
            self._weather_cache[city] = (data, now)
            return data
        except Exception:
            return None

    async def _check_calendar(
        self, user_id: str, now: datetime, db
    ) -> dict | None:
        """Check for events in the next 60 minutes. Skip events >1 day in the past."""
        day_ago = now - timedelta(days=1)
        window = now + timedelta(hours=1)
        r = await db.execute(
            select(CalendarEvent)
            .where(
                CalendarEvent.user_id == user_id,
                CalendarEvent.time >= now,  # only future events
                CalendarEvent.time <= window,
            )
            .order_by(CalendarEvent.time)
            .limit(3)
        )
        events = r.scalars().all()
        if not events:
            return None

        event_str = ", ".join(
            f"{e.time.strftime('%H:%M')} {e.title}" for e in events
        )
        prompt = CALENDAR_PROMPT.format(now=now.strftime("%H:%M"), events=event_str)
        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            return {"type": "calendar", "text": result} if result else None
        except Exception:
            return {"type": "calendar", "text": f"喵~ {len(events)}个日程快到了，记得看看哦 🐱"}

    async def _check_expense(
        self, user_id: str, now: datetime, db
    ) -> dict | None:
        """Check if user forgot to log expenses yesterday."""
        yesterday = (now - timedelta(days=1)).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

        r = await db.execute(
            select(func.count(ExpenseRecord.id)).where(
                ExpenseRecord.user_id == user_id,
                ExpenseRecord.recorded_at >= yesterday,
                ExpenseRecord.recorded_at < today_start,
            )
        )
        count = r.scalar() or 0
        if count > 0:
            return None  # They logged, skip

        # Check if they had any conversation yesterday
        r = await db.execute(
            select(func.count(Conversation.id)).where(
                Conversation.user_id == user_id,
                Conversation.updated_at >= yesterday,
                Conversation.updated_at < today_start,
            )
        )
        conv_count = r.scalar() or 0
        if conv_count == 0:
            return None  # Not active yesterday, don't bother

        return {"type": "expense", "text": "喵~ 昨天好像忘记记账了，要现在记一下吗？💰"}

    async def _check_idle(
        self, user_id: str, now: datetime, db
    ) -> dict | None:
        """Check if user has been idle for 4+ hours."""
        r = await db.execute(
            select(Conversation.updated_at)
            .where(Conversation.user_id == user_id)
            .order_by(desc(Conversation.updated_at))
            .limit(1)
        )
        row = r.scalar_one_or_none()
        if not row:
            return None

        last_active = row
        if last_active.tzinfo is None:
            last_active = last_active.replace(tzinfo=timezone.utc)

        idle_hours = (now.astimezone(timezone.utc) - last_active).total_seconds() / 3600
        if idle_hours < 4:
            return None

        return {"type": "idle", "text": "喵~ 好久不见！你回来啦 🐱"}

    async def _check_memory(
        self, user_id: str, now: datetime, db
    ) -> dict | None:
        """Use memories to start a conversation. Cache for 6 hours."""
        cached = self._memory_cache.get(user_id)
        if cached:
            msg, ts = cached
            if (now - ts).total_seconds() < 21600:  # 6 hour cache
                return msg if msg != "__NONE__" else None

        r = await db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(10)
        )
        memories = r.scalars().all()
        if len(memories) < 2:
            return None

        mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories)
        prompt = MEMORY_PROMPT.format(memories=mem_text)
        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            self._memory_cache[user_id] = (result or "__NONE__", now)
            return {"type": "memory", "text": result} if result else None
        except Exception:
            return None

    async def _check_emotion(
        self, user_id: str, now: datetime, db
    ) -> dict | None:
        """Check if user has been sad/angry and needs care."""
        # Throttle via global push system
        if not await self._can_push(user_id, now):
            return None

        r = await db.execute(
            select(UserEmotionState).where(
                UserEmotionState.user_id == user_id
            )
        )
        state = r.scalar_one_or_none()
        if not state or state.intensity < 0.5:
            return None
        if state.current_emotion not in ("sad", "angry", "worried"):
            return None

        messages = {
            "sad": "喵~ 感觉你心情不太好，要聊聊吗？我一直在这里陪你 🐱",
            "angry": "喵... 看起来你有点生气，深呼吸，一切都会好起来的~",
            "worried": "喵~ 你好像有点焦虑，需要我帮你做点什么吗？",
        }
        text = messages.get(state.current_emotion)
        return {"type": "emotion", "text": text} if text else None


    async def _check_holiday(self, now: datetime) -> dict | None:
        """Check if today is a holiday."""
        today_key = now.strftime("%m-%d")
        name = HOLIDAYS.get(today_key)
        return {"type": "holiday", "name": name} if name else None

    async def _check_practice_push(self, user_id: str, now: datetime, db) -> dict | None:
        """Check for unsolved practice questions and push them."""
        from uuid import UUID
        from app.models.study_record import PracticePush
        r = await db.execute(select(PracticePush).where(PracticePush.user_id == UUID(user_id), PracticePush.solved == False).limit(3))
        practices = r.scalars().all()
        if not practices: return None
        lines = [f"📝 {p.question[:100]}" for p in practices]
        return {"type": "practice", "questions": lines}

    async def _check_book_recommendation(self, user_id: str, now: datetime, db) -> dict | None:
        """Personalized book recommendation based on user memories. Once/day per user."""
        from uuid import UUID
        # Throttle: only push book recs once per day
        from app.models.proactive_push import ProactivePush
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        r = await db.execute(
            select(func.count(ProactivePush.id)).where(
                ProactivePush.user_id == UUID(user_id),
                ProactivePush.push_type == "book_recommend",
                ProactivePush.created_at >= today_start,
            )
        )
        if (r.scalar() or 0) > 0:
            return None

        # Get user memories for personalization
        r = await db.execute(
            select(UserMemory).where(UserMemory.user_id == UUID(user_id)).order_by(UserMemory.updated_at.desc()).limit(10)
        )
        memories = r.scalars().all()
        mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories) if memories else "暂无用户信息"

        prompt = f"""根据以下用户信息，推荐2-3本适合TA的书籍（每本一行，格式: 📖 书名 - 作者: 一句话推荐理由（15字以内））。
推荐要基于用户兴趣，实用为主。不要推荐太大众的书。

用户信息:
{mem_text}

书籍推荐:"""

        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            if result and len(result) > 5:
                # Save push type for throttle
                return {"type": "book_recommend", "books": result}
        except Exception:
            pass
        return None

    async def _check_countdown(self, user_id: str, now: datetime, db) -> list[dict] | None:
        """Check upcoming or due countdowns."""
        from uuid import UUID
        from app.models.countdown import Countdown
        r = await db.execute(
            select(Countdown).where(Countdown.user_id == UUID(user_id))
        )
        items = r.scalars().all()
        alerts = []
        for item in items:
            days_left = (item.target_date.date() - now.date()).days
            if days_left in (0, 1, 3):
                label = "🎉就是今天" if days_left == 0 else f"还有{days_left}天" if days_left > 0 else f"已过去{-days_left}天"
                alerts.append({"title": item.title, "label": label})
        return alerts[:2] if alerts else None

    async def _check_news(self, user_id: str, now: datetime) -> list[dict] | None:
        """Fetch local news headlines. Cache per city for 3 hours."""
        city = await self._get_city(user_id)
        cache_key = f"news_{city or 'default'}"
        cached = self._news_cache.get(cache_key)
        if cached:
            data, ts = cached
            if (now - ts).total_seconds() < 10800:  # 3 hours
                return data if data else None

        try:
            import httpx
            from app.config import settings
            query = f"{city} 新闻" if city else "今日热点新闻"
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{settings.searxng_url}/search",
                    params={
                        "q": query, "format": "json",
                        "categories": "news",
                        "engines": settings.searxng_engines,
                    },
                    timeout=10,
                )
                resp.raise_for_status()
                results = resp.json().get("results", [])[:3]
                if results:
                    logger.info("news fetch for '%s': %d results — %s", query, len(results),
                        " | ".join(r.get("title", "")[:60] for r in results)[:200])
        except Exception:
            logger.exception("news fetch failed")
            results = []

        if not results:
            self._news_cache[cache_key] = ([], now)
            return None

        news_items = [
            {
                "title": r.get("title", ""),
                "summary": (r.get("content", "") or "")[:150],
                "link": r.get("url", ""),
                "time": now.strftime("%m/%d %H:%M"),
            }
            for r in results
        ]
        self._news_cache[cache_key] = (news_items, now)
        return news_items

    async def _get_city(self, user_id: str) -> str | None:
        """Get user's city from memory."""
        try:
            async with async_session() as db:
                r = await db.execute(
                    select(UserMemory).where(
                        UserMemory.user_id == user_id,
                        UserMemory.key == "city",
                    )
                )
                mem = r.scalar_one_or_none()
                return mem.value if mem else None
        except Exception:
            return None

    def start(self):
        if self._task is None:
            self._task = asyncio.create_task(self._poll())
            logger.info("proactive service started, interval=%ds", self._interval)

    async def stop(self):
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None


proactive_service = ProactiveService()

GREETING_PROMPT = """你是一只关心主人的小猫灵犀。根据以下用户信息和当前时间，想一个简短温暖的欢迎语（不超过35字）。
要自然、可爱，不要刻意复述记忆。如果没有特别的信息就返回空。

注意: 不要提及已经过期的日历事件（如过去的家长会、接机、会议等）。只关注当前和未来的事。

当前时间: {now}
用户信息:
{memories}

小猫灵犀的欢迎语:"""


def _clean_llm_content(text: str) -> str:
    """Clean LLM output: remove English-only lines, meta-responses, and garbage."""
    import re
    lines = text.strip().split('\n')
    cleaned = []
    english_pattern = re.compile(r'^[A-Za-z][A-Za-z\s\.,!?;:\-\'"]+$')
    garbage_starts = (
        'It looks like', 'I apologize', "I'm sorry", 'As an AI',
        'Sorry', 'Sure', 'Certainly', 'Here', 'Feel free',
        'How can I', 'Let me', 'I can', 'You can',
    )
    for line in lines:
        t = line.strip()
        if not t:
            continue
        # Skip pure English lines
        if english_pattern.match(t):
            continue
        # Skip LLM meta-responses
        if any(t.startswith(g) for g in garbage_starts):
            continue
        # Skip raw JSON/URL dumps
        if t.startswith('[{') or t.startswith('http'):
            continue
        cleaned.append(t)
    return '\n'.join(cleaned).strip()


async def generate_daily_content() -> dict | None:
    """Generate today's daily content. DB-backed — restart-safe, no duplicate LLM calls."""
    import json
    now = datetime.now(BEIJING_TZ)
    today_key = now.strftime("%Y-%m-%d")

    # 1. Check in-memory cache
    if hasattr(generate_daily_content, '_cache'):
        cached_date, cached_data = generate_daily_content._cache
        if cached_date == today_key:
            return cached_data

    # 2. Check DB — if already generated today (survives restart)
    try:
        async with async_session() as db:
            from app.models.daily_content import DailyContent
            today_date = now.date()
            r = await db.execute(
                select(DailyContent).where(DailyContent.date == today_date)
            )
            row = r.scalar_one_or_none()
            if row and row.content:
                data = json.loads(row.content)
                generate_daily_content._cache = (today_key, data)
                logger.info("daily content: loaded from DB cache")
                return data
    except Exception:
        pass

    # 3. Generate fresh via LLM
    logger.info("daily content: generating fresh via LLM")
    configs = []
    try:
        async with async_session() as db:
            from app.models.daily_content_config import DailyContentConfig
            r = await db.execute(
                select(DailyContentConfig).where(DailyContentConfig.enabled == True).order_by(DailyContentConfig.priority)
            )
            configs = r.scalars().all()
    except Exception:
        logger.exception("failed to load daily content configs")

    result = {}
    for cfg in configs:
        try:
            content = await llm_router.chat([{"role": "user", "content": cfg.prompt}])
            cleaned = _clean_llm_content(content or "")
            result[cfg.content_type] = {
                "display_name": cfg.display_name,
                "content": cleaned[:300] if cleaned else "",
            }
        except Exception:
            result[cfg.content_type] = {"display_name": cfg.display_name, "content": ""}

    # Fallback: hot trends from SearXNG
    if not configs or "hot_trends" in result:
        try:
            import httpx
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{settings.searxng_url}/search",
                    params={"q": "热搜", "format": "json", "categories": "news"},
                    timeout=10,
                )
                resp.raise_for_status()
                trends = resp.json().get("results", [])[:5]
                logger.info("hot trends fetch: %d results — %s", len(trends),
                    " | ".join(t.get("title", "")[:60] for t in trends)[:200])
                result["hot_trends"] = {
                    "display_name": "🔥 热门资讯",
                    "content": [{"title": t.get("title", ""), "url": t.get("url", "")} for t in trends],
                }
        except Exception:
            pass

    generate_daily_content._cache = (today_key, result)

    # Save to DB so offline users can see it when they open the app
    try:
        async with async_session() as db:
            from app.models.daily_content import DailyContent
            today_date = now.date()
            existing = await db.execute(
                select(DailyContent).where(DailyContent.date == today_date)
            )
            row = existing.scalar_one_or_none()
            if row:
                row.content = json.dumps(result, ensure_ascii=False)
            else:
                db.add(DailyContent(date=today_date, content=json.dumps(result, ensure_ascii=False)))
            await db.commit()
    except Exception:
        logger.exception("failed to save daily content to DB")

    return result


async def push_daily_content():
    """Push daily content to online users who haven't received it today."""
    content = await generate_daily_content()
    if not content:
        return

    now = datetime.now(BEIJING_TZ)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    for uid in online_users():
        # Check if already pushed today
        try:
            from uuid import UUID
            from app.models.proactive_push import ProactivePush
            from app.database import async_session
            async with async_session() as db:
                r = await db.execute(
                    select(func.count(ProactivePush.id)).where(
                        ProactivePush.user_id == UUID(uid),
                        ProactivePush.push_type == "daily_content",
                        ProactivePush.created_at >= today_start,
                    )
                )
                if (r.scalar() or 0) > 0:
                    continue
        except Exception:
            pass

        try:
            payload = {"type": "proactive", "delta": "📰 每日精选", "skill": "daily_content", "data": content}
            await send_to_user(uid, payload)
            # Record push in DB
            async with async_session() as db:
                db.add(ProactivePush(user_id=UUID(uid), push_type="daily_content", message_preview="每日精选"))
                await db.commit()
        except Exception:
            pass


async def push_morning_briefing():
    """Push morning briefing to discover page at 8 AM Beijing time.

    Sends weather + calendar + expense summary as a proactive push.
    One per user per day (enforced by last_briefing_date on User model).
    """
    now = datetime.now(BEIJING_TZ)
    # Fire at any poll after 8:00 AM (once/day enforced by last_briefing_date)
    if now.hour < 8:
        return

    from app.services.briefing_service import generate_briefing

    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    for uid_str in online_users():
        try:
            uid = UUID(uid_str)
            # Check if briefing already sent today
            user_ok = False
            async with async_session() as db:
                r = await db.execute(select(User).where(User.id == uid))
                u = r.scalar_one_or_none()
                if u and (u.last_briefing_date is None or u.last_briefing_date < today_start):
                    user_ok = True

            if not user_ok:
                continue

            text = await generate_briefing(uid)
            if not text:
                continue

            # Update briefing date
            async with async_session() as db:
                r = await db.execute(select(User).where(User.id == uid))
                u = r.scalar_one_or_none()
                if u:
                    u.last_briefing_date = today_start
                    await db.commit()

            # Push to discover page
            await send_to_user(uid_str, {
                "type": "proactive",
                "delta": text,
                "skill": "morning_briefing",
                "data": None,
            })

            # Record in push DB
            async with async_session() as db:
                db.add(ProactivePush(
                    user_id=uid, push_type="morning_briefing",
                    message_preview=text[:200],
                ))
                await db.commit()

            logger.info("Morning briefing sent to user=%s", uid_str[:8])
        except Exception:
            logger.exception("push_morning_briefing failed for user=%s", uid_str[:8])


INTEREST_PROMPT = """分析以下用户记忆，提取用户的潜在兴趣点，用于个性化内容推荐。

用户记忆:
{memories}

请提取 2-3 个用户最可能感兴趣的话题/实体，每行一个，格式: "类别: 具体话题"
例如:
人物: 周杰伦
科技: 人工智能
投资: 特斯拉股票

只输出话题，不要解释。"""


async def push_interest_content():
    """Push personalized interest-based content to discover page.

    Extracts interests from user memories, searches for latest info,
    pushes up to 3 items. Throttle: max 3 pushes/day, 2h cooldown.
    """
    now = datetime.now(BEIJING_TZ)
    if now.hour < 8 or now.hour >= 23:
        return

    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    for uid_str in online_users():
        try:
            uid = UUID(uid_str)

            # Throttle: max 3 interest pushes per day, 2h cooldown
            async with async_session() as db:
                # Count today's interest pushes
                r = await db.execute(
                    select(func.count(ProactivePush.id)).where(
                        ProactivePush.user_id == uid,
                        ProactivePush.push_type == "interest_push",
                        ProactivePush.created_at >= today_start,
                    )
                )
                if (r.scalar() or 0) >= 3:
                    continue

                # Check 2h cooldown
                two_h_ago = now - timedelta(hours=2)
                r = await db.execute(
                    select(func.count(ProactivePush.id)).where(
                        ProactivePush.user_id == uid,
                        ProactivePush.push_type == "interest_push",
                        ProactivePush.created_at >= two_h_ago,
                    )
                )
                if (r.scalar() or 0) > 0:
                    continue

                # Load user memories
                r = await db.execute(
                    select(UserMemory).where(UserMemory.user_id == uid)
                    .order_by(UserMemory.updated_at.desc()).limit(20)
                )
                memories = r.scalars().all()

            if len(memories) < 2:
                continue

            # Extract interests via LLM
            mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories[:15])
            prompt = INTEREST_PROMPT.format(memories=mem_text)
            interests_raw = await llm_router.chat(
                [{"role": "user", "content": prompt}],
                max_tokens=200,
            )
            if not interests_raw:
                continue

            interests = [
                line.strip()
                for line in interests_raw.strip().split("\n")
                if line.strip() and ":" in line
            ][:3]
            if not interests:
                continue

            # Search for each interest via SearXNG
            items = []
            for interest in interests[:2]:  # Search top 2 interests
                try:
                    import httpx
                    async with httpx.AsyncClient() as client:
                        resp = await client.get(
                            f"{settings.searxng_url}/search",
                            params={
                                "q": interest, "format": "json",
                                "categories": "general",
                                "engines": settings.searxng_engines,
                            },
                            timeout=8,
                        )
                        results = resp.json().get("results", [])[:2]
                        if results:
                            logger.info(
                                "interest search '%s': %d results — %s",
                                interest[:30], len(results),
                                " | ".join(
                                    f"{r.get('title', '')[:60]}"
                                    for r in results
                                )[:200],
                            )
                        for r in results:
                            items.append({
                                "title": r.get("title", ""),
                                "summary": (r.get("content", "") or "")[:120],
                                "link": r.get("url", ""),
                                "interest": interest,
                            })
                except Exception:
                    continue

            if not items:
                continue

            # Build push text
            push_text = f"💡 你可能感兴趣"
            push_data = {"interests": interests, "items": items[:3]}

            await send_to_user(uid_str, {
                "type": "proactive",
                "delta": push_text,
                "skill": "interest_push",
                "data": push_data,
            })

            async with async_session() as db:
                db.add(ProactivePush(
                    user_id=uid, push_type="interest_push",
                    message_preview=push_text,
                ))
                await db.commit()

            logger.info("Interest push sent to user=%s: %d items", uid_str[:8], len(items))
        except Exception:
            logger.exception("push_interest_content failed for user=%s", uid_str[:8])


async def push_chinese_literature():
    """Push Chinese literature (poetry/idiom/history) at higher frequency (~3h).
    Separate throttle: 2h cooldown, max 5/day. Runs alongside daily_content."""
    now = datetime.now(BEIJING_TZ)
    # Only push during waking hours 8:00-22:00
    if now.hour < 8 or now.hour >= 22:
        return

    content = None
    for uid in online_users():
        try:
            from uuid import UUID
            from app.models.proactive_push import ProactivePush
            from app.database import async_session

            # Check throttle: max 1 per 2 hours, 5 per day
            async with async_session() as db:
                today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
                two_hours_ago = now - timedelta(hours=2)
                r = await db.execute(
                    select(func.count(ProactivePush.id)).where(
                        ProactivePush.user_id == UUID(uid),
                        ProactivePush.push_type == "chinese_literature",
                        ProactivePush.created_at >= today_start,
                    )
                )
                count_today = r.scalar() or 0
                if count_today >= 5:
                    continue
                r2 = await db.execute(
                    select(func.count(ProactivePush.id)).where(
                        ProactivePush.user_id == UUID(uid),
                        ProactivePush.push_type == "chinese_literature",
                        ProactivePush.created_at >= two_hours_ago,
                    )
                )
                if (r2.scalar() or 0) > 0:
                    continue
        except Exception:
            continue

        try:
            # Generate content once and reuse for all users
            if content is None:
                raw = await llm_router.chat([{"role": "user", "content": CHINESE_LITERATURE_PROMPT}])
                content = _clean_llm_content(raw or "")[:400]

            if not content:
                continue

            label = "📜 国学经典"
            if content.startswith("📜"):
                label = "📜 古诗词鉴赏"
            elif content.startswith("📚"):
                label = "📚 每日成语"
            elif content.startswith("🏛"):
                label = "🏛️ 历史典故"

            # delta = full content for discover card, data = structured for future use
            payload = {"type": "proactive", "delta": content, "skill": "chinese_literature", "data": {"literature": {"display_name": label, "content": content}}}
            await send_to_user(uid, payload)

            async with async_session() as db:
                db.add(ProactivePush(user_id=UUID(uid), push_type="chinese_literature", message_preview=content[:50]))
                await db.commit()
        except Exception:
            pass


async def seed_daily_content_configs():
    """Insert default daily content configs. Safe to call — uses ON CONFLICT DO NOTHING pattern."""
    defaults = [
        ("daily_topic", "💬 每日话题", DAILY_TOPIC_PROMPT, 1),
        ("content_card", "🌟 今日卡片", CONTENT_CARD_PROMPT, 2),
        ("chinese_poetry", "📜 每日古诗词", CHINESE_POETRY_PROMPT, 3),
        ("chinese_idiom", "📚 每日成语", CHINESE_IDIOM_PROMPT, 4),
        ("chinese_history", "🏛️ 每日典故", CHINESE_HISTORY_PROMPT, 5),
    ]
    try:
        async with async_session() as db:
            from app.models.daily_content_config import DailyContentConfig
            for ctype, name, prompt, prio in defaults:
                existing = await db.execute(select(DailyContentConfig).where(DailyContentConfig.content_type == ctype))
                if existing.scalar_one_or_none() is None:
                    db.add(DailyContentConfig(content_type=ctype, display_name=name, prompt=prompt, priority=prio))
            await db.commit()
            logger.info("seeded daily_content_configs defaults")
    except Exception:
        logger.exception("seed daily_content_configs failed")


DAILY_TOPIC_PROMPT = """生成一个有趣的每日话题（20字以内），可以引发用户思考和分享。话题要轻松自然，像朋友聊天。不要涉及政治敏感话题。
例如: "今天最让你开心的一件小事是什么？" "如果明天是世界末日，你会怎么过？"

每日话题:"""

CHINESE_POETRY_PROMPT = """你是一位语文老师。请推荐一首经典古诗词（中小学必背优先），格式如下：

📜 《诗词名》 — 作者（朝代）
原文（选最经典的两句）
🎓 赏析: 一句话解释含义和意境（25字以内）

示例：
📜 《静夜思》 — 李白（唐）
床前明月光，疑是地上霜。
🎓 赏析: 以月光寄托思乡之情，语言朴素意境深远。

今日古诗词:"""

CHINESE_IDIOM_PROMPT = """你是一位语文老师。请推荐一个常用成语，包含出处和用法，格式如下：

📚 成语名
💬 释义: 一句话解释（15字以内）
📖 出处: 原始出处（10字以内）
✍️ 例句: 一个生活化的例句（20字以内）

示例：
📚 画龙点睛
💬 释义: 在关键处加上精辟语句使内容更生动
📖 出处: 《历代名画记》
✍️ 例句: 这篇文章结尾那句话真是画龙点睛之笔！

今日成语:"""

CHINESE_HISTORY_PROMPT = """你是一位历史老师。请分享一个有趣的历史典故，格式如下：

🏛️ 典故名
📅 朝代
📝 故事: 用通俗语言简述（50字以内，要有趣）
💡 启示: 一句话启示（15字以内）

示例：
🏛️ 破釜沉舟
📅 秦朝末年
📝 项羽率军渡河后下令砸锅沉船，只留三天口粮，以示决一死战。将士们见无退路，奋勇杀敌，最终大败秦军。
💡 启示: 断绝退路才能全力以赴

今日典故:"""

CHINESE_LITERATURE_PROMPT = """你是一位语文老师。请随机选择以下一种类型生成内容（每种概率相等）:

类型A — 古诗词:
📜 《诗词名》 — 作者（朝代）
原文（选最经典两句）
🎓 一句话赏析（25字以内）

类型B — 成语:
📚 成语名
💬 释义（15字以内）| 📖 出处 | ✍️ 例句（20字以内）

类型C — 历史典故:
🏛️ 典故名 · 📅 朝代
📝 简述（50字以内，有趣）
💡 启示（15字以内）

注意: 只返回一种类型的内容，不要同时返回多种。优先选择中小学课本常见的篇目。

今日语文:"""


async def send_connect_greeting(user_id: str) -> str | None:
    """One consolidated greeting on app open.
    Uses its OWN throttle: once per day, independent of proactive push quota."""
    now = datetime.now(BEIJING_TZ)

    # Greeting-only throttle: once per day, skip quiet hours
    if now.hour >= 22 or now.hour < 8:
        logger.debug("connect greeting: quiet hours for %s", user_id[:8])
        return None

    # Check if greeting already sent today
    from uuid import UUID
    from app.models.proactive_push import ProactivePush
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    async with async_session() as db:
        r = await db.execute(
            select(func.count(ProactivePush.id)).where(
                ProactivePush.user_id == UUID(user_id),
                ProactivePush.push_type == "greeting",
                ProactivePush.created_at >= today_start,
            )
        )
        if (r.scalar() or 0) > 0:
            logger.debug("connect greeting: already sent today for %s", user_id[:8])
            return None

    parts = []
    async with async_session() as db:
        w = await proactive_service._check_weather(user_id, now)
        if w: parts.append(w)

        c = await proactive_service._check_calendar(user_id, now, db)
        if c: parts.append(c)

        r = await db.execute(
            select(UserMemory).where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc()).limit(8)
        )
        memories = r.scalars().all()
        if len(memories) >= 2:
            mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories)
            prompt = GREETING_PROMPT.format(now=now.strftime("%H:%M"), memories=mem_text)
            try:
                mem = await llm_router.chat([{"role": "user", "content": prompt}])
                mem = (mem or "").strip()
                # Filter LLM non-empty-but-meaningless responses
                if mem and len(mem) > 2 and mem not in ("暂无", "无", "没有", "暂无特别信息", "。", "空"):
                    parts.append(mem)
                else:
                    logger.debug("greeting: LLM returned empty/meaningless: %r", mem[:20] if mem else "")
            except Exception:
                pass

    if parts:
        msg = "\n".join(parts)
        # Persist to DB and send via _do_push (no need for ws_chat.py to send again)
        await proactive_service._do_push(user_id, now, msg, skill="greeting")
        logger.info("connect greeting sent to %s: %s", user_id[:8], msg[:50])
        return None  # already sent by _do_push
    logger.debug("connect greeting: no content for %s", user_id[:8])
    return None
