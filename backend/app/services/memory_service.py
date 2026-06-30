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


# ── Relevant Memory Query (keyword match) ─────────────────────────────

async def get_relevant_memories(user_id: UUID, user_text: str, top_k: int = 3) -> list[str]:
    """Get top-k relevant memories by keyword overlap."""
    async with async_session() as db:
        result = await db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(MAX_MEMORIES)
        )
        memories = result.scalars().all()

    if not memories:
        return []

    query_words = set(user_text)
    scored = []
    for m in memories:
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
    """Insert new memories, updating existing ones with the same key."""
    for key, value in items:
        result = await db.execute(
            select(UserMemory).where(UserMemory.user_id == user_id, UserMemory.key == key)
        )
        existing = result.scalar_one_or_none()
        if existing:
            existing.value = value
            existing.source_conv_id = conv_id
        else:
            db.add(UserMemory(user_id=user_id, key=key, value=value, source_conv_id=conv_id))
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
        for line in compressed.strip().split("\n"):
            line = line.strip()
            if not line or ":" not in line:
                continue
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if key and value and len(value) >= 2:
                r = await db.execute(
                    select(UserMemory).where(UserMemory.user_id == user_id, UserMemory.key == key)
                )
                e = r.scalar_one_or_none()
                if e:
                    e.value = value
                else:
                    db.add(UserMemory(user_id=user_id, key=key, value=value))

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
格式: "facts": [{{"key": "爱好", "value": "编程"}}]

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
