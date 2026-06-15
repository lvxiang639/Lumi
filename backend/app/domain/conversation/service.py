"""Domain service for conversation operations — summary, diary, email."""

import logging
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

logger = logging.getLogger(__name__)

SUMMARY_PROMPT = """请将以下对话提炼为一份简洁的摘要邮件。格式如下：

- 标题行：用一句话概括对话主题
- 关键要点：列点说明讨论的主要内容
- 待办事项：如果有的话
- 对话时间线：简短的时间顺序总结

对话内容：
{messages}

请直接输出邮件正文（纯文本），不要加额外的解释。"""

DIARY_PROMPT = """你是一位贴心的日记助手。请根据以下对话内容，以第一人称的视角写一篇简短的日记（100-200字）。

要求：
1. 以"今天"开头
2. 包含主要讨论内容和个人感受
3. 语气自然温暖
4. 适当加入一些 emoji

对话内容：
{messages}

请直接输出日记内容。"""


class ConversationService:
    """Domain service for conversation operations."""

    @staticmethod
    async def generate_summary(conv_id: UUID, db: AsyncSession, llm_router) -> str:
        """Fetch conversation messages and generate an LLM summary."""
        from app.models.message import Message

        msgs_result = await db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at)
        )
        messages = msgs_result.scalars().all()
        if not messages:
            raise ValueError("对话内容为空")

        lines = []
        for m in messages:
            role = "用户" if m.role.value == "user" else "AI"
            lines.append(f"{role}: {m.content or ''}")
        dialogue = "\n".join(lines)

        prompt = SUMMARY_PROMPT.format(messages=dialogue)
        try:
            summary = await llm_router.chat([{"role": "user", "content": prompt}])
        except Exception:
            logger.exception("LLM summary failed")
            raise RuntimeError("摘要生成失败")

        if not summary or not summary.strip():
            raise RuntimeError("摘要为空")

        return summary.strip()

    @staticmethod
    async def generate_diary(conv_id: UUID, db: AsyncSession, llm_router) -> str:
        """Generate a first-person diary entry from conversation history."""
        from app.models.message import Message

        msgs_result = await db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at)
        )
        messages = msgs_result.scalars().all()
        if not messages:
            raise ValueError("对话内容为空")

        lines = []
        for m in messages:
            role = "用户" if m.role.value == "user" else "AI"
            lines.append(f"{role}: {m.content or ''}")
        dialogue = "\n".join(lines)

        prompt = DIARY_PROMPT.format(messages=dialogue)
        try:
            diary = await llm_router.chat([{"role": "user", "content": prompt}])
        except Exception:
            logger.exception("LLM diary failed")
            raise RuntimeError("日记生成失败")

        if not diary or not diary.strip():
            raise RuntimeError("日记为空")

        return diary.strip()

    @staticmethod
    async def email_summary(
        conv_id: UUID,
        user_id: UUID,
        user_email: str,
        conv_title: str,
        db: AsyncSession,
        llm_router,
        send_email_fn,
    ) -> str:
        """Generate summary, send email, save SentEmail record. Returns email address."""
        from app.models import SentEmail

        if not user_email:
            raise ValueError("请先在个人资料中设置邮箱地址")

        summary = await ConversationService.generate_summary(conv_id, db, llm_router)

        subject = f"对话摘要: {conv_title}"
        success = await send_email_fn(user_email, subject, summary)
        if not success:
            raise RuntimeError("邮件发送失败，请检查邮箱配置")

        db.add(SentEmail(
            user_id=user_id,
            conv_title=conv_title,
            recipient=user_email,
            summary_preview=summary[:200],
        ))
        await db.commit()

        return user_email
