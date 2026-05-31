# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Backend
cd backend
pip install -r requirements.txt                    # Install deps
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload  # Start dev server
python -m pytest tests/ -v                         # Run all tests
python -m pytest tests/test_auth.py::test_login_new_user -v  # Run single test
alembic revision --autogenerate -m "description"    # Generate migration
alembic upgrade head                               # Apply migrations

# Frontend
cd frontend
flutter pub get                                    # Install deps
flutter analyze                                    # Static analysis
flutter test                                       # Run tests
flutter run -d macos                               # macOS
flutter run -d "iPhone 16"                         # iOS Simulator
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

- **Config is centralized** in `config.py` using `pydantic-settings` with `.env` support. All env vars (API keys, DB URLs, SMTP creds) are read through `settings.X` — never inline.
- **All database access is async** (`AsyncSession`, `async_sessionmaker`, `get_db` dependency). Uuid PKs use `sqlalchemy.Uuid` (not PostgreSQL-specific `UUID`) for SQLite compatibility in tests.
- **Auth is phone-based login** (no passwords). `POST /api/auth/login` with a phone number returns a JWT; new users auto-register. `get_current_user` in `deps.py` validates the Bearer token and returns the `User` ORM instance.

### Skill Plugin System

The conversation pipeline is intent-driven:

1. `chat_orchestrator.py` receives a user message
2. `llm_service.py:classify_intent()` calls DeepSeek to classify into `chat|search|weather|calendar|expense|convert`
3. If skill matched → dispatch to `SkillRegistry` → skill returns `SkillResult(text, data)`
4. If `chat` → stream LLM response with conversation history (last 20 messages)
5. Save assistant message → synthesize TTS → send `done`

**Registered skills:** weather, calendar, expense, search, convert

**Adding a new skill:** Implement `BaseSkill` (abstract `name` + `execute()`), register in `skill_registry.py`, add the intent label in `llm_service.classify_intent()`.

### LLM Routing

`llm_service.py` creates two `AsyncOpenAI` clients (DeepSeek and Qwen). Default model is DeepSeek (`deepseek-chat`); pass `force_model="qwen"` to switch. Both use OpenAI-compatible API. `chat_stream()` is an async generator. Errors are raised (not silently swallowed) so callers can handle them.

### Models (data)

10 tables (User now has `email` field). Key relationships:
- `User` 1:N `Conversation`, `CalendarEvent`, `ExpenseRecord`
- `User` 1:1 `Character` (character config: name, live2d model, current outfit/voice)
- `UserInventory` tracks owned outfits/voice_packs with `equipped` flag; `ItemType` enum discriminates
- `Outfit` and `VoicePack` are shop items (`price=0` = free default)
- `CalendarEvent` and `ExpenseRecord` have `updated_at` for `last_write_wins` sync
- `User.email` nullable String(200) — used for email summary feature

### Services (new since initial version)

| Service | Purpose |
|---------|---------|
| `email_service.py` | Async SMTP email sending via `asyncio.to_thread` + `smtplib`. Uses STARTTLS on port 587. |
| `conversion_service.py` | DOCX ↔ PDF conversion. PDF→DOCX via `pdf2docx`, DOCX→PDF via `python-docx` + `fpdf2` with CJK font support. |
| `notification_service.py` | Polls `calendar_events` for due notifications. Handles recurring event rescheduling with proper calendar-month arithmetic. |

