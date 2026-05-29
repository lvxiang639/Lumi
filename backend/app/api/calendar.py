from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.database import get_db
from app.models import CalendarEvent, User
from app.api.deps import get_current_user
from app.schemas.calendar import CalendarEventItem, CreateCalendarEvent, UpdateCalendarEvent

router = APIRouter(prefix="/api/calendar", tags=["calendar"])


def _event_to_item(e: CalendarEvent) -> CalendarEventItem:
    return CalendarEventItem(
        id=str(e.id), title=e.title, time=e.time,
        repeat_rule=e.repeat_rule, notified=e.notified,
        created_at=e.created_at, updated_at=e.updated_at,
    )


@router.get("")
async def list_events(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CalendarEvent)
        .where(CalendarEvent.user_id == current_user.id)
        .order_by(desc(CalendarEvent.time))
    )
    events = result.scalars().all()
    return {"items": [_event_to_item(e) for e in events]}


@router.post("", status_code=201)
async def create_event(
    req: CreateCalendarEvent,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CalendarEventItem:
    event = CalendarEvent(
        user_id=current_user.id,
        title=req.title,
        time=req.time,
        repeat_rule=req.repeat_rule,
    )
    db.add(event)
    await db.commit()
    await db.refresh(event)
    return _event_to_item(event)


@router.get("/{event_id}")
async def get_event(
    event_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CalendarEventItem:
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.user_id == current_user.id,
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(404, "Event not found")
    return _event_to_item(event)


@router.put("/{event_id}")
async def update_event(
    event_id: UUID,
    req: UpdateCalendarEvent,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CalendarEventItem:
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.user_id == current_user.id,
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(404, "Event not found")

    if req.title is not None:
        event.title = req.title
    if req.time is not None:
        event.time = req.time
    if req.repeat_rule is not None:
        event.repeat_rule = req.repeat_rule

    await db.commit()
    await db.refresh(event)
    return _event_to_item(event)


@router.delete("/{event_id}")
async def delete_event(
    event_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.id == event_id,
            CalendarEvent.user_id == current_user.id,
        )
    )
    event = result.scalar_one_or_none()
    if not event:
        raise HTTPException(404, "Event not found")

    await db.delete(event)
    await db.commit()
    return {"status": "deleted"}
