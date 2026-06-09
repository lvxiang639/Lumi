"""SQLAlchemy implementation of KnowledgeRepository."""

from uuid import UUID
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.domain.knowledge.repository import KnowledgeRepository, KnowledgeBaseEntity, KnowledgeChunkEntity
from app.models.knowledge_base import KnowledgeBase, KnowledgeChunk
import math


class SqlKnowledgeRepository(KnowledgeRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def add(self, kb: KnowledgeBaseEntity) -> KnowledgeBaseEntity:
        record = KnowledgeBase(user_id=kb.user_id, title=kb.title, file_name=kb.file_name, chunk_count=kb.chunk_count)
        self.db.add(record)
        await self.db.flush()
        await self.db.refresh(record)
        return self._to_entity(record)

    async def add_chunks(self, chunks: list[KnowledgeChunkEntity]) -> None:
        for c in chunks:
            self.db.add(KnowledgeChunk(kb_id=c.kb_id, content=c.content, chunk_index=c.chunk_index, embedding=c.embedding))
        await self.db.flush()

    async def list_by_user(self, user_id: UUID) -> list[KnowledgeBaseEntity]:
        r = await self.db.execute(select(KnowledgeBase).where(KnowledgeBase.user_id == user_id).order_by(KnowledgeBase.created_at.desc()))
        return [self._to_entity(row) for row in r.scalars().all()]

    async def get_by_id(self, kb_id: UUID, user_id: UUID) -> KnowledgeBaseEntity | None:
        r = await self.db.execute(select(KnowledgeBase).where(KnowledgeBase.id == kb_id, KnowledgeBase.user_id == user_id))
        row = r.scalar_one_or_none()
        return self._to_entity(row) if row else None

    async def delete(self, kb_id: UUID, user_id: UUID) -> bool:
        r = await self.db.execute(delete(KnowledgeBase).where(KnowledgeBase.id == kb_id, KnowledgeBase.user_id == user_id))
        await self.db.commit()
        return r.rowcount > 0

    async def search_chunks(self, kb_id: UUID, embedding: list[float], top_k: int = 3) -> list[KnowledgeChunkEntity]:
        """Cosine similarity search over chunks."""
        r = await self.db.execute(
            select(KnowledgeChunk).where(KnowledgeChunk.kb_id == kb_id, KnowledgeChunk.embedding.isnot(None))
        )
        chunks = r.scalars().all()
        if not chunks:
            return []

        # Compute cosine similarity
        scored = []
        for c in chunks:
            sim = self._cosine_sim(embedding, c.embedding or [])
            scored.append((sim, c))
        scored.sort(key=lambda x: x[0], reverse=True)

        return [KnowledgeChunkEntity(id=c.id, kb_id=c.kb_id, content=c.content, chunk_index=c.chunk_index) for _, c in scored[:top_k]]

    @staticmethod
    def _cosine_sim(a: list[float], b: list[float]) -> float:
        if not a or not b or len(a) != len(b):
            return 0.0
        dot = sum(x * y for x, y in zip(a, b))
        norm_a = math.sqrt(sum(x * x for x in a))
        norm_b = math.sqrt(sum(x * x for x in b))
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return dot / (norm_a * norm_b)

    @staticmethod
    def _to_entity(row: KnowledgeBase) -> KnowledgeBaseEntity:
        return KnowledgeBaseEntity(id=row.id, user_id=row.user_id, title=row.title, file_name=row.file_name, chunk_count=row.chunk_count, created_at=row.created_at)
