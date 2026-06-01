from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from app.database import get_db
from app.models import ExpenseRecord, User
from app.api.deps import get_current_user
from app.schemas.expense import ExpenseItem, CreateExpense, UpdateExpense, ExpenseStats

router = APIRouter(prefix="/api/expenses", tags=["expenses"])


def _expense_to_item(e: ExpenseRecord) -> ExpenseItem:
    return ExpenseItem(
        id=str(e.id), amount=float(e.amount), category=e.category,
        remark=e.remark, recorded_at=e.recorded_at, created_at=e.created_at,
    )


@router.get("")
async def list_expenses(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExpenseRecord)
        .where(ExpenseRecord.user_id == current_user.id)
        .order_by(desc(ExpenseRecord.recorded_at))
    )
    expenses = result.scalars().all()
    return {"items": [_expense_to_item(e) for e in expenses]}


@router.post("", status_code=201)
async def create_expense(
    req: CreateExpense,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ExpenseItem:
    recorded_at = req.recorded_at or datetime.now(timezone.utc)
    expense = ExpenseRecord(
        user_id=current_user.id,
        amount=req.amount,
        category=req.category,
        remark=req.remark,
        recorded_at=recorded_at,
    )
    db.add(expense)
    await db.commit()
    await db.refresh(expense)
    return _expense_to_item(expense)


@router.get("/stats")
async def get_expense_stats(
    period: str = Query("month", pattern="^(week|month)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ExpenseStats:
    from datetime import datetime, timedelta

    # Use Beijing time for date filtering (user's timezone)
    beijing_tz = timezone(timedelta(hours=8))
    now = datetime.now(beijing_tz)
    if period == "week":
        start = (now - timedelta(days=now.weekday())).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
    else:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    rows_result = await db.execute(
        select(
            ExpenseRecord.category,
            func.sum(ExpenseRecord.amount),
        )
        .where(
            ExpenseRecord.user_id == current_user.id,
            ExpenseRecord.recorded_at >= start,
        )
        .group_by(ExpenseRecord.category)
    )
    by_category: dict[str, float] = {}
    total_expense = 0.0
    for category, total in rows_result.all():
        val = float(total)
        by_category[category] = val
        total_expense += val

    return ExpenseStats(
        total_expense=total_expense,
        total_income=0.0,
        by_category=by_category,
    )


@router.get("/{expense_id}")
async def get_expense(
    expense_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ExpenseItem:
    result = await db.execute(
        select(ExpenseRecord).where(
            ExpenseRecord.id == expense_id,
            ExpenseRecord.user_id == current_user.id,
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(404, "Expense not found")
    return _expense_to_item(expense)


@router.put("/{expense_id}")
async def update_expense(
    expense_id: UUID,
    req: UpdateExpense,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ExpenseItem:
    result = await db.execute(
        select(ExpenseRecord).where(
            ExpenseRecord.id == expense_id,
            ExpenseRecord.user_id == current_user.id,
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(404, "Expense not found")

    if req.amount is not None:
        expense.amount = req.amount
    if req.category is not None:
        expense.category = req.category
    if req.remark is not None:
        expense.remark = req.remark

    await db.commit()
    await db.refresh(expense)
    return _expense_to_item(expense)


@router.delete("/{expense_id}")
async def delete_expense(
    expense_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExpenseRecord).where(
            ExpenseRecord.id == expense_id,
            ExpenseRecord.user_id == current_user.id,
        )
    )
    expense = result.scalar_one_or_none()
    if not expense:
        raise HTTPException(404, "Expense not found")

    await db.delete(expense)
    await db.commit()
    return {"status": "deleted"}
