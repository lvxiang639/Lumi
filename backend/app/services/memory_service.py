import asyncio
import logging
from uuid import UUID

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session
from app.models import UserMemory
from app.services.llm_service import llm_router

logger = logging.getLogger("memory")

EXTRACT_PROMPT = """从以下对话中提取关于用户的关键信息。只提取明确表述的事实，不要推测。
每行一条，格式: key: value（用中文key）

可提取的信息类型:
- 姓名、年龄、性别
- 职业、工作地点
- 所在城市
- 兴趣爱好、喜欢/讨厌的事物
- 家庭成员、宠物
- 习惯、偏好
- 重要经历

如果对话中没有新的可提取信息，返回空。

对话内容:
{dialogue}

提取结果（没有就留空）:"""

MERGE_PROMPT = """合并以下关于同一个用户的记忆。合并规则：
1. 相同key的信息，保留较新的value
2. 相似的信息合并为一条
3. 删除互相矛盾的信息（保留较新的）
4. 输出格式不变: key: value（每行一条）

当前记忆:
{existing}

新记忆:
{new_items}

合并结果:"""

MAX_MEMORIES = 50
MEMORY_SUMMARY_PROMPT = """将以下用户信息压缩为简洁的要点列表，保持关键信息不丢失：

{memories}

压缩结果（每行一条 key: value）:"""


# ── Embedding helpers ──────────────────────────────────────────────────

async def _embed_memory_text(key: str, value: str) -> list[float] | None:
    """Compute embedding for a memory entry. Runs in executor to avoid blocking."""
    from app.services.memory_embedder import embed_single
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, embed_single, f"{key}: {value}")


async def compute_missing_embeddings() -> int:
    """Backfill embeddings for memories that don't have them yet.
    Also preloads BGE-M3 model so first chat is fast.
    Should be called once at startup."""
    from app.services.memory_embedder import embed_batch, _load_model
    import numpy as np

    # Preload model in background thread — ensures first chat doesn't wait
    loop = asyncio.get_running_loop()
    loop.run_in_executor(None, _load_model)
    logger.info("BGE-M3 preload scheduled")

    async with async_session() as db:
        result = await db.execute(
            select(UserMemory).where(UserMemory.embedding == None).limit(100)
        )
        memories = result.scalars().all()

    if not memories:
        return 0

    texts = [f"{m.key}: {m.value}" for m in memories]
    embeddings = await loop.run_in_executor(None, embed_batch, texts)

    if embeddings is None:
        return 0

    count = 0
    async with async_session() as db:
        for mem, emb in zip(memories, embeddings):
            result = await db.execute(
                select(UserMemory).where(UserMemory.id == mem.id)
            )
            m = result.scalar_one_or_none()
            if m is not None:
                m.embedding = emb.tolist()
                count += 1
        await db.commit()

    logger.info("Backfilled embeddings for %d memories", count)
    return count


# ── Relevant Memory Query (semantic search) ────────────────────────────

async def get_relevant_memories(user_id: UUID, user_text: str, top_k: int = 3) -> list[str]:
    """Get top-k semantically relevant memories using precomputed embeddings.
    Falls back to keyword matching if model isn't loaded yet."""
    from app.services.memory_embedder import embed_single, search, is_ready

    async with async_session() as db:
        result = await db.execute(
            select(UserMemory)
            .where(
                UserMemory.user_id == user_id,
                UserMemory.embedding != None,
            )
            .order_by(UserMemory.updated_at.desc())
            .limit(MAX_MEMORIES)
        )
        memories = result.scalars().all()

    if not memories:
        return []

    # Try semantic search if model is ready
    if is_ready():
        loop = asyncio.get_running_loop()
        query_vec = await loop.run_in_executor(None, embed_single, user_text)
        if query_vec is not None:
            items = [{"id": m.id, "text": f"{m.key}: {m.value}", "embedding": m.embedding} for m in memories]
            results = search(query_vec, items, top_k=top_k)
            if results:
                return [r["text"] for r in results]
    else:
        logger.debug("BGE-M3 not ready, using keyword fallback")

    # Fallback: keyword match
    query_words = set(user_text)
    scored = []
    result2 = await db.execute(
        select(UserMemory)
        .where(UserMemory.user_id == user_id)
        .order_by(UserMemory.updated_at.desc())
        .limit(MAX_MEMORIES)
    )
    all_memories = result2.scalars().all()
    for m in all_memories:
        text = f"{m.key}: {m.value}"
        score = sum(1 for w in query_words if w in text)
        if score > 0:
            scored.append((score, text))
    scored.sort(reverse=True)
    return [t for _, t in scored[:top_k]]


