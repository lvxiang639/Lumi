import json
import logging
import re
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select

from app.database import async_session
from app.models.emotion_state import UserEmotionState
from app.services.llm_service import llm_router

logger = logging.getLogger("emotion")

VALID_EMOTIONS = frozenset({"joy", "sad", "angry", "calm", "surprised", "worried"})

EMOTION_PROMPT = """分析用户当前的情绪状态。根据对话内容判断，返回JSON。

情绪选项: joy(开心), sad(难过), angry(生气), calm(平静), surprised(惊讶), worried(担心)

返回格式: {{"emotion": "joy", "intensity": 0.8, "reason": "简短原因"}}

用户消息: {message}

{context}

JSON:"""

TONE_MAP = {
    "joy":       "欢快活泼，多用感叹词，可以俏皮一点",
    "sad":       "温柔安慰，语气平稳轻声",
    "angry":     "简短冷淡，不啰嗦，但不要粗鲁无礼",
    "calm":      "正常语调，自然交流",
    "surprised": "带感叹词，表达惊奇和兴奋",
    "worried":   "关切询问，语气温暖体贴",
}

# Decay: intensity -= rate per 30 minutes
DECAY_RATES = {
    "joy": 0.15, "sad": 0.12, "angry": 0.18,
    "calm": 0.05, "surprised": 0.20, "worried": 0.10,
}


async def analyze(message: str, context: str = "") -> dict:
    """Analyze user message for emotional content. Returns {emotion, intensity, reason}."""
    prompt = EMOTION_PROMPT.format(message=message, context=context)
    try:
        raw = await llm_router.chat([{"role": "user", "content": prompt}])
    except Exception:
        logger.exception("emotion analysis LLM failed")
        return {"emotion": "calm", "intensity": 0.0, "reason": ""}

    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        m = re.search(r'\{[^}]+\}', raw)
        if m:
            try:
                data = json.loads(m.group())
            except json.JSONDecodeError:
                return {"emotion": "calm", "intensity": 0.0, "reason": ""}
        else:
            return {"emotion": "calm", "intensity": 0.0, "reason": ""}

    emotion = data.get("emotion", "calm")
    if emotion not in VALID_EMOTIONS:
        emotion = "calm"
    intensity = min(1.0, max(0.0, float(data.get("intensity", 0.0))))
    reason = str(data.get("reason", ""))[:200]
    return {"emotion": emotion, "intensity": intensity, "reason": reason}


async def apply(user_id: UUID, emotion_data: dict) -> dict:
    """Apply new emotion to user state with decay blending. Returns final state."""
    emotion = emotion_data["emotion"]
    new_intensity = emotion_data["intensity"]
    reason = emotion_data.get("reason", "")

    async with async_session() as db:
        result = await db.execute(
            select(UserEmotionState).where(UserEmotionState.user_id == user_id)
        )
        state = result.scalar_one_or_none()

        now = datetime.now(timezone.utc)

        if state is None:
            state = UserEmotionState(
                user_id=user_id,
                current_emotion=emotion,
                intensity=new_intensity,
                last_updated=now,
                last_reason=reason,
            )
            db.add(state)
            await db.commit()
            return {"emotion": emotion, "intensity": new_intensity}

        # Apply decay since last update
        elapsed = (now - state.last_updated).total_seconds()
        half_hours = elapsed / 1800.0
        decay_rate = DECAY_RATES.get(state.current_emotion, 0.1)
        decayed_intensity = max(0.0, state.intensity - half_hours * decay_rate)

        if decayed_intensity <= 0:
            final_emotion = emotion
            final_intensity = new_intensity
        elif new_intensity >= decayed_intensity:
            final_emotion = emotion
            final_intensity = min(1.0, new_intensity + decayed_intensity * 0.3)
        else:
            final_emotion = state.current_emotion
            final_intensity = min(1.0, decayed_intensity + new_intensity * 0.2)

        state.current_emotion = final_emotion
        state.intensity = final_intensity
        state.last_updated = now
        if reason:
            state.last_reason = reason
        await db.commit()

        return {"emotion": final_emotion, "intensity": final_intensity}


async def get_emotion_state(user_id: UUID) -> str:
    """Get brief emotion state label for system prompt (no LLM call)."""
    async with async_session() as db:
        result = await db.execute(
            select(UserEmotionState).where(UserEmotionState.user_id == user_id)
        )
        state = result.scalar_one_or_none()

    if not state or state.intensity <= 0.2:
        return ""

    emoji_map = {
        "joy": "😊 开心", "sad": "😢 有点难过", "angry": "😠 生气中",
        "calm": "😌 平静", "surprised": "😲 惊讶", "worried": "😟 担忧",
    }
    return emoji_map.get(state.current_emotion, "")


async def get_emotion_prompt(user_id: UUID) -> str:
    """Get emotion tone instruction for LLM system prompt."""
    async with async_session() as db:
        result = await db.execute(
            select(UserEmotionState).where(UserEmotionState.user_id == user_id)
        )
        state = result.scalar_one_or_none()

    if not state or state.intensity <= 0.1:
        return ""

    tone = TONE_MAP.get(state.current_emotion, "正常交流")
    emoji_map = {
        "joy": "😊", "sad": "😢", "angry": "😠",
        "calm": "😌", "surprised": "😲", "worried": "😟",
    }
    emoji = emoji_map.get(state.current_emotion, "")

    return (
        f"当前情绪: {state.current_emotion} {emoji}"
        f"（强度 {state.intensity:.1f}）\n"
        f"请根据当前情绪调整回复风格: {tone}"
    )
