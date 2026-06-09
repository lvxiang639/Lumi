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
        """Get embedding vector for text using DeepSeek API."""
        try:
            from openai import AsyncOpenAI
            from app.config import settings

            client = AsyncOpenAI(api_key=settings.deepseek_api_key, base_url=settings.deepseek_base_url)
            resp = await client.embeddings.create(
                model="deepseek-chat",  # DeepSeek embeddings
                input=text[:2000],
            )
            return resp.data[0].embedding if resp.data else []
        except Exception:
            logger.exception("embedding failed for text len=%d", len(text))
            return []
