import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.config import settings
from app.database import async_session
from app.models import CalendarEvent

logger = logging.getLogger("notification")


def _add_month(t: datetime) -> datetime:
    """Advance *t* by one calendar month, clamping the day if needed."""
    import calendar as _calendar

    y, m, d = t.year, t.month, t.day
    m += 1
    if m > 12:
        m = 1
        y += 1
    last_day = _calendar.monthrange(y, m)[1]
    if d > last_day:
        d = last_day
    return t.replace(year=y, month=m, day=d)



class NotificationService:
    def __init__(self):
        self._task: asyncio.Task | None = None
        self._interval = settings.notification_check_interval

    async def _poll(self):
        while True:
            try:
                await self._check_and_notify()
            except Exception:
                logger.exception("notification poll error")
            await asyncio.sleep(self._interval)

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
                    "NOTIFY: user=%s title=%s time=%s repeat=%s",
                    str(event.user_id)[:8], event.title,
                    event.time.isoformat(), event.repeat_rule,
                )
                event.notified = True

                # Reschedule recurring events
                if event.repeat_rule != "none":
                    next_time = self._next_occurrence(event.time, event.repeat_rule)
                    if next_time:
                        db.add(CalendarEvent(
                            user_id=event.user_id,
                            title=event.title,
                            time=next_time,
                            repeat_rule=event.repeat_rule,
                        ))
                        logger.info(
                            "rescheduled: title=%s next=%s",
                            event.title, next_time.isoformat(),
                        )

            if events:
                await db.commit()
                logger.info("notified %d events", len(events))

    def _next_occurrence(self, time: datetime, rule: str) -> datetime | None:
        """Compute the next occurrence for a recurring event."""
        from datetime import timedelta

        if rule == "daily":
            return time + timedelta(days=1)
        elif rule == "weekly":
            return time + timedelta(weeks=1)
        elif rule == "monthly":
            # Advance one calendar month, clamping the day-of-month if needed
            # (e.g. Jan 31 → Feb 28/29).
            return _add_month(time)
        elif rule == "yearly":
            return time.replace(year=time.year + 1)
        return None

    def start(self):
        if self._task is None:
            self._task = asyncio.create_task(self._poll())
            logger.info("notification service started, interval=%ds", self._interval)

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
