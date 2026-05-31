import logging
from datetime import datetime, timezone, timedelta
from uuid import UUID

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import async_session
from app.models import CalendarEvent, ExpenseRecord, User
from app.services.llm_service import llm_router

logger = logging.getLogger("briefing")

BEIJING_TZ = timezone(timedelta(hours=8))

BRIEFING_PROMPT = """请根据以下信息生成一段温馨的早晨问候简报（不超过200字）：

今日日期：{date}
天气概况：{weather}
日历提醒：{calendar}
昨日消费：{expenses}

要求：
1. 开头用一句话问候（融入天气和日期感觉），语气亲切
2. 自然地列出今日待办事项
3. 提一下昨天的消费情况
4. 结尾给一句鼓励或祝福

请直接输出简报内容，不需要标题或格式标记。"""


async def generate_briefing(user_id: UUID) -> str | None:
    """Generate morning briefing text for a user.

    Returns None if there's nothing worth briefing about.
    """

    now = datetime.now(BEIJING_TZ)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = today_start + timedelta(days=1)
    yesterday_start = today_start - timedelta(days=1)

    async with async_session() as db:
        # Today's calendar events
        cal_result = await db.execute(
            select(CalendarEvent)
            .where(
                CalendarEvent.user_id == user_id,
                CalendarEvent.time >= today_start,
                CalendarEvent.time < today_end,
            )
            .order_by(CalendarEvent.time)
        )
        events = cal_result.scalars().all()
        calendar_text = "\n".join(
            f"- {e.time.strftime('%H:%M')} {e.title}" for e in events
        ) if events else "今天没有日程安排"

        # Yesterday's expenses
        exp_result = await db.execute(
            select(func.sum(ExpenseRecord.amount))
            .where(
                ExpenseRecord.user_id == user_id,
                ExpenseRecord.recorded_at >= yesterday_start,
                ExpenseRecord.recorded_at < today_start,
            )
        )
        total = exp_result.scalar() or 0.0
        expenses_text = f"共 ¥{total:.2f}" if total > 0 else "昨日无消费"

        # Weather (minimal — user's default city or just skip detail)
        weather_text = "天气晴朗"  # simplified; real weather would need city info

    # Build briefing via LLM
    prompt = BRIEFING_PROMPT.format(
        date=now.strftime("%Y年%m月%d日 %A"),
        weather=weather_text,
        calendar=calendar_text,
        expenses=expenses_text,
    )

    try:
        return await llm_router.chat([
            {"role": "user", "content": prompt},
        ])
    except Exception:
        logger.exception("briefing LLM failed")
        return None


async def check_and_send_briefings(send_callback) -> None:
    """Called by notification poller. Sends briefing to users who:
    - Are in the 8:00 AM window (Beijing time)
    - Haven't received a briefing today
    - Are currently connected (send_callback handles this)
    """
    now = datetime.now(BEIJING_TZ)
    if now.hour != 8:
        return

    async with async_session() as db:
        result = await db.execute(
            select(User).where(
                User.last_briefing_date == None
            ) | select(User).where(
                User.last_briefing_date < now.replace(hour=0, minute=0, second=0, microsecond=0)
            )
        )
        users = result.scalars().all()

    for user in users:
        text = await generate_briefing(user.id)
        if text:
            # Update briefing date
            async with async_session() as db:
                r = await db.execute(
                    select(User).where(User.id == user.id)
                )
                u = r.scalar_one_or_none()
                if u:
                    u.last_briefing_date = now.replace(
                        hour=0, minute=0, second=0, microsecond=0
                    )
                    await db.commit()

            await send_callback(user.id, text)
            logger.info("Briefing sent to user=%s", str(user.id)[:8])
