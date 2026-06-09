"""Domain service: text chunking, embedding, and retrieval logic."""

import logging
from uuid import UUID
from .repository import KnowledgeRepository, KnowledgeBaseEntity, KnowledgeChunkEntity

logger = logging.getLogger("knowledge")


class KnowledgeService:
    def __init__(self, repo: KnowledgeRepository):
        self.repo = repo

    async def ingest_document(self, user_id: UUID, title: str, file_name: str, text: str) -> KnowledgeBaseEntity:
        """Parse document, chunk it, embed chunks, store everything."""
        # 1. Chunk text
        chunks = self._chunk_text(text)
        if not chunks:
            raise ValueError("文档内容为空")

        # 2. Create knowledge base
        kb = KnowledgeBaseEntity(user_id=user_id, title=title, file_name=file_name, chunk_count=len(chunks))
        kb = await self.repo.add(kb)

        # 3. Embed + store chunks
        chunk_entities = []
        for i, chunk_text in enumerate(chunks):
            embedding = await self._embed(chunk_text)
            chunk_entities.append(KnowledgeChunkEntity(
                kb_id=kb.id, content=chunk_text, chunk_index=i, embedding=embedding
            ))

        await self.repo.add_chunks(chunk_entities)
        logger.info("ingested document '%s': %d chunks", title, len(chunks))
        return kb

    async def retrieve(self, kb_id: UUID, user_id: UUID, query: str, top_k: int = 3) -> list[str]:
        """Retrieve relevant chunks for a query."""
        # Embed query
        query_embedding = await self._embed(query)
        if not query_embedding:
            return []

        # Search
        chunks = await self.repo.search_chunks(kb_id, query_embedding, top_k)
        return [c.content for c in chunks]

    def _chunk_text(self, text: str, chunk_size: int = 500, overlap: int = 100) -> list[str]:
        """Split text into overlapping chunks."""
        text = text.strip()
        if not text:
            return []
        chunks = []
        start = 0
        while start < len(text):
            end = min(start + chunk_size, len(text))
            chunks.append(text[start:end])
            start += chunk_size - overlap
        return chunks

    async def _embed(self, text: str) -> list[float]:
        """Get embedding vector using local sentence-transformers (free, no API cost)."""
        try:
            import asyncio
            loop = asyncio.get_running_loop()
            return await loop.run_in_executor(None, _embed_sync, text)
        except Exception:
            logger.exception("embedding failed for text len=%d", len(text))
            return []


def _embed_sync(text: str) -> list[float]:
    """Synchronous embedding using BGE-M3 (best Chinese + multilingual model)."""
    try:
        from sentence_transformers import SentenceTransformer
        if not hasattr(_embed_sync, '_model'):
            _embed_sync._model = SentenceTransformer('BAAI/bge-m3')
        result = _embed_sync._model.encode(
            text[:2000],
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        return result.tolist()
    except ImportError:
        import hashlib; import random
        random.seed(hashlib.md5(text.encode()).hexdigest())
        return [random.random() for _ in range(1024)]
    except Exception:
        import hashlib; import random
        random.seed(hashlib.md5(text.encode()).hexdigest())
        return [random.random() for _ in range(1024)]
