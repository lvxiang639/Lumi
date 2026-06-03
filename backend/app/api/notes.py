import logging
from uuid import UUID
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func

from app.api.deps import get_current_user
from app.database import get_db
from app.models import User, Note, MoodLog
from app.schemas.conversation import UpdateTitleRequest

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/notes", tags=["notes"])

BEIJING_TZ = timezone(timedelta(hours=8))


# ── Notes ──

@router.get("")
async def list_notes(
    note_type: str = Query("note", pattern="^(note|journal)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(Note)
        .where(Note.user_id == current_user.id, Note.note_type == note_type)
        .order_by(desc(Note.updated_at))
        .limit(50)
    )
    notes = r.scalars().all()
    return {
        "items": [{"id": str(n.id), "title": n.title, "content": n.content,
                   "note_type": n.note_type, "created_at": n.created_at.isoformat(),
                   "updated_at": n.updated_at.isoformat()} for n in notes]
    }


@router.post("", status_code=201)
async def create_note(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    note = Note(
        user_id=current_user.id,
        title=body.get("title", ""),
        content=body.get("content", ""),
        note_type=body.get("note_type", "note"),
    )
    db.add(note)
    await db.commit()
    await db.refresh(note)
    return {"id": str(note.id), "title": note.title, "content": note.content,
            "note_type": note.note_type, "created_at": note.created_at.isoformat(),
            "updated_at": note.updated_at.isoformat()}


@router.put("/{note_id}")
async def update_note(
    note_id: UUID, body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = r.scalar_one_or_none()
    if not note: raise HTTPException(404, "Note not found")
    if "title" in body: note.title = body["title"]
    if "content" in body: note.content = body["content"]
    await db.commit()
    return {"status": "ok"}


@router.delete("/{note_id}")
async def delete_note(
    note_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(select(Note).where(Note.id == note_id, Note.user_id == current_user.id))
    note = r.scalar_one_or_none()
    if not note: raise HTTPException(404, "Note not found")
    await db.delete(note); await db.commit()
    return {"status": "deleted"}


# ── Moods ──

@router.get("/moods")
async def list_moods(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(MoodLog)
        .where(MoodLog.user_id == current_user.id)
        .order_by(desc(MoodLog.created_at))
        .limit(50)
    )
    moods = r.scalars().all()
    return {
        "items": [{"id": str(m.id), "emotion": m.emotion, "intensity": m.intensity,
                   "note": m.note, "created_at": m.created_at.isoformat()} for m in moods]
    }


@router.post("/moods", status_code=201)
async def create_mood(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    mood = MoodLog(
        user_id=current_user.id,
        emotion=body.get("emotion", "calm"),
        intensity=body.get("intensity", 1.0),
        note=body.get("note"),
    )
    db.add(mood); await db.commit()
    return {"status": "ok"}


@router.get("/moods/stats")
async def mood_stats(
    period: str = Query("week", pattern="^(week|month)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    now = datetime.now(BEIJING_TZ)
    if period == "week":
        start = now - timedelta(days=now.weekday())
    else:
        start = now.replace(day=1)
    start = start.replace(hour=0, minute=0, second=0, microsecond=0)

    r = await db.execute(
        select(MoodLog.emotion, func.count(MoodLog.id))
        .where(MoodLog.user_id == current_user.id, MoodLog.created_at >= start)
        .group_by(MoodLog.emotion)
    )
    by_emotion = {row[0]: row[1] for row in r.all()}
    return {"by_emotion": by_emotion, "period": period}
