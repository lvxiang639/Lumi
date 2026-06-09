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


class ProactiveService:
    def __init__(self):
        self._task: asyncio.Task | None = None
        self._interval = settings.notification_check_interval * 180  # ~3 hours
        self._last_push: dict[str, datetime] = {}      # user_id → last push time
        self._push_count: dict[str, tuple[int, datetime]] = {}  # user_id → (count, day)
        self._news_cache: dict[str, tuple[list[dict], datetime]] = {}  # city → (items, time)

    async def _poll(self):
        while True:
            try:
                await self._check_all()
            except Exception:
                logger.exception("proactive poll error")
            await asyncio.sleep(self._interval)

    async def _check_all(self):
        users = online_users()
        if not users:
            return

        now = datetime.now(BEIJING_TZ)
        for uid in users:
            try:
                await self._check_user(uid, now)
            except Exception:
                logger.exception("proactive check failed for user=%s", uid[:8])

    async def _check_water(self, user_id: str, now: datetime) -> str | None:
        """Remind to drink water every 2 hours during daytime (8-22)."""
        if now.hour < 8 or now.hour > 22:
            logger.debug("proactive water: outside daytime (hour=%d)", now.hour)
            return None
        last = self._last_push.get(user_id)
        if last and (now - last).total_seconds() < 7200:
            return None
        hour = now.hour
        return f"💧 已经{hour}点了，记得喝杯水哦~ 今天也要元气满满！"

    async def _check_user(self, user_id: str, now: datetime):
        """Consolidated check — build one combined message (max 1 push per cycle)."""
        logger.info("proactive check: [0] starting scan for %s", user_id[:8])
        if not self._can_push(user_id, now):
            logger.info("proactive check: throttled (cooldown/limit) for %s", user_id[:8])
            return

        async with async_session() as db:
            r = await db.execute(select(User).where(User.id == user_id))
            if not r.scalar_one_or_none():
                return
            parts = []

            logger.info("proactive check: [1/8] weather for %s", user_id[:8])
            w = await self._check_weather(user_id, now)
            logger.info("proactive check: weather -> %s", "HIT" if w else "SKIP")
            if w: parts.append(w)

            logger.info("proactive check: [2/8] calendar for %s", user_id[:8])
            c = await self._check_calendar(user_id, now, db)
            logger.info("proactive check: calendar -> %s", "HIT" if c else "SKIP")
            if c: parts.append(c)

            logger.info("proactive check: [3/8] expense for %s", user_id[:8])
            e = await self._check_expense(user_id, now, db)
            logger.info("proactive check: expense -> %s", "HIT" if e else "SKIP")
            if e: parts.append(e)

            logger.info("proactive check: [4/8] idle for %s", user_id[:8])
            idle = await self._check_idle(user_id, now, db)
            logger.info("proactive check: idle -> %s", "HIT" if idle else "SKIP")
            if idle: parts.append(idle)

            logger.info("proactive check: [5/8] water for %s", user_id[:8])
            water = await self._check_water(user_id, now)
            logger.info("proactive check: water -> %s", "HIT" if water else "SKIP")
            if water: parts.append(water)

            logger.info("proactive check: [6/8] emotion for %s", user_id[:8])
            emo = await self._check_emotion(user_id, now, db)
            logger.info("proactive check: emotion -> %s", "HIT" if emo else "SKIP")
            if emo: parts.append(emo)

            logger.info("proactive check: [7/8] memory for %s", user_id[:8])
            mem = await self._check_memory(user_id, now, db)
            logger.info("proactive check: memory -> %s", "HIT" if mem else "SKIP")
            if mem: parts.append(mem)

            logger.info("proactive check: %d parts collected for %s", len(parts), user_id[:8])
            if parts:
                msg = "\\n".join(parts)
                await self._do_push(user_id, now, msg, skill=None)

            logger.info("proactive check: [8/8] news for %s", user_id[:8])
            news = await self._check_news(user_id, now)
            logger.info("proactive check: news -> %s", f"{len(news)} items" if news else "SKIP")
            if news and self._can_push(user_id, now):
                await self._do_push(user_id, now, "📰 本地资讯更新", skill="news", data=news)
    def _can_push(self, user_id: str, now: datetime) -> bool:
        """Throttle: max 1 push per 2 hours, max 3 per day."""
        # 2-hour cooldown
        last = self._last_push.get(user_id)
        if last and (now - last).total_seconds() < 7200:
            return False
        # Daily limit
        today = now.date()
        count, day = self._push_count.get(user_id, (0, today))
        if day != today:
            count = 0
        if count >= 3:
            return False
        return True

    async def _do_push(self, user_id: str, now: datetime, msg: str,
                       skill: str | None = None, data: dict | None = None):
        """Send push and update throttles."""
        payload = {"type": "proactive", "delta": msg}
        if skill: payload["skill"] = skill
        if data: payload["data"] = data
        await send_to_user(user_id, payload)

        self._last_push[user_id] = now
        today = now.date()
        count, day = self._push_count.get(user_id, (0, today))
        if day != today:
            count = 0
        self._push_count[user_id] = (count + 1, today)
        logger.info("proactive push #%d to %s: %s", count + 1, user_id[:8], msg[:50])

    async def _check_weather(self, user_id: str, now: datetime) -> str | None:
        """Check weather with 2-hour cache per city to reduce LLM cost."""
        try:
            city = await get_city(user_id=user_id)
            cached = self._weather_cache.get(city)
            if cached:
                msg, ts = cached
                if (now - ts).total_seconds() < 7200:  # 2 hour cache
                    return msg if msg != "__NONE__" else None
            prompt = WEATHER_PROMPT.format(now=now.strftime("%H:%M"), city=city)
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            self._weather_cache[city] = (result or "__NONE__", now)
            return result if result else None
        except Exception:
            return None

    async def _check_calendar(
        self, user_id: str, now: datetime, db
    ) -> str | None:
        """Check for events in the next 60 minutes."""
        window = now + timedelta(hours=1)
        r = await db.execute(
            select(CalendarEvent)
            .where(
                CalendarEvent.user_id == user_id,
                CalendarEvent.time >= now,
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
            return result if result else None
        except Exception:
            return f"喵~ {len(events)}个日程快到了，记得看看哦 🐱"

    async def _check_expense(
        self, user_id: str, now: datetime, db
    ) -> str | None:
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

        return "喵~ 昨天好像忘记记账了，要现在记一下吗？💰"

    async def _check_idle(
        self, user_id: str, now: datetime, db
    ) -> str | None:
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

        return "喵~ 好久不见！你回来啦 🐱"

    async def _check_memory(
        self, user_id: str, now: datetime, db
    ) -> str | None:
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
            return result if result else None
        except Exception:
            return None

    async def _check_emotion(
        self, user_id: str, now: datetime, db
    ) -> str | None:
        """Check if user has been sad/angry and needs care."""
        # Throttle via global push system
        last = self._last_push.get(user_id)
        if last and (now - last).total_seconds() < 14400:
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
        return messages.get(state.current_emotion)

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

当前时间: {now}
用户信息:
{memories}

小猫灵犀的欢迎语:"""


async def send_connect_greeting(user_id: str) -> str | None:
    """One consolidated greeting on app open — weather + calendar + memory."""
    now = datetime.now(BEIJING_TZ)
    if not proactive_service._can_push(user_id, now):
        return None

    parts = []
    async with async_session() as db:
        # Weather
        w = await proactive_service._check_weather(user_id, now)
        if w: parts.append(w)

        # Calendar
        c = await proactive_service._check_calendar(user_id, now, db)
        if c: parts.append(c)

        # Memory
        r = await db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(8)
        )
        memories = r.scalars().all()
        if len(memories) >= 2:
            mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories)
            prompt = GREETING_PROMPT.format(now=now.strftime("%H:%M"), memories=mem_text)
            try:
                mem = await llm_router.chat([{"role": "user", "content": prompt}])
                mem = (mem or "").strip()
                if mem: parts.append(mem)
            except Exception:
                pass

    if parts:
        msg = "\n".join(parts)
        # Update throttle (same as _do_push) but let ws_chat.py send the actual message
        proactive_service._last_push[user_id] = now
        today = now.date()
        count, day = proactive_service._push_count.get(user_id, (0, today))
        if day != today:
            count = 0
        proactive_service._push_count[user_id] = (count + 1, today)
        logger.info("proactive push #%d to %s: %s", count + 1, user_id[:8], msg[:50])
        return msg
    return None
