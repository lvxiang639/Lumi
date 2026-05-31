# Emotion System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give 灵犀 6 real-time emotions (joy/sad/angry/calm/surprised/worried) with intensity decay, LLM tone injection, and character animation sync.

**Architecture:** `emotion_service.py` analyzes user messages via LLM, persists state to `user_emotion_state` table with time-based decay, injects emotion tone into orchestrator's LLM prompt, and pushes `emotion_update` via WebSocket to frontend for animation switching.

**Tech Stack:** Python/FastAPI/SQLAlchemy (backend), Flutter (frontend), existing LLM router, existing WebSocket infrastructure

---

## File Structure

| File | Purpose |
|------|---------|
| `backend/app/models/emotion_state.py` | NEW — `UserEmotionState` ORM model |
| `backend/app/services/emotion_service.py` | NEW — analyze, apply, decay, get_prompt |
| `backend/app/services/chat_orchestrator.py` | MODIFY — inject emotion into system prompt, push emotion_update |
| `backend/app/models/__init__.py` | MODIFY — register new model |
| `backend/alembic/versions/...` | NEW — migration |
| `frontend/lib/widgets/character_view.dart` | MODIFY — emotion → animation mapping (macOS PNG) |
| `frontend/assets/character/character.html` | MODIFY — emotion CSS classes (iOS/Android SVG) |
| `frontend/lib/providers/chat_provider.dart` | MODIFY — handle emotion_update message |

---

### Task 1: UserEmotionState Model + Migration

**Files:**
- Create: `backend/app/models/emotion_state.py`
- Modify: `backend/app/models/__init__.py`
- Create: migration (auto-generated)

- [ ] **Step 1: Write the model**

```python
# backend/app/models/emotion_state.py
import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Float, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserEmotionState(Base):
    __tablename__ = "user_emotion_states"

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), primary_key=True
    )
    current_emotion: Mapped[str] = mapped_column(
        String(20), nullable=False, default="calm"
    )
    intensity: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    last_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
```

- [ ] **Step 2: Register in models/__init__.py**

```python
# add import
from app.models.emotion_state import UserEmotionState

# add to __all__
"UserEmotionState",
```

- [ ] **Step 3: Generate migration**

```bash
cd backend && python3 -m alembic revision --autogenerate -m "add_user_emotion_states"
```

Expected: migration file created in `alembic/versions/`

- [ ] **Step 4: Apply migration**

```bash
cd backend && python3 -m alembic upgrade head
```

Expected: table created successfully

- [ ] **Step 5: Run tests to verify no regressions**

```bash
cd backend && python3 -m pytest tests/ -q --tb=short
```

