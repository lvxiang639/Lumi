"""BGE-M3 embedding service — model loaded once, cached in memory."""

import logging
import numpy as np

logger = logging.getLogger("embedder")

_model = None
_embedding_dim = 1024


def is_ready() -> bool:
    """Check if model is loaded without triggering a load."""
    return _model is not None


def _load_model():
    """Load BGE-M3 sentence-transformer model. Called once on first use."""
    global _model
    if _model is not None:
        return _model

    from sentence_transformers import SentenceTransformer

    logger.info("Loading BGE-M3 embedding model...")
    _model = SentenceTransformer("BAAI/bge-m3")
    logger.info("BGE-M3 model loaded (dim=%d)", _embedding_dim)
    return _model


def embed_single(text: str) -> list[float] | None:
    """Embed a single text, return 1024-dim float list."""
    try:
        model = _load_model()
        vec = model.encode([text], normalize_embeddings=True)[0]
        return vec.tolist()
    except Exception:
        logger.exception("embed_single failed")
        return None


def embed_batch(texts: list[str]) -> np.ndarray | None:
    """Embed multiple texts, return (N, 1024) float array."""
    try:
        model = _load_model()
        return model.encode(texts, normalize_embeddings=True)
    except Exception:
        logger.exception("embed_batch failed")
        return None


def search(
    query_vec: list[float],
    items: list[dict],  # each: {"id": uuid, "text": str, "embedding": list[float]}
    top_k: int = 3,
    min_score: float = 0.15,
) -> list[dict]:
    """Search top-k items by cosine similarity to query vector."""
    if not items or not query_vec:
        return []

    q = np.array(query_vec, dtype=np.float32)
    scores = []

    for item in items:
        emb = item.get("embedding")
        if emb is None or len(emb) == 0:
            continue
        v = np.array(emb, dtype=np.float32)
        sim = float(np.dot(q, v))
        scores.append((sim, item))

    scores.sort(key=lambda x: x[0], reverse=True)
    return [item for sim, item in scores[:top_k] if sim >= min_score]
