import logging
import uuid

from sqlalchemy import select, desc

from app.database import async_session
from app.models import User, Conversation, Message
from app.services.skills.base import BaseSkill, SkillResult
from app.services.llm_service import llm_router
from app.services.email_service import send_email

logger = logging.getLogger("email_skill")

SUMMARY_PROMPT = """请将以下对话提炼为一份简洁的邮件摘要。格式如下：

对话主题：（用一句话概括）
关键要点：
- 要点1
- 要点2
待办事项：（如果有）
简短总结：

对话内容：
{dialogue}

请直接输出邮件正文:"""


class EmailSkill(BaseSkill):
    name = "email"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            uid = uuid.UUID(user_id)
        except (ValueError, TypeError):
            return SkillResult(text="用户信息异常")

        # 1. Get user's email
        async with async_session() as s:
            r = await s.execute(select(User).where(User.id == uid))
            user = r.scalar_one_or_none()

        if not user or not user.email:
            return SkillResult(
                text="请先在个人资料中设置你的邮箱地址，设置后再说一次就好。"
            )

        # 2. Get the most recent conversation
        async with async_session() as s:
            r = await s.execute(
                select(Conversation)
                .where(Conversation.user_id == uid)
                .order_by(desc(Conversation.updated_at))
                .limit(1)
            )
            conv = r.scalar_one_or_none()

        if not conv:
            return SkillResult(text="还没有对话记录，请先开始一段对话吧。")

        # 3. Get messages
        async with async_session() as s:
            r = await s.execute(
                select(Message)
                .where(Message.conv_id == conv.id)
                .order_by(Message.created_at)
                .limit(50)
            )
            msgs = r.scalars().all()

        if not msgs:
            return SkillResult(text="当前对话内容为空")

        # 4. Format dialogue for LLM
        lines = []
        for m in msgs:
            role = "用户" if m.role.value == "user" else "灵犀"
            lines.append(f"{role}: {m.content or ''}")
        dialogue = "\n".join(lines)

        # 5. Summarize
        try:
            summary = await llm_router.chat([
                {"role": "user", "content": SUMMARY_PROMPT.format(dialogue=dialogue)},
            ])
        except Exception:
            logger.exception("LLM summary failed")
            return SkillResult(text="摘要生成失败，请稍后再试")

        if not summary or not summary.strip():
            return SkillResult(text="摘要生成失败")

        # 6. Send email
        subject = f"对话摘要: {conv.title}"
        success = await send_email(user.email, subject, summary.strip())
        if not success:
            return SkillResult(
                text="邮件发送失败，请检查邮箱配置是否正确。你可以到设置里确认邮箱地址。"
            )

        return SkillResult(
            text=f"✅ 对话摘要已发送到 {user.email}，请查收邮件。"
        )


email_skill = EmailSkill()
