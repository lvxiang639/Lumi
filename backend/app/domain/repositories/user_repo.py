"""Abstract repository interface for User aggregate and related entities."""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID


@dataclass
class UserEntity:
    """Domain entity for a user."""
    id: UUID | None = None
    phone: str = ""
    email: str | None = None
    nickname: str = ""
    avatar_url: str = ""
    persona: str = "小猫"
    hashed_password: str | None = None
    last_briefing_date: datetime | None = None
    created_at: datetime | None = None


@dataclass
class MemoryEntity:
    """Domain entity for a user memory entry."""
    id: UUID | None = None
    user_id: UUID | None = None
    key: str = ""
    value: str = ""
    source_conv_id: UUID | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class EmotionEntity:
    """Domain entity for user emotional state."""
    id: UUID | None = None
    user_id: UUID | None = None
    current_emotion: str = ""     # 'happy' | 'sad' | 'angry' | 'worried' | 'neutral'
    intensity: float = 0.0
    updated_at: datetime | None = None


class UserRepository(ABC):
    """Abstract repository for User aggregate and related entities."""

    @abstractmethod
    async def get_by_id(self, user_id: UUID) -> UserEntity | None:
        ...

    @abstractmethod
    async def get_by_phone(self, phone: str) -> UserEntity | None:
        ...

    @abstractmethod
    async def get_by_email(self, email: str) -> UserEntity | None:
        ...

    @abstractmethod
    async def add(self, user: UserEntity) -> UserEntity:
        ...

    @abstractmethod
    async def get_memories(self, user_id: UUID, limit: int = 10) -> list[MemoryEntity]:
        ...

    @abstractmethod
    async def get_memory_count(self, user_id: UUID) -> int:
        ...

    @abstractmethod
    async def get_emotion(self, user_id: UUID) -> EmotionEntity | None:
        ...
