import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from app.database import get_db
from app.models import Conversation, Message, User
from app.api.deps import get_current_user
from app.schemas.conversation import ConversationItem, MessageItem, UpdateTitleRequest
from app.services.llm_service import llm_router
from app.services.email_service import send_email

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/conversations", tags=["conversations"])

SUMMARY_PROMPT = """请将以下对话提炼为一份简洁的摘要邮件。格式如下：

- 标题行：用一句话概括对话主题
- 关键要点：列点说明讨论的主要内容
- 待办事项：如果有的话
- 对话时间线：简短的时间顺序总结

对话内容：
{messages}

请直接输出邮件正文（纯文本），不要加额外的解释。"""


@router.get("")
async def list_conversations(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    offset = (page - 1) * page_size
    total_result = await db.execute(
        select(func.count(Conversation.id)).where(Conversation.user_id == current_user.id)
    )
    total = total_result.scalar()
    result = await db.execute(
        select(Conversation)
        .where(Conversation.user_id == current_user.id)
        .order_by(desc(Conversation.updated_at))
        .offset(offset).limit(page_size)
    )
    convs = result.scalars().all()
    return {
        "items": [
            ConversationItem(id=str(c.id), title=c.title,
                           created_at=c.created_at, updated_at=c.updated_at)
            for c in convs
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/{conv_id}/messages")
async def list_messages(
    conv_id: UUID,
    cursor: str = Query(None),
    limit: int = Query(20, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    conv_result = await db.execute(
        select(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
    if not conv_result.scalar_one_or_none():
        raise HTTPException(404, "Conversation not found")

    q = select(Message).where(Message.conv_id == conv_id).order_by(desc(Message.created_at))
    if cursor:
        q = q.where(Message.created_at < cursor)
    q = q.limit(limit)
    result = await db.execute(q)
    msgs = result.scalars().all()
    return {
        "items": [
            MessageItem(id=str(m.id), role=m.role.value, type=m.type.value,
                       content=m.content, audio_url=m.audio_url, created_at=m.created_at)
            for m in reversed(msgs)
        ],
        "next_cursor": str(msgs[-1].created_at) if len(msgs) == limit else None,
    }


@router.delete("/{conv_id}")
async def delete_conversation(
    conv_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation).where(
            Conversation.id == conv_id,
            Conversation.user_id == current_user.id,
        )
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(404, "Conversation not found")
    await db.delete(conv)
    await db.commit()
    return {"status": "deleted"}


@router.put("/{conv_id}/title")
async def update_title(
    conv_id: UUID,
    req: UpdateTitleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(404, "Conversation not found")
    conv.title = req.title
    await db.commit()
    return {"status": "ok"}


@router.post("/{conv_id}/email-summary")
async def email_summary(
    conv_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Summarize the conversation via LLM and send it to the user's email."""
    # 1. Check conversation belongs to user
    conv_result = await db.execute(
        select(Conversation).where(
            Conversation.id == conv_id,
            Conversation.user_id == current_user.id,
        )
    )
    conv = conv_result.scalar_one_or_none()
    if not conv:
        raise HTTPException(404, "Conversation not found")

    # 2. Check user has an email address
    if not current_user.email:
        raise HTTPException(400, "请先在个人资料中设置邮箱地址")

    # 3. Fetch messages
    msgs_result = await db.execute(
        select(Message)
        .where(Message.conv_id == conv_id)
        .order_by(Message.created_at)
    )
    messages = msgs_result.scalars().all()
    if not messages:
        raise HTTPException(400, "对话内容为空")

    # 4. Format messages for LLM
    lines = []
    for m in messages:
        role = "用户" if m.role.value == "user" else "AI"
        lines.append(f"{role}: {m.content or ''}")
    dialogue = "\n".join(lines)

    # 5. Summarize via LLM
    prompt = SUMMARY_PROMPT.format(messages=dialogue)
    try:
        summary = await llm_router.chat([
            {"role": "user", "content": prompt},
        ])
    except Exception:
        logger.exception("LLM summary failed")
        raise HTTPException(500, "摘要生成失败")

    if not summary.strip():
        raise HTTPException(500, "摘要为空")

    # 6. Send email
    subject = f"对话摘要: {conv.title}"
    success = await send_email(current_user.email, subject, summary.strip())
    if not success:
        raise HTTPException(500, "邮件发送失败，请检查邮箱配置")

    return {"status": "sent", "email": current_user.email}
