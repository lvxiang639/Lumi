"""Message repository — abstracts conversation & message DB queries."""

from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.conversation import Conversation
from app.models.message import Message, MessageRole, MessageType
from app.models.conv_memory import ConvMemory


class MessageRepository:
    """Repository for Conversation & Message aggregates."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_conversation(self, conv_id: UUID, user_id: UUID) -> Conversation | None:
        r = await self.db.execute(
            select(Conversation).where(
                Conversation.id == conv_id,
                Conversation.user_id == user_id,
            )
        )
        return r.scalar_one_or_none()

    async def get_recent_messages(self, conv_id: UUID, limit: int = 20) -> list[Message]:
        r = await self.db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at.desc())
            .limit(limit)
        )
        return list(r.scalars().all())

    async def get_all_messages(self, conv_id: UUID) -> list[Message]:
        r = await self.db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at)
        )
        return list(r.scalars().all())

    async def save_message(self, msg: Message) -> Message:
        self.db.add(msg)
        await self.db.flush()
        return msg

    async def get_conv_summary(self, conv_id: UUID) -> str:
        r = await self.db.execute(
            select(ConvMemory.summary_text)
            .where(ConvMemory.conv_id == conv_id)
            .order_by(ConvMemory.updated_at.desc())
            .limit(1)
        )
        row = r.scalar_one_or_none()
        return row or ""
