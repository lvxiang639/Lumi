"""Abstract repository interface for knowledge base persistence."""

from abc import ABC, abstractmethod
from uuid import UUID
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class KnowledgeBaseEntity:
    id: UUID | None = None
    user_id: UUID | None = None
    title: str = ""
    file_name: str = ""
    chunk_count: int = 0
    created_at: datetime | None = None


@dataclass
class KnowledgeChunkEntity:
    id: UUID | None = None
    kb_id: UUID | None = None
    content: str = ""
    chunk_index: int = 0
    embedding: list[float] = field(default_factory=list)


class KnowledgeRepository(ABC):
    """Abstract repository for knowledge base persistence."""

    @abstractmethod
    async def add(self, kb: KnowledgeBaseEntity) -> KnowledgeBaseEntity:
        ...

    @abstractmethod
    async def add_chunks(self, chunks: list[KnowledgeChunkEntity]) -> None:
        ...

    @abstractmethod
    async def list_by_user(self, user_id: UUID) -> list[KnowledgeBaseEntity]:
        ...

    @abstractmethod
    async def get_by_id(self, kb_id: UUID, user_id: UUID) -> KnowledgeBaseEntity | None:
        ...

    @abstractmethod
    async def delete(self, kb_id: UUID, user_id: UUID) -> bool:
        ...

    @abstractmethod
    async def search_chunks(self, kb_id: UUID, embedding: list[float], top_k: int = 3) -> list[KnowledgeChunkEntity]:
        ...
