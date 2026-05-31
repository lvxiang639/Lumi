# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Backend
cd backend
pip install -r requirements.txt                    # Install deps
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload  # Start dev server
python -m pytest tests/ -v                         # Run all tests (22)
python -m pytest tests/test_auth.py::test_login_new_user -v  # Run single test
alembic revision --autogenerate -m "description"    # Generate migration
alembic upgrade head                               # Apply migrations

# Frontend
cd frontend
flutter pub get                                    # Install deps
flutter analyze                                    # Static analysis
flutter test                                       # Run tests
flutter run -d macos                               # macOS
flutter run -d "iPhone 17 Pro"                     # iOS Simulator
xcrun simctl boot "iPhone 17 Pro" && open -a Simulator  # Boot iOS sim first

# Regenerate embedded character HTML (after editing character_3d.html)
python3 -c "
with open('frontend/assets/character/character_3d.html','r') as f:
    c=f.read()
c=c.replace('\\\\','\\\\\\\\').replace('\$','\\\\\$')
with open('frontend/lib/widgets/character_html.dart','w') as f:
    f.write(f'const String kCharacterHtml = r\\'\\'\\'\\n{c}\\n\\'\\'\\'\\;\\n')
"
```

**Database:** Tests use `sqlite+aiosqlite://` (in-memory). Production uses PostgreSQL via `DATABASE_URL` env var. The `conftest.py` overrides `get_db` dependency and seeds default Outfit/VoicePack records.

## Architecture

### Backend (FastAPI)

Three-layer structure with a plugin-based skill system for conversation routing:

```
api/     → Route handlers, thin — delegates to services, uses deps.py for auth
models/  → SQLAlchemy ORM (async, Uuid PKs, declarative Base in database.py)
schemas/ → Pydantic request/response models
services/→ Business logic: AI wrappers, skill plugins, chat orchestrator
core/    → JWT security (python-jose + passlib)
```

**Key architectural decisions:**

- **Config is centralized** in `config.py` using `pydantic-settings` with `.env` support. All env vars are read through `settings.X` — never inline.
- **All database access is async** (`AsyncSession`, `async_sessionmaker`, `get_db` dependency). Uuid PKs use `sqlalchemy.Uuid`.
- **Auth is phone-based login** (no passwords). `POST /api/auth/login` returns a JWT; new users auto-register.

### Skill Plugin System

The conversation pipeline is intent-driven:

1. `chat_orchestrator.py` receives a user message
2. `llm_service.py:classify_intent()` calls DeepSeek to classify into `chat|search|weather|calendar|expense|convert|briefing`
3. If skill matched → dispatch to `SkillRegistry` → skill returns `SkillResult(text, data)`
4. If `chat` → inject memory + emotion into system prompt → stream LLM response (last 20 messages)
5. Save assistant message → synthesize TTS → send `done`
6. Fire-and-forget: memory extraction + emotion analysis after response

**Registered skills:** weather, calendar, expense, search, convert, briefing

**Adding a new skill:** Implement `BaseSkill` (abstract `name` + `execute()`), register in `skill_registry.py`, add intent label in `llm_service.classify_intent()`.

### LLM Routing

`llm_service.py` creates two `AsyncOpenAI` clients (DeepSeek and Qwen). Default model is DeepSeek (`deepseek-chat`). Errors are raised so callers can handle them.

### Models (data)

13 tables. Key additions since initial version:

| Model | Table | Purpose |
|-------|-------|---------|
| `UserMemory` | `user_memories` | key-value facts extracted from conversations |
| `UserEmotionState` | `user_emotion_states` | current emotion + intensity with time decay |
| `ConvertedFile` | `converted_files` | track user's converted files (MinIO object name) |
| `User.email` | `users.email` | nullable String(200) — for email summary |
| `User.last_briefing_date` | `users.last_briefing_date` | dedup daily briefing push |

### Services

| Service | Purpose |
|---------|---------|
| `email_service.py` | Async SMTP via `asyncio.to_thread` + `smtplib`. STARTTLS on port 587. |
| `conversion_service.py` | DOCX ↔ PDF. `pdf2docx` / `python-docx` + `fpdf2` with CJK font. |
| `notification_service.py` | Polls `calendar_events`. Calendar-month recurring reschedule. |
| `emotion_service.py` | LLM emotion analysis, decay blending, tone prompt generation. |
| `memory_service.py` | Async LLM extraction → `user_memories`, injection into system prompt. |
| `briefing_service.py` | Morning briefing: weather + calendar + expenses → LLM format. |
| `location_service.py` | Multi-layer IP geolocation (header → server IP → memory → Beijing). |
| `minio_service.py` | Upload/download/presigned URLs for MinIO object storage. |

### API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/conversations/{id}/email-summary` | LLM summary → email |
| `POST` | `/api/tools/convert?target=pdf\|docx` | File upload → convert → MinIO → JSON |
| `GET`  | `/api/tools/files` | List user's converted files + presigned URLs |
| `GET`  | `/api/tools/files/{id}/download` | Stream download from MinIO |
| `PUT`  | `/api/auth/profile` | Now accepts `email` field |

### Emotion System

6 emotions with intensity decay:

```
User message → LLM analysis → {emotion, intensity, reason}
  → decay blending (0.05-0.20 per 30 min) → persist to user_emotion_states
  → tone injected into LLM system prompt
  → emotion_update pushed via WebSocket to frontend
  → 3D character BlendShape / CSS animation switched
```

