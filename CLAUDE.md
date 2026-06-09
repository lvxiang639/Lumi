# LINGXI (灵犀) — AI Companion App

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND (Flutter)                    │
│  screens/  widgets/  providers/  services/  models/     │
│     │              │              │                     │
│     │    WebSocket │    HTTP REST │                     │
└─────┼──────────────┼──────────────┼─────────────────────┘
      │              │              │
┌─────┼──────────────┼──────────────┼─────────────────────┐
│     ▼              ▼              ▼                     │
│                  BACKEND (FastAPI)                       │
│  api/  ←  domain/knowledge/  ←  infrastructure/        │
│                │                                        │
│     ┌──────────┼──────────┐                             │
│     ▼          ▼          ▼                             │
│  PostgreSQL   MinIO   FAISS (vector search)             │
└─────────────────────────────────────────────────────────┘
```

## Conversation Flow (Updated)

```
User speaks/types
    │
    ▼
┌──────────────────────────────────────────────────────────┐
│ 1. Intent Classification (llm_service.classify_intent)   │
│    DeepSeek → chat|search|weather|calendar|expense|      │
│               convert|briefing|email|agent               │
│    System messages (📋✅❌📝📧📎📄) → force chat         │
└─────────────┬────────────────────────────────────────────┘
              │
    ┌─────────┴─────────┐
    │ intent?            │
    ▼ agent             ▼ skill           ▼ chat
┌────────────┐  ┌──────────────┐  ┌──────────────────────┐
│ AI Agent   │  │ Skill        │  │ Build chat context:   │
│ plan→exec  │  │ Registry     │  │ - Current time (IP)   │
│ multi-step │  │ dispatch     │  │ - AI Persona          │
│            │  │ with context │  │ - Memory (keyword)    │
│ returns    │  │ Skill        │  │ - Emotion (info only) │
│ text       │  │ returns      │  │ - Last 10 messages    │
└────────────┘  │ SkillResult  │  │ LLM stream→response   │
                └──────────────┘  └──────────────────────┘
                  
                      ▼
┌──────────────────────────────────────────┐
│ 2. Save Messages (user + assistant)      │
│ 3. Send 'done' + quick_reply suggestions │
│ 4. Fire-and-forget:                      │
│    - Emotion analysis + persist          │
│    - Memory extraction (async LLM)       │
│    - Conv memory summary (cumulative)    │
└──────────────────────────────────────────┘
```

## Proactive Care Flow (V2)

```
Every ~3 hours (22:00-8:00 quiet hours):
    │
    ▼
┌─────────────────────────────────────────────┐
│ For each online user (WebSocket connected): │
│                                             │
│ Check: Holiday? → push holiday greeting ❌  │
│ Collect structured data from:               │
│  - Weather alert                            │
│  - Calendar event                           │
│  - Expense reminder                         │
│  - Idle greeting                            │
│  - Water reminder                           │
│  - Emotion care                             │
│  - Memory topic                             │
│                                             │
│ LLM generates natural push text (1 call)     │
│ Save to proactive_pushes (DB throttle)       │
│ Max 3 pushes/day, 2h cooldown                │
│                                             │
│ News: separate push (SearXNG, cached 3h)     │
│ Countdown: alert at 3/1/0 days               │
└─────────────────────────────────────────────┘

On user connect (8:00+):
    │
    ▼
