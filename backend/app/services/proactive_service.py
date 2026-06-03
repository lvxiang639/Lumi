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
        self._interval = settings.notification_check_interval * 30  # ~30 min
        self._last_emotion_care: dict[str, datetime] = {}  # user_id → last care sent

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

    async def _check_user(self, user_id: str, now: datetime):
        """Run all checks for one user. Only send ONE message (first hit)."""

        async with async_session() as db:
            # Get user
            r = await db.execute(select(User).where(User.id == user_id))
            user = r.scalar_one_or_none()
            if not user:
                return

            # ── Check 1: Weather alert ──
            msg = await self._check_weather(user_id, now)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                logger.info("proactive weather sent to %s", user_id[:8])
                return

            # ── Check 2: Upcoming calendar event ──
            msg = await self._check_calendar(user_id, now, db)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                logger.info("proactive calendar sent to %s", user_id[:8])
                return

            # ── Check 3: Missing expense log ──
            msg = await self._check_expense(user_id, now, db)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                return

            # ── Check 4: Long idle ──
            msg = await self._check_idle(user_id, now, db)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                return

            # ── Check 5: Memory topic ──
            msg = await self._check_memory(user_id, now, db)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                return

            # ── Check 6: Emotion care ──
            msg = await self._check_emotion(user_id, now, db)
            if msg:
                await send_to_user(user_id, {
                    "type": "llm_stream", "delta": msg,
                })
                await send_to_user(user_id, {"type": "done"})
                return

    async def _check_weather(self, user_id: str, now: datetime) -> str | None:
        """Check if there's weather worth warning about."""
        # Only check once per 2 hours to avoid spamming
        # For now: check every cycle but use a simple heuristic
        try:
            city = await get_city(user_id=user_id)
            prompt = WEATHER_PROMPT.format(
                now=now.strftime("%H:%M"), city=city
            )
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
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
        """Use memories to start a conversation."""
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
            return result if result else None
        except Exception:
            return None

    async def _check_emotion(
        self, user_id: str, now: datetime, db
    ) -> str | None:
        """Check if user has been sad/angry and needs care."""
        # Don't spam — once per 4 hours
        last = self._last_emotion_care.get(user_id)
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

        self._last_emotion_care[user_id] = now

        messages = {
            "sad": "喵~ 感觉你心情不太好，要聊聊吗？我一直在这里陪你 🐱",
            "angry": "喵... 看起来你有点生气，深呼吸，一切都会好起来的~",
            "worried": "喵~ 你好像有点焦虑，需要我帮你做点什么吗？",
        }
        return messages.get(state.current_emotion)

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

# In-memory tracker: user_id → last greeting time
_last_greeting: dict[str, datetime] = {}

GREETING_PROMPT = """你是一只关心主人的小猫灵犀。根据以下用户信息和当前时间，想一个简短温暖的欢迎语（不超过35字）。
要自然、可爱，不要刻意复述记忆。如果没有特别的信息就返回空。

当前时间: {now}
用户信息:
{memories}

小猫灵犀的欢迎语:"""


async def send_memory_greeting(user_id: str) -> str | None:
    """Generate a personalized greeting on connect. One per 6 hours."""
    now = datetime.now(BEIJING_TZ)
    last = _last_greeting.get(user_id)
    if last and (now - last).total_seconds() < 21600:  # 6 hours
        return None

    _last_greeting[user_id] = now

    async with async_session() as db:
        r = await db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(8)
        )
        memories = r.scalars().all()
        if len(memories) < 2:
            return None

        mem_text = "\n".join(f"- {m.key}: {m.value}" for m in memories)
        prompt = GREETING_PROMPT.format(
            now=now.strftime("%H:%M"), memories=mem_text
        )
        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            result = (result or "").strip()
            return result if result else None
        except Exception:
            return None
