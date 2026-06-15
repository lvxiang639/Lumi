"""SQLAlchemy implementation of MessageRepository."""

from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.conversation import Conversation
from app.models.message import Message
from app.models.conv_memory import ConvMemory
from app.domain.repositories.message_repo import (
    MessageRepository, MessageEntity, ConversationEntity,
)


class SqlMessageRepository(MessageRepository):
    """SQLAlchemy-backed repository for Conversation & Message aggregates."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_conversation(self, conv_id: UUID, user_id: UUID) -> ConversationEntity | None:
        r = await self.db.execute(
            select(Conversation).where(
                Conversation.id == conv_id,
                Conversation.user_id == user_id,
            )
        )
        row = r.scalar_one_or_none()
        return _to_conv_entity(row) if row else None

    async def get_recent_messages(self, conv_id: UUID, limit: int = 20) -> list[MessageEntity]:
        r = await self.db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at.desc())
            .limit(limit)
        )
        return [_to_msg_entity(row) for row in r.scalars().all()]

    async def get_all_messages(self, conv_id: UUID) -> list[MessageEntity]:
        r = await self.db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at)
        )
        return [_to_msg_entity(row) for row in r.scalars().all()]

    async def save_message(self, msg: MessageEntity) -> MessageEntity:
        record = Message(
            id=msg.id,
            conv_id=msg.conv_id,
            role=msg.role,
            type=msg.type,
            content=msg.content,
            audio_url=msg.audio_url,
        )
        self.db.add(record)
        await self.db.flush()
        return _to_msg_entity(record)

    async def get_conv_summary(self, conv_id: UUID) -> str:
        r = await self.db.execute(
            select(ConvMemory.summary_text)
            .where(ConvMemory.conv_id == conv_id)
            .order_by(ConvMemory.updated_at.desc())
            .limit(1)
        )
        row = r.scalar_one_or_none()
        return row or ""


def _to_msg_entity(row: Message) -> MessageEntity:
    return MessageEntity(
        id=row.id, conv_id=row.conv_id, role=row.role.value if hasattr(row.role, 'value') else str(row.role),
        type=row.type.value if hasattr(row.type, 'value') else str(row.type),
        content=row.content or "", audio_url=row.audio_url or "",
        created_at=row.created_at,
    )


def _to_conv_entity(row: Conversation) -> ConversationEntity:
    return ConversationEntity(
        id=row.id, user_id=row.user_id, title=row.title or "新对话",
        created_at=row.created_at, updated_at=row.updated_at,
    )
