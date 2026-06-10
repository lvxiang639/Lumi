"""Push notification API — free polling-based, no third-party service."""

import logging
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_db
from app.models import User
from app.api.deps import get_current_user
from app.services.fcm_service import get_latest_pushes

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/push", tags=["push"])

BEIJING_TZ = timezone(timedelta(hours=8))


@router.get("/poll")
async def poll_pushes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Check for new proactive pushes since last poll.
    App calls this every 5-15 minutes to show local notifications."""
    from datetime import datetime as dt
    # Get pushes from last 30 minutes
    since = dt.now(BEIJING_TZ) - timedelta(minutes=30)
    pushes = await get_latest_pushes(str(current_user.id), since)
    return {"items": pushes, "server_time": dt.now(BEIJING_TZ).isoformat()}

