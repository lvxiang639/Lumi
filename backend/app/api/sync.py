from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import CalendarEvent, ExpenseRecord, User
from app.api.deps import get_current_user
from app.schemas.sync import SyncRequest, SyncResponse

router = APIRouter(prefix="/api/sync", tags=["sync"])


@router.post("")
async def sync(
    req: SyncRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    # Process batch actions from client: create/update/delete for events and expenses
    for action in req.events:
        action_data = action.data or {}
        if action.action == "create":
            if "time" not in action_data:
                raise HTTPException(400, "Missing 'time' for calendar event")
            event = CalendarEvent(
                id=action_data.get("id"),
                user_id=current_user.id,
                title=action_data.get("title", ""),
                time=datetime.fromisoformat(action_data["time"]),
                repeat_rule=action_data.get("repeat_rule", "none"),
            )
            db.add(event)
        elif action.action == "update":
            result = await db.execute(
                select(CalendarEvent).where(
                    CalendarEvent.id == action_data.get("id"),
                    CalendarEvent.user_id == current_user.id,
                )
            )
            event = result.scalar_one_or_none()
            if event:
                if "title" in action_data:
                    event.title = action_data["title"]
                if "time" in action_data:
                    event.time = datetime.fromisoformat(action_data["time"])
                if "repeat_rule" in action_data:
                    event.repeat_rule = action_data["repeat_rule"]
        elif action.action == "delete":
            result = await db.execute(
                select(CalendarEvent).where(
                    CalendarEvent.id == action_data.get("id"),
                    CalendarEvent.user_id == current_user.id,
                )
            )
            event = result.scalar_one_or_none()
            if event:
                await db.delete(event)

    for action in req.expenses:
        action_data = action.data or {}
        if action.action == "create":
            expense = ExpenseRecord(
                id=action_data.get("id"),
                user_id=current_user.id,
                amount=float(action_data.get("amount", 0)),
                category=action_data.get("category", "其他"),
                remark=action_data.get("remark", ""),
                recorded_at=datetime.fromisoformat(action_data["recorded_at"]) if "recorded_at" in action_data else datetime.now(timezone.utc),
            )
            db.add(expense)
        elif action.action == "update":
            result = await db.execute(
                select(ExpenseRecord).where(
                    ExpenseRecord.id == action_data.get("id"),
                    ExpenseRecord.user_id == current_user.id,
                )
            )
            expense = result.scalar_one_or_none()
            if expense:
                if "amount" in action_data:
                    expense.amount = float(action_data["amount"])
                if "category" in action_data:
                    expense.category = action_data["category"]
                if "remark" in action_data:
                    expense.remark = action_data["remark"]
        elif action.action == "delete":
            result = await db.execute(
                select(ExpenseRecord).where(
                    ExpenseRecord.id == action_data.get("id"),
                    ExpenseRecord.user_id == current_user.id,
                )
            )
            expense = result.scalar_one_or_none()
            if expense:
                await db.delete(expense)

    await db.commit()

    # Fetch server-side changes newer than last_sync_at
    changes: dict = {"events": [], "expenses": []}

    events_result = await db.execute(
        select(CalendarEvent).where(
            CalendarEvent.user_id == current_user.id,
            CalendarEvent.updated_at > req.last_sync_at,
        )
    )
    for event in events_result.scalars().all():
        changes["events"].append({
            "id": str(event.id),
            "title": event.title,
            "time": event.time.isoformat(),
            "repeat_rule": event.repeat_rule,
            "notified": event.notified,
            "created_at": event.created_at.isoformat(),
            "updated_at": event.updated_at.isoformat(),
        })

    expenses_result = await db.execute(
        select(ExpenseRecord).where(
            ExpenseRecord.user_id == current_user.id,
            ExpenseRecord.updated_at > req.last_sync_at,
        )
    )
    for expense in expenses_result.scalars().all():
        changes["expenses"].append({
            "id": str(expense.id),
            "amount": float(expense.amount),
            "category": expense.category,
            "remark": expense.remark,
            "recorded_at": expense.recorded_at.isoformat(),
            "created_at": expense.created_at.isoformat(),
            "updated_at": expense.updated_at.isoformat(),
        })

    return SyncResponse(
        server_changes=changes,
        sync_at=datetime.now(timezone.utc),
    )
