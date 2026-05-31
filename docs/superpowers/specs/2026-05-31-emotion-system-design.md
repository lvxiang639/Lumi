# Emotion System Design

Date: 2026-05-31

## Overview

Give 灵犀 real-time emotional awareness. The character perceives user emotions from conversation, maintains an emotional state that decays over time, and reflects that emotion in both reply tone and character animation.

## Emotion Types (6)

| Emotion | Label | Visual | Tone |
|---|---|---|---|
| Joy | joy | Eyes squint, body sway, blush deepen | Cheerful, playful |
| Sadness | sad | Head down, slow movements, tear glint | Gentle, comforting |
| Anger | angry | Brows furrow, body tense, lips tight | Short, cold (never rude) |
| Calm | calm | Normal breathing + blink | Normal, natural |
| Surprise | surprised | Eyes wide, body lean back, mouth open | Excited, exclamatory |
| Worry | worried | Brows knit, body lean forward | Caring, questioning |

## Data Model

```sql
user_emotion_state:
  user_id: UUID PK → users
  current_emotion: VARCHAR(20) NOT NULL DEFAULT 'calm'
  intensity: FLOAT NOT NULL DEFAULT 0.0  -- 0.0–1.0
  last_updated: DATETIME
  last_reason: TEXT  -- what triggered this emotion
```

## Architecture

```
User sends message
    ↓
emotion_service.analyze(message, recent_context)
    ↓ LLM call
{emotion, intensity, reason}
    ↓
emotion_service.apply(user_id, emotion_data)
    ↓ persist + merge with existing state
    ↓
Orchestrator injects emotion into LLM system prompt
    ↓ LLM generates emotionally-toned response
    ↓
WebSocket sends emotion data to frontend
    ↓ character animation switches
```

## Services

### emotion_service.py

**analyze(message, context) → EmotionResult:**
Uses LLM with a dedicated prompt to classify emotion from the current message + last 4 exchanges for context.

EMOTION_PROMPT:
```
分析用户当前的情绪状态。根据对话内容判断，返回JSON:
{"emotion": "joy|sad|angry|calm|surprised|worried", "intensity": 0.0-1.0, "reason": "简短原因"}

最近对话:
{context}
```

**apply(user_id, emotion_data):**
1. Load current emotion state from DB
2. Apply decay since last update (0.1 per 30 minutes)
3. Blend new emotion with current (weighted by intensity)
4. If new intensity > current, override with new emotion
5. Save to DB

**get_emotion_prompt(user_id) → str:**
Returns the emotional tone instruction for LLM system prompt.

## Decay Model

- Every 30 minutes: intensity -= 0.1
- When intensity drops to 0, reset to "calm"
- Strong emotions (joy, angry) decay faster → 0.15/30min
- Weak emotions (calm, worried) decay slower → 0.05/30min
- New strong emotion always overrides decayed state

## LLM Integration

Inject into orchestrator before building chat messages:
```
当前情绪: {emotion_label}（强度 {intensity}）

请根据当前情绪调整回复风格:
- joy: 欢快活泼，多用感叹，可以俏皮
- sad: 温柔安慰，语气平稳
- angry: 简短冷淡，但不粗鲁
- calm: 正常交流
- surprised: 带感叹词，表达惊奇
- worried: 关切询问，语气温暖
```

## Frontend

### Character Animation

WebSocket message type `emotion_update`:
```json
{"type": "emotion_update", "emotion": "joy", "intensity": 0.8}
```

- macOS (PNG `CharacterView`): switch animation preset based on emotion
- iOS/Android (SVG `CharacterWebView`): JavaScript receives emotion, CSS class toggles on character element

### Optional: Emotion indicator
Tiny emoji/chip near character showing current emotion (can be toggled off).

## Testing

- Unit test emotion analysis with sample dialogues
- Unit test decay calculation
- Integration test: full flow from message → emotion → reply tone

## Implementation Order

1. `user_emotion_state` model + migration
2. `emotion_service.py` (analyze + apply + decay + get_prompt)
3. Orchestrator integration (inject emotion into LLM prompts)
4. WebSocket emotion_update message
5. Frontend emotion → animation mapping
