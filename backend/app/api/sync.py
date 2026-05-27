from datetime import datetime, timezone
from fastapi import APIRouter, Depends
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
        if action.action == "create":
            event = CalendarEvent(
                id=action.data.get("id"),
                user_id=current_user.id,
                title=action.data.get("title", ""),
                time=datetime.fromisoformat(action.data["time"]) if "time" in action.data else datetime.now(timezone.utc),
                repeat_rule=action.data.get("repeat_rule", "none"),
            )
            db.add(event)
        elif action.action == "update":
            result = await db.execute(
                select(CalendarEvent).where(
                    CalendarEvent.id == action.data.get("id"),
                    CalendarEvent.user_id == current_user.id,
                )
            )
            event = result.scalar_one_or_none()
            if event:
                if "title" in action.data:
                    event.title = action.data["title"]
                if "time" in action.data:
                    event.time = datetime.fromisoformat(action.data["time"])
                if "repeat_rule" in action.data:
                    event.repeat_rule = action.data["repeat_rule"]
        elif action.action == "delete":
            result = await db.execute(
                select(CalendarEvent).where(
                    CalendarEvent.id == action.data.get("id"),
                    CalendarEvent.user_id == current_user.id,
                )
            )
            event = result.scalar_one_or_none()
            if event:
                await db.delete(event)

    for action in req.expenses:
        if action.action == "create":
            expense = ExpenseRecord(
                id=action.data.get("id"),
                user_id=current_user.id,
                amount=float(action.data.get("amount", 0)),
                category=action.data.get("category", "其他"),
                remark=action.data.get("remark", ""),
                recorded_at=datetime.fromisoformat(action.data["recorded_at"]) if "recorded_at" in action.data else datetime.now(timezone.utc),
            )
            db.add(expense)
        elif action.action == "update":
            result = await db.execute(
                select(ExpenseRecord).where(
                    ExpenseRecord.id == action.data.get("id"),
                    ExpenseRecord.user_id == current_user.id,
                )
            )
            expense = result.scalar_one_or_none()
            if expense:
                if "amount" in action.data:
                    expense.amount = float(action.data["amount"])
                if "category" in action.data:
                    expense.category = action.data["category"]
                if "remark" in action.data:
                    expense.remark = action.data["remark"]
        elif action.action == "delete":
            result = await db.execute(
                select(ExpenseRecord).where(
                    ExpenseRecord.id == action.data.get("id"),
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