Expected: 22 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/models/emotion_state.py backend/app/models/__init__.py backend/alembic/versions/*.py
git commit -m "feat: add UserEmotionState model for emotion system"
```

---

### Task 2: Emotion Service (analyze + apply + decay)

**Files:**
- Create: `backend/app/services/emotion_service.py`

- [ ] **Step 1: Create emotion_service.py**

```python
# backend/app/services/emotion_service.py
import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

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

    import json
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        # Try to extract JSON from raw text
        import re
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
            # Fully decayed, accept new emotion
            final_emotion = emotion
            final_intensity = new_intensity
        elif new_intensity >= decayed_intensity:
            # New emotion is stronger, override
            final_emotion = emotion
            final_intensity = min(1.0, new_intensity + decayed_intensity * 0.3)
        else:
            # Current (decayed) emotion is still stronger, keep it
            final_emotion = state.current_emotion
            final_intensity = min(1.0, decayed_intensity + new_intensity * 0.2)

        state.current_emotion = final_emotion
        state.intensity = final_intensity
        state.last_updated = now
        if reason:
            state.last_reason = reason
        await db.commit()

        return {"emotion": final_emotion, "intensity": final_intensity}


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

    return f"当前情绪: {state.current_emotion} {emoji}（强度 {state.intensity:.1f}）\n请根据当前情绪调整回复风格: {tone}"
```

- [ ] **Step 2: Run backend tests to verify no import issues**

```bash
cd backend && python3 -m pytest tests/ -q --tb=short
```

Expected: 22 passed

- [ ] **Step 3: Commit**

```bash
git add backend/app/services/emotion_service.py
git commit -m "feat: emotion service — analyze, apply, decay, tone prompt"
```

---

### Task 3: Orchestrator Integration

**Files:**
- Modify: `backend/app/services/chat_orchestrator.py`

- [ ] **Step 1: Add emotion analysis call**

After building `llm_messages` (chat path, after line ~90), add emotion injection:

```python
# Before building llm_messages, inject emotion tone
from app.services.emotion_service import analyze as analyze_emotion, get_emotion_prompt, apply as apply_emotion
emotion_data = await analyze_emotion(text)
emotion_state = await apply_emotion(user_uuid, emotion_data)
emotion_tone = await get_emotion_prompt(user_uuid)
```

In the system prompt building (line ~88-93 where `system_prefix` is defined), append `emotion_tone`:

```python
system_prefix = "你是一个贴心的AI助手，名叫灵犀。"
# ... existing memory injection ...
if emotion_tone:
    system_prefix += f"\n\n{emotion_tone}"
```

- [ ] **Step 2: Send emotion_update via WebSocket**

After `done` is sent (~line 122), push emotion state to frontend:

```python
await send_message({
    "type": "emotion_update",
    "emotion": emotion_state["emotion"],
    "intensity": emotion_state["intensity"],
})
```

The `send_message` closure already exists in both `process_text` and `process_voice`. In `process_text`, `send_message` is passed as a parameter.

- [ ] **Step 3: Also handle emotion in skill path**

For skill executions (when intent is not "chat"), also analyze emotion:

```python
# After line 39 (skill result), add:
emotion_data = await analyze_emotion(text)
emotion_state = await apply_emotion(user_uuid, emotion_data)
await send_message({
    "type": "emotion_update",
    "emotion": emotion_state["emotion"],
    "intensity": emotion_state["intensity"],
})
```

- [ ] **Step 4: Run tests**

```bash
cd backend && python3 -m pytest tests/ -q --tb=short
```

Expected: 22 passed

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/chat_orchestrator.py
git commit -m "feat: integrate emotion analysis into orchestrator"
```

---

### Task 4: Frontend — macOS PNG Emotion Animation

**Files:**
- Modify: `frontend/lib/widgets/character_view.dart`

- [ ] **Step 1: Add emotion state to CharacterView**

Add emotion tracking:

```dart
class CharacterView extends StatefulWidget {
  final double mouthOpen;
  final String animState;
  final String emotion;  // NEW
  final double emotionIntensity;  // NEW

  const CharacterView({
    super.key,
    this.mouthOpen = 0.0,
    this.animState = 'idle',
    this.emotion = 'calm',
    this.emotionIntensity = 0.0,
  });
  // ...
}
```

- [ ] **Step 2: Add emotion-driven animation tweaks in build**

In the build method, add emotion-based modifications after computing transforms:

```dart
// Emotion-driven modifications
final emotionBounce = widget.emotion == 'joy' ? _bounceEnergy * 1.5 : _bounceEnergy;
final emotionScale = switch (widget.emotion) {
  'surprised' => 1.0 + widget.emotionIntensity * 0.05,
  'sad' => 1.0 - widget.emotionIntensity * 0.02,
  _ => 1.0,
};
```

- [ ] **Step 3: Run flutter analyze**

```bash
cd frontend && flutter analyze
```

Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/widgets/character_view.dart
git commit -m "feat: emotion-driven character animation (macOS)"
```

---

### Task 5: Frontend — WebSocket Emotion Handler

**Files:**
- Modify: `frontend/lib/providers/chat_provider.dart`
- Modify: `frontend/lib/screens/chat_screen.dart`

- [ ] **Step 1: Add emotion state to ChatProvider**

```dart
// In ChatProvider class:
String _emotion = 'calm';
double _emotionIntensity = 0.0;

String get emotion => _emotion;
double get emotionIntensity => _emotionIntensity;
```

- [ ] **Step 2: Handle emotion_update in _onWsMessage**

Add a case in the switch:

```dart
case 'emotion_update':
  _emotion = msg.data['emotion'] as String? ?? 'calm';
  _emotionIntensity = (msg.data['intensity'] as num?)?.toDouble() ?? 0.0;
  break;
```

- [ ] **Step 3: Pass emotion to CharacterView in chat_screen.dart**

In the `CharacterView` widget call:

```dart
CharacterView(
  mouthOpen: chat.mouthOpen,
  animState: chat.animState.name,
  emotion: chat.emotion,
  emotionIntensity: chat.emotionIntensity,
),
```

- [ ] **Step 4: Run flutter analyze**

```bash
cd frontend && flutter analyze
```

Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/providers/chat_provider.dart frontend/lib/screens/chat_screen.dart
git commit -m "feat: handle emotion_update in WebSocket and pass to character"
```

---

### Task 6: Frontend — SVG Character Emotion (iOS/Android)

**Files:**
- Modify: `frontend/assets/character/character.html`
- Modify: `frontend/lib/widgets/character_html.dart` (regenerate)

- [ ] **Step 1: Add emotion CSS classes to character.html**

In `<style>`, add:

```css
.char-joy    .mouth-group { transform: scaleY(1.2); }
.char-joy    .eyes-group { transform: scaleY(0.9); }
.char-sad    .character  { animation-duration: 4.5s; }
.char-sad    .eyes-group { transform: translateY(3px); }
.char-angry  .eyebrows, .eyebrow-r  { transform: translateY(-3px); }
.char-surprised .eyes-group { transform: scale(1.15); }
.char-worried .eyes-group { transform: translateY(-2px); }
```

- [ ] **Step 2: Add JS handler for emotion**

```javascript
window.setEmotion = function(emotion, intensity) {
  document.querySelectorAll('.char-joy,.char-sad,.char-angry,.char-surprised,.char-worried'
    .split(',').forEach(function(c) { document.body.classList.remove(c); }));
  document.body.classList.add('char-' + emotion);
};
```

- [ ] **Step 3: Update CharacterWebView to call setEmotion**

In `character_webview.dart`, add `_syncEmotion()`:

```dart
void _syncEmotion() {
  if (!_ready || _controller == null || _usePng) return;
  _controller!.runJavaScript(
    "if(window.setEmotion)window.setEmotion('${widget.emotion}',${widget.emotionIntensity})");
}
```

Call it after `_syncToJs()` in `didUpdateWidget`.

- [ ] **Step 4: Regenerate character_html.dart**

```bash
cd frontend && python3 -c "
with open('assets/character/character.html','r') as f:
    c=f.read()
c=c.replace('\\\\','\\\\\\\\').replace('\$','\\\\\$')
with open('lib/widgets/character_html.dart','w') as f:
    f.write(f'const String kCharacterHtml = r\\'\\'\\'\\n{c}\\n\\'\\'\\'\\;\\n')
"
```

- [ ] **Step 5: Run flutter analyze**

```bash
cd frontend && flutter analyze
```

Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add frontend/assets/character/character.html frontend/lib/widgets/character_html.dart frontend/lib/widgets/character_webview.dart
git commit -m "feat: emotion CSS classes for SVG character"
```

---

### Task 7: End-to-End Test + Final Verify

- [ ] **Step 1: Run all backend tests**

```bash
cd backend && python3 -m pytest tests/ -q --tb=short
```

Expected: 22 passed

- [ ] **Step 2: Run flutter analyze**

```bash
cd frontend && flutter analyze
```

Expected: No issues found

- [ ] **Step 3: Run migration**

```bash
cd backend && alembic upgrade head
```

- [ ] **Step 4: Manual smoke test**
  - Start backend + frontend
  - Send "今天好开心！升职了！"
  - Verify character reaction changes
  - Send "我很难过，猫丢了"
  - Verify character switches to sad

- [ ] **Step 5: Commit if any fixes needed, otherwise push**

```bash
git push
```
