import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select, update

from app.database import async_session
from app.models import CalendarEvent

logger = logging.getLogger("notification")

CHECK_INTERVAL = 60  # seconds


class NotificationService:
    def __init__(self):
        self._task: asyncio.Task | None = None

    async def _poll(self):
        while True:
            try:
                await self._check_and_notify()
            except Exception:
                logger.exception("notification poll error")
            await asyncio.sleep(CHECK_INTERVAL)

    async def _check_and_notify(self):
        now = datetime.now(timezone.utc)
        async with async_session() as db:
            result = await db.execute(
                select(CalendarEvent).where(
                    CalendarEvent.notified == False,
                    CalendarEvent.time <= now,
                )
            )
            events = result.scalars().all()

            for event in events:
                logger.info(
                    "NOTIFY: user=%s title=%s time=%s",
                    str(event.user_id)[:8], event.title, event.time.isoformat(),
                )
                event.notified = True

            if events:
                await db.commit()
                logger.info("notified %d events", len(events))

    def start(self):
        if self._task is None:
            self._task = asyncio.create_task(self._poll())
            logger.info("notification service started")

    async def stop(self):
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
            self._task = None
            logger.info("notification service stopped")


notification_service = NotificationService()
