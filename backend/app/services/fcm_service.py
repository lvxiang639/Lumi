"""Push notification polling endpoint — free, no third-party service needed."""

import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID
from sqlalchemy import select
from app.database import async_session
from app.models.proactive_push import ProactivePush

logger = logging.getLogger("push")
BEIJING_TZ = timezone(timedelta(hours=8))


async def get_latest_pushes(user_id: str, since: datetime | None = None) -> list[dict]:
    """Get latest proactive pushes for a user since a given time.
    Called by the App's periodic background check to show local notifications."""
    try:
        uid = UUID(user_id)
        async with async_session() as db:
            q = select(ProactivePush).where(ProactivePush.user_id == uid)
            if since:
                q = q.where(ProactivePush.created_at >= since)
            q = q.order_by(ProactivePush.created_at.desc()).limit(5)
            r = await db.execute(q)
            rows = r.scalars().all()
            return [
                {
                    "id": str(row.id),
                    "push_type": row.push_type,
                    "message": row.message_preview[:100],
                    "created_at": row.created_at.isoformat() if row.created_at else "",
                }
                for row in rows
            ]
    except Exception:
        logger.exception("get_latest_pushes failed")
        return []