Emotions: `joy` 😊 `sad` 😢 `angry` 😠 `calm` 😌 `surprised` 😲 `worried` 😟

### Long-term Memory

```
Conversation ends → async LLM extraction → user_memories (key-value facts)
New conversation → load memories → inject into system prompt
> 50 memories → LLM merges/compresses older ones
Location: user_memories key="city" → used by weather/briefing as fallback
```

### Daily Briefing

- **Auto:** 8 AM Beijing time → push to online users via WebSocket (dedup via `last_briefing_date`)
- **Manual:** say "早上好" / "今日简报" → triggers `briefing` skill
- **Content:** LLM greeting + today's calendar + yesterday's expenses + real weather (IP-detected city)

### Location Detection

4-layer fallback: ① HTTP header (X-Forwarded-For) → ② Server IP → ip-api.com → ③ UserMemory key="city" → ④ "Beijing"

### Frontend (Flutter)

**State management:** Provider pattern with `ChangeNotifier` providers in `app.dart:MultiProvider`. Auth state drives LoginScreen vs HomeScreen routing.

**WebSocket message types handled by `chat_provider.dart`:**
`asr_result`, `llm_stream`, `skill_call`, `tts_audio`, `tts_audio_chunk`, `tts_audio_end`, `emotion_update`, `done`

### UI Layout

```
┌──────────────────────────────────┐
│  🟢 灵犀   📧  🔧  👤          │ ← AppBar
│                                  │
│  Sci-fi animated background      │ ← sci_fi_bg.dart
│                                  │
│       ┌──────────────┐           │
│       │  3D Character │           │ ← character_webview.dart
│       │  (Three.js +  │           │   WebView with VRM model
│       │   VRM model)  │           │   on all platforms
│       └──────────────┘           │
│  ┌──────────────────┐            │
│  │ 灵犀: 你好        │            │ ← Glass chat panel
│  │ 你: 帮我查天气    │            │   Left-aligned, prefixed
│  └──────────────────┘            │
│        [💬] [📎] (🎤)            │ ← Floating input cluster
└──────────────────────────────────┘
```

### 3D Character System

Three.js + VRM model rendered in WebView, bundled locally (no network dependency):

| File | Purpose |
|------|---------|
| `assets/character/character_3d.html` | Three.js scene, VRM loader, animation, JS bridge |
| `assets/character/model.vrm` | Rose CC0 VRM model (2.4MB, bundled at build) |
| `widgets/character_html.dart` | Auto-generated — HTML embedded as `kCharacterHtml` constant |
| `widgets/character_webview.dart` | WebView wrapper, injects VRM bytes as base64 after page load |

**JS bridge (Flutter → Three.js):**
- `window.loadModelBase64(b64)` — inject VRM model
- `window.updateMouth(v)` — TTS mouth sync
- `window.setEmotion(e)` — BlendShape expression
- `window.setAnimState(s)` — trigger jump on 'dancing'

**Animations:** auto-rotate, drag-to-spin, blink timer, morph-based mouth/emotion, parabolic jump with squash-stretch

**Fallback:** If VRM doesn't load within 3s, renders geometric female character (head, eyes, hair, body, skirt, arms)

### Tools Panel

3 tabs: `📅 日历 | 💰 记账 | 📄 文件处理`

文件处理 tab: conversion UI on top + file history list below. Converted files stored in MinIO, listed with presigned download URLs.

### Key Frontend Widgets

| Widget | File | Purpose |
|--------|------|---------|
| `ChatScreen` | `screens/chat_screen.dart` | Main sci-fi themed chat UI |
| `SciFiBackground` | `widgets/sci_fi_bg.dart` | Animated grid + particles background |
| `CharacterWebView` | `widgets/character_webview.dart` | 3D VRM character via WebView (all platforms) |
| `CharacterView` | `widgets/character_view.dart` | PNG character with Flutter animation (backup) |
| `ToolsPanel` | `widgets/tools_panel.dart` | 3-tab drawer with conversion + file history |

## Ports

| Service | Port |
|---------|------|
| FastAPI | 8000 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO | 9000 (API), 9001 (Console) |

## Email Configuration

126.com SMTP via `.env`:
```env
SMTP_HOST=smtp.126.com
SMTP_PORT=587
SMTP_USERNAME=lvxiang639@126.com
SMTP_PASSWORD=<authorization-code>
SMTP_FROM_EMAIL=lvxiang639@126.com
```

## File Conversion

Two paths:
1. **Tools panel:** `📄 文件处理` tab — pick file, convert, auto-upload to MinIO, listed with downloads
2. **Conversation:** 📎 button → pick file → auto-convert → result in chat stream

Backend endpoint: `POST /api/tools/convert?target=pdf|docx` (multipart upload, returns JSON with `download_url`)

## Platform Notes

- **macOS file_picker:** needs `com.apple.security.files.user-selected.read-only` entitlement
- **iOS microphone:** needs `NSMicrophoneUsageDescription` in Info.plist
- **iOS calendar:** needs `NSCalendarsUsageDescription` in Info.plist
- **3D WebView:** uses Three.js via jsDelivr CDN, VRM model bundled in assets (no network needed for model)
- **Font paths:** `conversion_service.py` font detection is macOS-specific. Add paths for cross-platform.
- **Dart `Platform.isMacOS`** used for file-open behavior and WebView config