### API Endpoints (new since initial version)

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/conversations/{id}/email-summary` | LLM-summarize conversation → email to user |
| `POST` | `/api/tools/convert?target=pdf\|docx` | Upload file → convert → download result |
| `PUT`  | `/api/auth/profile` | Now accepts `email` field |

### Frontend (Flutter)

**State management:** Provider pattern with 6 `ChangeNotifier` providers registered in `app.dart:MultiProvider`. Auth state drives top-level routing (LoginScreen vs HomeScreen).

**Service layer:** `api_client.dart` wraps HTTP with Bearer token injection from SharedPreferences. `ws_service.dart` manages WebSocket lifecycle as a broadcast `Stream<WsMessage>`.

**Conversation flow on client:** `chat_provider.dart` listens to `WsService.messages` stream, dispatches by `type` field (`asr_result` → add user message, `llm_stream` → append delta to `_streamingText`, `done` → finalize assistant message, `skill_call` → show chip).

### UI Layout (chat_screen.dart)

```
┌──────────────────────────────────┐
│  🟢 灵犀     📧  🔧  👤        │ ← AppBar: connection status + actions
│                                  │
│  Sci-fi animated background      │ ← sci_fi_bg.dart (grid + particles)
│                                  │
│          ┌──────────┐            │
│          │ Character │            │ ← Upper 58% — character_webview.dart
│          │ (WebView  │            │   (SVG/CSS on iOS/Android,
│          │  or PNG)  │            │    PNG on macOS)
│          └──────────┘            │
│  ┌──────────────────┐            │
│  │ 灵犀: 你好        │            │ ← Glass chat panel
│  │ 你: 帮我转换      │            │   Left-aligned, prefixed
│  └──────────────────┘            │
│                                  │
│        [💬] [📎] (🎤)            │ ← Floating input cluster
└──────────────────────────────────┘
```

**Key frontend widgets:**

| Widget | File | Purpose |
|--------|------|---------|
| `ChatScreen` | `screens/chat_screen.dart` | Main chat UI with sci-fi theme |
| `SciFiBackground` | `widgets/sci_fi_bg.dart` | Animated grid + particles background |
| `CharacterWebView` | `widgets/character_webview.dart` | Character display — WebView on iOS/Android, PNG fallback on macOS |
| `CharacterView` | `widgets/character_view.dart` | PNG-based character with Flutter animation controllers |
| `ToolsPanel` | `widgets/tools_panel.dart` | 3-tab drawer: 📅 Calendar, 💰 Expense, 🔄 Conversion |
| `character_html.dart` | `widgets/character_html.dart` | Auto-generated — SVG/CSS anime character embedded as Dart string |
| `character.html` | `assets/character/character.html` | Source SVG character (edit here, regenerate via Python script) |

**Regenerating character_html.dart:**
```bash
python3 -c "
with open('frontend/assets/character/character.html','r') as f:
    c=f.read()
c=c.replace('\\\\','\\\\\\\\').replace('\$','\\\\\$')
with open('frontend/lib/widgets/character_html.dart','w') as f:
    f.write(f'const String kCharacterHtml = r\\'\\'\\'\\n{c}\\n\\'\\'\\'\\;\\n')
"
```

### Email Summary Feature

Flow: AppBar 📧 → check email in profile → LLM summarizes conversation → SMTP send.
Config via `.env`:
```env
SMTP_HOST=smtp.126.com
SMTP_PORT=587
SMTP_USERNAME=lvxiang639@126.com
SMTP_PASSWORD=<authorization-code>
SMTP_FROM_EMAIL=lvxiang639@126.com
```

### File Conversion Feature

Two paths:
1. **Tools panel:** `🔧` → `🔄 转换` tab — pick file, convert, download
2. **Conversation:** 📎 button → pick file → auto-convert → result in chat stream

Backend endpoint: `POST /api/tools/convert?target=pdf|docx` (multipart upload)

## Ports

| Service | Port |
|---------|------|
| FastAPI | 8000 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO | 9000 (API), 9001 (Console) |

## Platform-specific notes

- **macOS:** WKWebView `setOpaque()` throws `UnimplementedError` — character falls back to PNG `CharacterView`. WebView only used for character on iOS/Android.
- **Font paths:** `conversion_service.py` font detection is macOS-specific. Add Linux/Windows font paths for cross-platform deployment.
- **Dart `Platform.isMacOS`** guards WebView background transparency and file-open behavior.