# ── Memory Extraction ──────────────────────────────────────────────────

async def extract_memories(user_id: UUID, conv_id: UUID, dialogue: str) -> None:
    """Async: extract facts from a conversation and save to memory store."""
    if not dialogue.strip():
        return

    # Extract via LLM
    try:
        raw = await llm_router.chat([
            {"role": "user", "content": EXTRACT_PROMPT.format(dialogue=dialogue)},
        ])
    except Exception:
        logger.exception("memory extraction LLM failed")
        return

    if not raw or not raw.strip():
        return

    new_items = []
    for line in raw.strip().split("\n"):
        line = line.strip()
        if not line or ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if key and value and len(value) >= 2:
            new_items.append((key, value))

    if not new_items:
        return

    async with async_session() as db:
        await _save_memories(db, user_id, conv_id, new_items)
        await _enforce_limit(db, user_id)


async def _save_memories(
    db: AsyncSession, user_id: UUID, conv_id: UUID, items: list[tuple[str, str]]
) -> None:
    """Insert new memories with precomputed embeddings, updating existing ones.
    Embeddings are batch-computed for efficiency (single BGE-M3 call for all new items)."""
    # First, check what exists and collect new items that need embedding
    to_embed: list[tuple[str, str, bool]] = []  # (key, value, is_update)
    for key, value in items:
        result = await db.execute(
            select(UserMemory).where(
                UserMemory.user_id == user_id,
                UserMemory.key == key,
            )
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.value = value
            existing.source_conv_id = conv_id
            to_embed.append((key, value, True))
        else:
            to_embed.append((key, value, False))

    # Batch embed all new/changed items
    embed_map: dict[str, list[float]] = {}
    if to_embed:
        from app.services.memory_embedder import embed_batch
        loop = asyncio.get_running_loop()
        texts = [f"{k}: {v}" for k, v, _ in to_embed]
        embeddings = await loop.run_in_executor(None, embed_batch, texts)
        if embeddings is not None:
            for (key, _, _), emb in zip(to_embed, embeddings):
                embed_map[key] = emb.tolist()

    # Apply embeddings
    for key, value, is_update in to_embed:
        emb = embed_map.get(key)
        if is_update:
            # Embedding already applied to existing record's field above
            result = await db.execute(
                select(UserMemory).where(
                    UserMemory.user_id == user_id,
                    UserMemory.key == key,
                )
            )
            existing = result.scalar_one_or_none()
            if existing and emb is not None:
                existing.embedding = emb
        else:
            db.add(UserMemory(
                user_id=user_id,
                key=key,
                value=value,
                source_conv_id=conv_id,
                embedding=emb,
            ))

    await db.commit()


async def _enforce_limit(db: AsyncSession, user_id: UUID) -> None:
    """Keep at most MAX_MEMORIES per user. Merge/summarize older ones."""
    result = await db.execute(
        select(func.count(UserMemory.id)).where(UserMemory.user_id == user_id)
    )
    count = result.scalar() or 0

    if count <= MAX_MEMORIES:
        return

    result = await db.execute(
        select(UserMemory)
        .where(UserMemory.user_id == user_id)
        .order_by(UserMemory.updated_at.desc())
        .limit(MAX_MEMORIES + 100)
    )
    all_memories = result.scalars().all()
    keep = all_memories[:MAX_MEMORIES]

    overflow = all_memories[MAX_MEMORIES:]
    if not overflow:
        return

    old_text = "\n".join(f"- {m.key}: {m.value}" for m in overflow)
    keep_text = "\n".join(f"- {m.key}: {m.value}" for m in keep)
    combined = f"新记忆:\n{old_text}\n\n现有记忆:\n{keep_text}"

    try:
        compressed = await llm_router.chat([
            {"role": "user", "content": MEMORY_SUMMARY_PROMPT.format(memories=combined)},
        ])
    except Exception:
        logger.exception("memory compression LLM failed")
        for m in overflow:
            await db.delete(m)
        await db.commit()
        return

    for m in overflow:
        await db.delete(m)
    await db.flush()

    if compressed and compressed.strip():
        # Collect new items that need embeddings
        new_items: list[tuple[str, str, bool]] = []  # (key, value, is_existing)
        for line in compressed.strip().split("\n"):
            line = line.strip()
            if not line or ":" not in line:
                continue
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if key and value and len(value) >= 2:
                r = await db.execute(
                    select(UserMemory).where(
                        UserMemory.user_id == user_id,
                        UserMemory.key == key,
                    )
                )
                e = r.scalar_one_or_none()
                if e:
                    e.value = value
                    new_items.append((key, value, True))
                else:
                    new_items.append((key, value, False))

        # Batch embed new items
        if new_items:
            from app.services.memory_embedder import embed_batch
            loop = asyncio.get_running_loop()
            new_only = [(k, v) for k, v, exists in new_items if not exists]
            if new_only:
                texts = [f"{k}: {v}" for k, v in new_only]
                embeddings = await loop.run_in_executor(None, embed_batch, texts)
                if embeddings is not None:
                    for (key, value, _), emb in zip(new_items, embeddings):
                        db.add(UserMemory(
                            user_id=user_id, key=key, value=value,
                            embedding=emb.tolist(),
                        ))

    await db.commit()


# ── ConvMemory (对话级记忆) ──

CONV_SUMMARY_PROMPT = """为以下对话生成简短的累积摘要（50字以内），概括用户和AI聊了些什么。如果已有之前的摘要，请合并新旧内容，避免信息丢失。

之前的摘要: {previous}

对话内容:
{dialogue}

累积摘要（50字以内）:"""


async def extract_conv_summary(user_id: UUID, conv_id: UUID, dialogue: str) -> None:
    """Async: extract a cumulative summary of this conversation and save to conv_memories."""
    if not dialogue.strip():
        return

    previous_summary = ""
    async with async_session() as db:
        from app.models import ConvMemory
        result = await db.execute(
            select(ConvMemory.summary_text)
            .where(ConvMemory.conv_id == conv_id)
            .order_by(ConvMemory.updated_at.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row:
            previous_summary = row

    try:
        summary = await llm_router.chat([
            {"role": "user", "content": CONV_SUMMARY_PROMPT.format(
                dialogue=dialogue,
                previous=previous_summary or "(无)",
            )},
        ])
    except Exception:
        logger.exception("conv memory extraction LLM failed")
        return

    if not summary or not summary.strip():
        return

    summary = summary.strip()[:200]

    async with async_session() as db:
        from app.models import ConvMemory
        result = await db.execute(
            select(ConvMemory).where(ConvMemory.conv_id == conv_id)
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.summary_text = summary
        else:
            db.add(ConvMemory(
                user_id=user_id,
                conv_id=conv_id,
                summary_text=summary,
            ))
        await db.commit()


async def get_conv_memory_summary(conv_id: UUID) -> str:
    """Get conversation-level memory summary for a given conversation."""
    async with async_session() as db:
        from app.models import ConvMemory
        result = await db.execute(
            select(ConvMemory.summary_text)
            .where(ConvMemory.conv_id == conv_id)
            .order_by(ConvMemory.updated_at.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
    return row or ""


async def get_memory_summary(user_id: UUID) -> str:
    """Get all memories for a user as a compact string for system prompt."""
    async with async_session() as db:
        result = await db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(MAX_MEMORIES)
        )
        memories = result.scalars().all()

    if not memories:
        return ""

    lines = [f"- {m.key}: {m.value}" for m in memories]
    return "\n".join(lines)


UNIFIED_EXTRACT_PROMPT = """分析以下对话，同时完成两个任务。返回JSON格式。

任务1 - 提取用户关键信息（只提取明确表述的事实）:
可提取类型: 姓名/年龄/职业/城市/兴趣爱好/家庭成员/宠物/习惯/偏好/重要经历
格式: "facts": [{"key": "爱好", "value": "编程"}]

任务2 - 对话摘要（50字以内，概括用户和AI聊了什么）:
格式: "summary": "..."

如果对话很短（<3轮）或没有新信息，对应字段返回空。
如果已有之前的摘要，新摘要应合并旧内容。

之前的摘要: {previous_summary}

对话内容:
{dialogue}

JSON:"""


def schedule_extraction(user_id: UUID, conv_id: UUID, dialogue: str) -> None:
    """Fire-and-forget: extract memories + conversation summary in one LLM call.
    Skips trivial conversations (< 3 messages or < 50 chars of dialogue)."""
    lines = [l for l in dialogue.strip().split("\n") if l.strip()]
    if len(lines) < 3 or len(dialogue) < 50:
        return

    async def _run():
        try:
            await _unified_extract(user_id, conv_id, dialogue)
        except Exception:
            logger.exception("unified extraction failed")

    asyncio.create_task(_run())


async def _unified_extract(user_id: UUID, conv_id: UUID, dialogue: str) -> None:
    """Single LLM call: extract user facts + conversation summary."""
    # Load previous summary for cumulative merge
    previous_summary = ""
    async with async_session() as db:
        from app.models import ConvMemory
        result = await db.execute(
            select(ConvMemory.summary_text)
            .where(ConvMemory.conv_id == conv_id)
            .order_by(ConvMemory.updated_at.desc())
            .limit(1)
        )
        row = result.scalar_one_or_none()
        if row:
            previous_summary = row

    prompt = UNIFIED_EXTRACT_PROMPT.format(
        dialogue=dialogue,
        previous_summary=previous_summary or "(无)",
    )
    raw = await llm_router.chat([{"role": "user", "content": prompt}])
    if not raw or not raw.strip():
        return

    # Parse JSON
    try:
        import json
        # Strip markdown wrappers
        clean = raw.strip()
        if clean.startswith("```"):
            clean = clean.split("\n", 1)[-1] if "\n" in clean else clean[3:]
            if clean.endswith("```"):
                clean = clean[:-3]
            clean = clean.strip()
        data = json.loads(clean)
    except Exception:
        return

    # Save facts
    facts = data.get("facts") or []
    if isinstance(facts, dict):
        facts = [{"key": k, "value": v} for k, v in facts.items()]
    if facts:
        items = [(f["key"], str(f["value"])) for f in facts if f.get("key") and f.get("value")]
        if items:
            async with async_session() as db:
                await _save_memories(db, user_id, conv_id, items)

    # Save summary
    summary = (data.get("summary") or "").strip()[:200]
    if summary:
        async with async_session() as db:
            from app.models import ConvMemory
            result = await db.execute(
                select(ConvMemory).where(ConvMemory.conv_id == conv_id)
            )
            existing = result.scalar_one_or_none()
            if existing:
                existing.summary_text = summary
            else:
                db.add(ConvMemory(
                    user_id=user_id,
                    conv_id=conv_id,
                    summary_text=summary,
                ))
            await db.commit()
