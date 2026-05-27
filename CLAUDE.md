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
flutter run                                        # Launch on device/emulator
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

- **Config is centralized** in `config.py` using `pydantic-settings` with `.env` support. All env vars (API keys, DB URLs, MinIO creds) are read through `settings.X` — never inline.
- **All database access is async** (`AsyncSession`, `async_sessionmaker`, `get_db` dependency). Uuid PKs use `sqlalchemy.Uuid` (not PostgreSQL-specific `UUID`) for SQLite compatibility in tests.
- **Auth is phone-based login** (no passwords). `POST /api/auth/login` with a phone number returns a JWT; new users auto-register. `get_current_user` in `deps.py` validates the Bearer token and returns the `User` ORM instance.

### Skill Plugin System

The conversation pipeline is intent-driven:

1. `chat_orchestrator.py` receives a user message
2. `llm_service.py:classify_intent()` calls DeepSeek to classify into `chat|search|weather|calendar|expense`
3. If skill matched → dispatch to `SkillRegistry` → skill returns `SkillResult(text, data)`
4. If `chat` → stream LLM response with conversation history (last 20 messages)
5. Save assistant message → synthesize TTS → send `done`

**Adding a new skill:** Implement `BaseSkill` (abstract `name` + `execute()`), register in `skill_registry.py`, add the intent label in `llm_service.classify_intent()`.

### LLM Routing

`llm_service.py` creates two `AsyncOpenAI` clients (DeepSeek and Qwen). Default model is DeepSeek (`deepseek-chat`); pass `force_model="qwen"` to switch. Both use OpenAI-compatible API. `chat_stream()` is an async generator.

### Models (data)

9 tables. Key relationships:
- `User` 1:N `Conversation`, `CalendarEvent`, `ExpenseRecord`
- `User` 1:1 `Character` (character config: name, live2d model, current outfit/voice)
- `UserInventory` tracks owned outfits/voice_packs with `equipped` flag; `ItemType` enum discriminates
- `Outfit` and `VoicePack` are shop items (`price=0` = free default)
- `CalendarEvent` and `ExpenseRecord` have `updated_at` for `last_write_wins` sync

### Frontend (Flutter)

**State management:** Provider pattern with 5 `ChangeNotifier` providers registered in `app.dart:MultiProvider`. Auth state drives top-level routing (LoginScreen vs HomeScreen). HomeScreen uses `IndexedStack` with bottom nav for 4 tabs.

**Service layer:** `api_client.dart` wraps HTTP with Bearer token injection from SharedPreferences. `ws_service.dart` manages WebSocket lifecycle as a broadcast `Stream<WsMessage>`.

**Conversation flow on client:** `chat_provider.dart` listens to `WsService.messages` stream, dispatches by `type` field (`asr_result` → add user message, `llm_stream` → append delta to `_streamingText`, `done` → finalize assistant message, `skill_call` → show chip).

## Ports

| Service | Port |
|---------|------|
| FastAPI | 8000 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO | 9000 (API), 9001 (Console) |
