"""Abstract repository interface for Conversation & Message aggregates."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID


@dataclass
class MessageEntity:
    """Domain entity for a chat message."""
    id: UUID | None = None
    conv_id: UUID | None = None
    role: str = ""       # 'user' | 'assistant' | 'system'
    type: str = "text"
    content: str = ""
    audio_url: str = ""
    created_at: datetime | None = None


@dataclass
class ConversationEntity:
    """Domain entity for a conversation."""
    id: UUID | None = None
    user_id: UUID | None = None
    title: str = "新对话"
    created_at: datetime | None = None
    updated_at: datetime | None = None


class MessageRepository(ABC):
    """Abstract repository for Conversation & Message persistence."""

    @abstractmethod
    async def get_conversation(self, conv_id: UUID, user_id: UUID) -> ConversationEntity | None:
        ...

    @abstractmethod
    async def get_recent_messages(self, conv_id: UUID, limit: int = 20) -> list[MessageEntity]:
        ...

    @abstractmethod
    async def get_all_messages(self, conv_id: UUID) -> list[MessageEntity]:
        ...

    @abstractmethod
    async def save_message(self, msg: MessageEntity) -> MessageEntity:
        ...

    @abstractmethod
    async def get_conv_summary(self, conv_id: UUID) -> str:
        ...
