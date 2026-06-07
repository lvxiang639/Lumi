import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.database import get_db
from app.models import Countdown, User
from app.api.deps import get_current_user
from pydantic import BaseModel
from datetime import datetime

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/countdown", tags=["countdown"])


class CountdownCreate(BaseModel):
    title: str
    target_date: datetime
    note: str = ""


@router.get("")
async def list_countdowns(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Countdown)
        .where(Countdown.user_id == current_user.id)
        .order_by(desc(Countdown.target_date))
    )
    items = result.scalars().all()
    return {
        "items": [
            {
                "id": str(c.id),
                "title": c.title,
                "target_date": c.target_date.isoformat(),
                "note": c.note,
                "created_at": c.created_at.isoformat(),
            }
            for c in items
        ]
    }


@router.post("", status_code=201)
async def create_countdown(
    req: CountdownCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    c = Countdown(
        user_id=current_user.id,
        title=req.title,
        target_date=req.target_date,
        note=req.note,
    )
    db.add(c)
    await db.commit()
    await db.refresh(c)
    return {"id": str(c.id), "title": c.title}


@router.delete("/{countdown_id}")
async def delete_countdown(
    countdown_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Countdown).where(
            Countdown.id == countdown_id,
            Countdown.user_id == current_user.id,
        )
    )
    c = result.scalar_one_or_none()
    if not c:
        raise HTTPException(404, "Not found")
    await db.delete(c)
    await db.commit()
    return {"status": "deleted"}
