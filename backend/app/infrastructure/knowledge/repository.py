"""SQLAlchemy + FAISS implementation of KnowledgeRepository."""

import logging
from uuid import UUID
import numpy as np
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.domain.knowledge.repository import KnowledgeRepository, KnowledgeBaseEntity, KnowledgeChunkEntity
from app.models.knowledge_base import KnowledgeBase, KnowledgeChunk

logger = logging.getLogger("knowledge_repo")

# In-memory FAISS index cache: kb_id → (faiss_index, chunk_list)
_index_cache: dict[UUID, tuple] = {}


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
        # Build FAISS index after adding chunks
        if chunks and chunks[0].kb_id:
            self._build_faiss_index(chunks[0].kb_id, chunks)

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
        _index_cache.pop(kb_id, None)  # Clear FAISS cache
        return r.rowcount > 0

    async def search_chunks(self, kb_id: UUID, embedding: list[float], top_k: int = 3) -> list[KnowledgeChunkEntity]:
        """FAISS vector similarity search."""
        import asyncio
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._search_sync, kb_id, embedding, top_k)

    def _search_sync(self, kb_id: UUID, embedding: list[float], top_k: int) -> list[KnowledgeChunkEntity]:
        try:
            import faiss
            cached = _index_cache.get(kb_id)
            if cached is None:
                # Lazy-load from DB
                chunks = _load_chunks_sync(kb_id)
                if not chunks:
                    return []
                self._build_faiss_index(kb_id, chunks)
                cached = _index_cache.get(kb_id)
                if cached is None:
                    return []

            index, chunk_list = cached
            query = np.array([embedding], dtype=np.float32)
            distances, indices = index.search(query, min(top_k, len(chunk_list)))

            results = []
            for i, dist in zip(indices[0], distances[0]):
                if i >= 0 and i < len(chunk_list):
                    results.append(chunk_list[i])
            return results
        except ImportError:
            logger.warning("FAISS not installed, using fallback cosine search")
            return _fallback_search(kb_id, embedding, top_k)

    def _build_faiss_index(self, kb_id: UUID, chunks: list[KnowledgeChunkEntity]):
        try:
            import faiss
            import numpy as np
            vectors = np.array([c.embedding for c in chunks if c.embedding], dtype=np.float32)
            if len(vectors) == 0:
                return
            dim = vectors.shape[1]
            index = faiss.IndexFlatIP(dim)  # Inner product = cosine for normalized vectors
            index.add(vectors)
            _index_cache[kb_id] = (index, chunks)
            logger.info("FAISS index built for kb %s: %d vectors, dim=%d", kb_id, len(vectors), dim)
        except ImportError:
            pass

    @staticmethod
    def _to_entity(row: KnowledgeBase) -> KnowledgeBaseEntity:
        return KnowledgeBaseEntity(id=row.id, user_id=row.user_id, title=row.title, file_name=row.file_name, chunk_count=row.chunk_count, created_at=row.created_at)


def _load_chunks_sync(kb_id: UUID) -> list[KnowledgeChunkEntity]:
    """Load chunks from DB synchronously (for FAISS build)."""
    import asyncio
    try:
        async def _load():
            from app.database import async_session
            async with async_session() as db:
                r = await db.execute(select(KnowledgeChunk).where(KnowledgeChunk.kb_id == kb_id, KnowledgeChunk.embedding.isnot(None)).order_by(KnowledgeChunk.chunk_index))
                rows = r.scalars().all()
                return [KnowledgeChunkEntity(id=row.id, kb_id=row.kb_id, content=row.content, chunk_index=row.chunk_index, embedding=row.embedding or []) for row in rows]

        loop = asyncio.get_event_loop()
        if loop.is_running():
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, _load())
                return future.result(timeout=30)
        else:
            return asyncio.run(_load())
    except Exception as e:
        logger.error("failed to load chunks for kb %s: %s", kb_id, e)
        return []


def _fallback_search(kb_id: UUID, embedding: list[float], top_k: int) -> list[KnowledgeChunkEntity]:
    """Pure Python cosine similarity fallback when FAISS unavailable."""
    import math
    chunks = _load_chunks_sync(kb_id)
    if not chunks:
        return []
    scored = [(sum(x * y for x, y in zip(embedding, c.embedding or [])), c) for c in chunks if c.embedding]
    scored.sort(key=lambda x: x[0], reverse=True)
    return [c for _, c in scored[:top_k]]