┌──────────────────────────────────────┐
│ Morning briefing (once/day):         │
│ weather + calendar + expense summary │
└──────────────────────────────────────┘
```

## Domain Model Map (Updated)

```
app/domain/
├── knowledge/       KnowledgeBase, KnowledgeChunk (RAG)
│   ├── repository.py    Abstract interface
│   └── service.py       Chunking + BGE-M3 embedding
├── repositories/
│   ├── user_repo.py     User, Memory, Emotion queries
│   └── message_repo.py  Conversation, Message queries
│
app/models/           SQLAlchemy models (21 tables)
├── user/            User, UserMemory, UserEmotionState
├── chat/            Conversation, Message, ConvMemory
├── calendar/        CalendarEvent
├── expense/         ExpenseRecord
├── character/       Character, Outfit, VoicePack, UserInventory
├── tools/           ConvertedFile, SentEmail, Note, MoodLog
├── knowledge/       KnowledgeBase, KnowledgeChunk (ARRAY vectors)
├── proactive_push   Push throttle records (DB-backed)
├── reminder_schedule Custom time-based reminders
└── countdown        Countdown days
```

## Database Tables (21)

| Domain | Tables |
|--------|--------|
| User | users, user_memories, user_emotion_states |
| Chat | conversations, messages, conv_memories |
| Calendar | calendar_events |
| Expense | expense_records |
| Character | characters, outfits, voice_packs, user_inventory |
| Tools | converted_files, sent_emails, notes, mood_logs |
| Knowledge | knowledge_bases, knowledge_chunks |
| Push | proactive_pushes, reminder_schedules |
| Countdown | countdowns |

## API Endpoints (55+)

| Method | Path | Purpose |
|--------|------|---------|
| POST | /api/auth/login | Phone login → JWT |
| POST | /api/auth/register | Email register (bcrypt) |
| POST | /api/auth/email-login | Email login |
| DELETE | /api/auth/account | Permanently delete account |
| GET/PUT | /api/auth/profile | Profile + email + persona |
| GET/PUT | /api/characters/* | Character customization |
| GET | /api/conversations | List conversations |
| GET | /api/conversations/{id}/messages | List messages |
| POST | /api/conversations/{id}/export | Export PDF/DOCX |
| POST | /api/conversations/{id}/diary | AI diary from conversation |
| GET/POST/DELETE | /api/calendar | Calendar CRUD |
| GET/POST/PUT/DELETE | /api/expenses | Expense CRUD |
| GET | /api/expenses/stats | Stats by category (week/month) |
| GET | /api/expenses/insights/weekly | Weekly insight report |
| POST | /api/tools/convert | File conversion (PDF↔DOCX) |
| GET | /api/tools/files | Converted file list |
| GET | /api/tools/files/{id}/download | File download |
| POST | /api/tools/ocr | Image OCR via Qwen-VL |
| GET/POST/PUT/DELETE | /api/notes | Notes CRUD |
| GET/POST | /api/notes/moods | Mood logging |
| GET | /api/countdown | Countdown days CRUD |
| POST | /api/knowledge/upload | Upload doc → RAG knowledge base |
| GET/DELETE | /api/knowledge/{id} | List/delete knowledge bases |
| POST | /api/knowledge/{id}/chat | RAG chat with sources |
| WS | /ws/chat | WebSocket chat |

## Skills (8 registered)

| Skill | Intent | What it does |
|-------|--------|-------------|
| weather | weather | IP geolocation + wttr.in API |
| calendar | calendar | LLM extract time/title → CalendarEvent |
| expense | expense | LLM extract amount/category → ExpenseRecord |
| search | search | SearXNG + LLM (full results, no summarization) |
| convert | convert | File format detection → conversion |
| briefing | briefing | Morning report: weather+calendar+expenses |
| email | email | Summarize conversation → SMTP send |
| agent | agent | Multi-step: plan → execute skills → consolidate |

## Frontend Widget Map (Updated)

```
ChatScreen
├── ChatBgPainter        (WhatsApp-style tile doodles)
├── AppBar               (title + online dot + ⋮ menu)
├── Body (Stack)
│   ├── ChatBgPainter    (background tile pattern)
│   ├── ChatMessageList  (messages + bubbles + timestamps)
│   ├── Quick Reply Chips (glass pills with emoji)
│   └── OfflineBanner    (top banner when disconnected)
├── ChatInputBar         (voice mic + text field + send)
│   └── (pet cat resting removed)
└── AssistantMenu        (email, note, summary, export, share, diary)

MainScreen (4 tabs)
├── ConversationListScreen (pin + swipe delete + search)
├── ToolsCenterScreen      (3×3 grid, 10 tools)
├── DiscoverScreen         (notifications + news cards)
└── ProfileScreen          (user card + theme switch + 6 settings)

Tools (10)
├── CalendarPage           (date cards, upcoming/past groups)
├── ExpensePage            (stats card + category chart + detail list)
├── NotesPage, MoodPage, EmailPage, FilePage
├── SummaryPage, CountdownPage, KnowledgePage
└── PrivacyScreen
```

## Key Design Decisions (Updated)

- **Time injection**: Server local time injected into system prompt first line
- **Memory pruning**: Only last 5 + keyword-matched memories injected (max 8 lines)
- **History limit**: 10 messages (down from 20)
- **No conv_memory injection**: Removed from system prompt
- **Proactive throttle**: DB-backed (`proactive_pushes` table), survives restarts
- **LLM rate limit**: asyncio.Semaphore(8) for concurrent calls
- **RAG embedding**: BGE-M3 (1024-dim) via sentence-transformers, FAISS vector search
- **Pet cat**: 4-frame SVG walk cycle with body sway, occasional pause
- **Offline detection**: DNS lookup every 15s, red banner when disconnected
- **iOS/Android widgets**: Swift + Kotlin widget scaffold

## Environment (.env)

```env
DEEPSEEK_API_KEY=sk-xxx
QWEN_API_KEY=sk-xxx
JWT_SECRET=<random-64-char>
DATABASE_URL=postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi
SMTP_HOST=smtp.126.com
SMTP_PORT=465
SMTP_USERNAME=lvxiang639@126.com
SMTP_PASSWORD=<authorization-code>
SMTP_FROM_EMAIL=lvxiang639@126.com
```
