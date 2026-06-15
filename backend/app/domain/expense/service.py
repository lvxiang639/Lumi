"""Domain service for expense analysis — weekly insights."""

import logging
from datetime import datetime, timezone, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

logger = logging.getLogger(__name__)
BEIJING_TZ = timezone(timedelta(hours=8))


class ExpenseService:
    """Domain service for expense analysis operations."""

    @staticmethod
    async def get_weekly_insights(user_id: UUID, db: AsyncSession, llm_router) -> dict:
        """Generate a weekly insight report from expenses, emotions, and memories."""
        from app.models.emotion_state import UserEmotionState
        from app.models.user_memory import UserMemory
        from app.models import ExpenseRecord

        now = datetime.now(BEIJING_TZ)
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
                ExpenseRecord.user_id == user_id,
                ExpenseRecord.recorded_at >= week_start,
            )
            .group_by(ExpenseRecord.category)
        )
        exp_rows = exp_result.all()
        total_expense = sum(float(row[1]) for row in exp_rows)
        top_category = max(exp_rows, key=lambda r: float(r[1]))[0] if exp_rows else None
        exp_count = sum(row[2] for row in exp_rows)

        # 2. Emotion trend
        emo_result = await db.execute(
            select(UserEmotionState.current_emotion, UserEmotionState.intensity)
            .where(UserEmotionState.user_id == user_id)
        )
        emo_row = emo_result.first()
        current_emotion = emo_row[0] if emo_row else "calm"
        emo_intensity = float(emo_row[1]) if emo_row else 0.0

        # 3. Memory count
        mem_count = await db.execute(
            select(func.count(UserMemory.id)).where(UserMemory.user_id == user_id)
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
        }
