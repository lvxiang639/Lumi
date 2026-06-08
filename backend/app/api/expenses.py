from uuid import UUID
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func
from app.database import get_db
from app.models import ExpenseRecord, User
from app.models.emotion_state import UserEmotionState
from app.models.user_memory import UserMemory
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


@router.get("/insights/weekly")
async def get_weekly_insights(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Generate a weekly insight report from expenses, emotions, and memories."""
    from datetime import datetime, timedelta

    beijing_tz = timezone(timedelta(hours=8))
    now = datetime.now(beijing_tz)
    week_start = (now - timedelta(days=now.weekday())).replace(
        hour=0, minute=0, second=0, microsecond=0
    )

    # 1. Week's expenses
    exp_result = await db.execute(
        select(
            ExpenseRecord.category,
            func.sum(ExpenseRecord.amount),
            func.count(ExpenseRecord.id),
        )
        .where(
            ExpenseRecord.user_id == current_user.id,
            ExpenseRecord.recorded_at >= week_start,
        )
        .group_by(ExpenseRecord.category)
    )
    exp_rows = exp_result.all()
    total_expense = sum(float(row[1]) for row in exp_rows)
    top_category = max(exp_rows, key=lambda r: float(r[1]))[0] if exp_rows else None
    exp_count = sum(row[2] for row in exp_rows)

    # 2. Emotion trend (average intensity this week)
    emo_result = await db.execute(
        select(UserEmotionState.current_emotion, UserEmotionState.intensity)
        .where(UserEmotionState.user_id == current_user.id)
    )
    emo_row = emo_result.first()
    current_emotion = emo_row[0] if emo_row else "calm"
    emo_intensity = float(emo_row[1]) if emo_row else 0.0

    # 3. Memory count
    mem_count = await db.execute(
        select(func.count(UserMemory.id)).where(UserMemory.user_id == current_user.id)
    )
    total_memories = mem_count.scalar() or 0

    # 4. LLM summary
    summary_text = ""
    try:
        prompt = (
            f"根据以下用户数据，用2-3句温馨的话总结本周情况（不超过80字）：\n"
            f"本周支出: ¥{total_expense:.0f}，共{exp_count}笔，主要花在{top_category or '无'}\n"
            f"当前心情: {current_emotion}（强度{emo_intensity:.1f}）\n"
            f"已记录{total_memories}条生活信息\n"
            f"请用小猫灵犀的语气，温暖、简短。"
        )
        summary_text = await llm_router.chat([{"role": "user", "content": prompt}])
        summary_text = (summary_text or "").strip()
    except Exception:
        summary_text = f"本周支出 ¥{total_expense:.0f}，主要花在{top_category or '无'}。心情还不错~"

    return {
        "total_expense": total_expense,
        "expense_count": exp_count,
        "top_category": top_category,
        "current_emotion": current_emotion,
        "emo_intensity": emo_intensity,
        "total_memories": total_memories,
        "summary": summary_text,
        "week_start": week_start.isoformat(),
    }
