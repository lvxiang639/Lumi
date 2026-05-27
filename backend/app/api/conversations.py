from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, delete as sql_delete
from app.database import get_db
from app.models import Conversation, Message, User
from app.api.deps import get_current_user
from app.schemas.conversation import ConversationItem, MessageItem, UpdateTitleRequest

router = APIRouter(prefix="/api/conversations", tags=["conversations"])


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
    await db.execute(
        sql_delete(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
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
