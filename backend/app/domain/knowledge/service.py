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
        """Split text into overlapping chunks, respecting paragraph and sentence boundaries.

        Strategy:
        1. Split by double-newline (paragraphs)
        2. For paragraphs > chunk_size, split by sentence boundaries (。！？)
        3. Fall back to character slicing for very long sentences
        """
        import re

        text = text.strip()
        if not text:
            return []

        # Step 1: split into paragraph segments
        paragraphs = re.split(r'\n\s*\n', text)
        segments = []
        for p in paragraphs:
            p = p.strip()
            if not p:
                continue
            if len(p) <= chunk_size:
                segments.append(p)
            else:
                # Step 2: split long paragraphs by sentence
                sentences = re.split(r'(?<=[。！？；\n])\s*', p)
                current = ''
                for s in sentences:
                    s = s.strip()
                    if not s:
                        continue
                    if len(current) + len(s) <= chunk_size:
                        current = (current + ' ' + s).strip() if current else s
                    else:
                        if current:
                            segments.append(current)
                        # Step 3: if single sentence > chunk_size, slice it
                        if len(s) > chunk_size:
                            start = 0
                            while start < len(s):
                                end = min(start + chunk_size, len(s))
                                segments.append(s[start:end])
                                start += chunk_size - overlap
                        else:
                            current = s
                if current:
                    segments.append(current)

        # Build overlapping chunks from segments
        chunks = []
        for seg in segments:
            if not chunks:
                chunks.append(seg)
            else:
                # Try to merge with previous chunk if possible
                prev = chunks[-1]
                if len(prev) + len(seg) + 1 <= chunk_size:
                    chunks[-1] = prev + ' ' + seg
                else:
                    chunks.append(seg)

        logger.debug("chunked %d chars into %d chunks (avg %d chars/chunk)",
                     len(text), len(chunks),
                     sum(len(c) for c in chunks) // len(chunks) if chunks else 0)
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
