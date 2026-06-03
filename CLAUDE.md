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
│  api/  ←  domain/  ←  core/  ←  config.py              │
│                │                                        │
│     ┌──────────┼──────────┐                             │
│     ▼          ▼          ▼                             │
│  PostgreSQL   MinIO     Redis (future)                  │
└─────────────────────────────────────────────────────────┘
```

## Conversation Flow

```
User speaks/types
    │
    ▼
┌──────────────────────────────────────────────────────────┐
│ 1. Intent Classification (llm_service.classify_intent)   │
│    DeepSeek → chat|search|weather|calendar|expense|      │
│               convert|briefing|email                     │
└─────────────┬────────────────────────────────────────────┘
              │
    ┌─────────┴─────────┐
    │ skill matched?     │
    ▼ yes               ▼ no (chat)
┌────────────┐    ┌──────────────────────────┐
│ Skill      │    │ Build chat context:      │
│ Registry   │    │  - Long-term memory      │
│ dispatch   │    │  - Emotion tone          │
│            │    │  - Last 20 messages      │
│ Skill      │    │  - System prompt         │
│ returns    │    │                          │
│ SkillResult│    │ LLM stream → full response│
└─────┬──────┘    └──────────┬───────────────┘
      │                      │
      └──────────┬───────────┘
                 ▼
┌──────────────────────────────────────────┐
│ 2. Save Messages (user + assistant)      │
│ 3. Send 'done' to client                 │
│ 4. Fire-and-forget:                      │
│    - Emotion analysis + persist          │
│    - Memory extraction (async LLM)       │
│ 5. TTS synthesis + stream audio          │
└──────────────────────────────────────────┘
```

## Proactive Care Flow

```
Every ~30 minutes:
    │
    ▼
┌─────────────────────────────────────────────┐
│ For each online user (WebSocket connected): │
│                                             │
│ Check 1: Weather alert? ──→ "带伞 ☔"       │
│ Check 2: Event in 1hr?  ──→ "会议提醒"     │
│ Check 3: Missing expense? ──→ "记账 💰"    │
│ Check 4: Idle 4+ hours? ──→ "你回来啦 🐱" │
│ Check 5: Memory topic?  ──→ "周杰伦..."    │
│ Check 6: Sad/angry?     ──→ "要聊聊吗?"    │
│                                             │
│ First hit wins (one message per cycle)      │
└─────────────────────────────────────────────┘

On user connect:
    │
    ▼
┌──────────────────────────────────────┐
│ Memory-driven greeting (1/6 hours):  │
│ "你回来啦~ 北京今天晴呢 ☀️"          │
└──────────────────────────────────────┘
```

## Emotion System

```
User message
    │
    ▼
┌────────────────────────────────────────┐
│ LLM analysis → {emotion, intensity}    │
│ 6 emotions: joy sad angry calm         │
│             surprised worried          │
│                                        │
│ Decay blending:                        │
│  - Each emotion decays 0.05-0.20/30min │
│  - New strong emotion overrides decayed│
│  - intensity ≤ 0 → reset to calm       │
│                                        │
│ Persist to user_emotion_states         │
│                                        │
│ Inject tone into LLM system prompt     │
│ Push emotion_update via WebSocket      │
│ → frontend → character animation       │
└────────────────────────────────────────┘
```

## Long-Term Memory Flow

```
Conversation ends
    │
    ▼
┌──────────────────────────────┐
│ Async LLM extraction:        │
│ "从对话中提取用户关键信息"     │
│                              │
│ → user_memories table        │
│   key: value pairs            │
│   (city, job, hobby, etc.)   │
│                              │
│ > 50 memories → LLM merge    │
└──────────────────────────────┘

New conversation starts
    │
    ▼
┌──────────────────────────────┐
│ Load all memories for user   │
│ Inject as system prompt:     │
│ "用户信息: 喜欢周杰伦,       │
│  在北京工作, 养了猫..."      │
└──────────────────────────────┘
```

## Email Summary Flow

```
User: "发送到我的邮箱"  or  Tools Panel → 📧
    │
    ▼
┌──────────────────────────────────┐
│ 1. Classify intent → email       │
│ 2. Get recent conversation msgs  │
│ 3. LLM summarize dialogue        │
│ 4. SMTP_SSL send (126.com:465)  │
│ 5. Save to sent_emails table     │
│ 6. Return success                │
└──────────────────────────────────┘
```

## File Conversion Flow

```
User picks .docx/.pdf (conversation or tools panel)
    │
    ▼
┌─────────────────────────────────────┐
│ POST /api/tools/convert?target=pdf │
│                                     │
│ PDF→DOCX: pdf2docx library         │
│ DOCX→PDF: python-docx + fpdf2      │
│           (CJK font on macOS)      │
│                                     │
│ Upload result to MinIO              │
│ Save ConvertedFile record          │
│ Return JSON with download_url       │
└─────────────────────────────────────┘
```

## Daily Briefing Flow

```
Auto (8 AM Beijing):
    │
    ▼
┌────────────────────────────────────┐
│ For online users:                  │
│  - Today's calendar events         │
│  - Yesterday's expenses            │
│  - Weather (IP-detected city)      │
│  - LLM formats greeting            │
│  - Dedup via last_briefing_date    │
└────────────────────────────────────┘

Manual: "早上好" → briefing intent → same generation
```

## Location Detection

```
Weather query / Briefing
    │
    ▼
┌──────────────────────────────────┐
│ Layer 1: Client IP header        │
│   (X-Forwarded-For / X-Real-IP)  │
│ Layer 2: Server IP → ip-api.com  │
│ Layer 3: UserMemory key="city"   │
│ Layer 4: Fallback "Beijing"      │
└──────────────────────────────────┘
```

## Domain Model Map

```
app/domain/
├── user/       User, UserMemory, UserEmotionState
├── chat/       Conversation, Message, MessageRole, MessageType
│               Orchestrator, LLM Router, TTS, ASR, Skills
├── calendar/   CalendarEvent, NotificationService
├── expense/    ExpenseRecord
├── character/  Character, Outfit, VoicePack, UserInventory
└── tools/      ConvertedFile, SentEmail, Note, MoodLog
                Conversion, Email, MinIO, Location, Proactive
```

## Database Tables (15)

| Domain | Table | Key Fields |
|--------|-------|-----------|
| User | users | phone, nickname, email, last_briefing_date |
| User | user_memories | key, value, source_conv_id |
| User | user_emotion_states | current_emotion, intensity |
| Chat | conversations | title, user_id, updated_at |
| Chat | messages | conv_id, role, type, content |
| Calendar | calendar_events | title, time, repeat_rule |
| Expense | expense_records | amount, category, remark |
| Character | characters | user_id, outfit_id, voice_pack_id |
| Character | outfits | name, model_file, price |
| Character | voice_packs | name, cosyvoice_id, price |
| Character | user_inventory | user_id, item_type, item_id, equipped |
| Tools | converted_files | original_name, target_name, object_name, file_size |
| Tools | sent_emails | conv_title, recipient, summary_preview |
| Tools | notes | title, content, note_type |
| Tools | mood_logs | emotion, intensity, note |

## API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| POST | /api/auth/login | Phone login → JWT |
| GET/PUT | /api/auth/profile | User profile + email |
| GET | /api/characters/config | Character config |
| GET/PUT | /api/characters/outfits, /voices, /equip | Character customization |
| GET | /api/conversations | List conversations |
| GET | /api/conversations/{id}/messages | List messages |
| POST | /api/conversations/{id}/email-summary | Summarize + email |
| GET | /api/conversations/sent-emails | Sent email history |
| GET/POST/DELETE | /api/calendar | Calendar CRUD |
| GET/POST/PUT/DELETE | /api/expenses | Expense CRUD |
| GET | /api/expenses/stats?period=week|month | Expense stats |
| POST | /api/tools/convert?target=pdf|docx | File conversion |
| GET | /api/tools/files | Converted file list |
| GET | /api/tools/files/{id}/download | File download |
| POST | /api/tools/ocr | Image OCR via Qwen-VL |
| GET/POST/PUT/DELETE | /api/notes | Notes CRUD |
| GET/POST | /api/notes/moods | Mood logging |
| GET | /api/notes/moods/stats?period=week|month | Mood stats |
| WS | /ws/chat | WebSocket chat |

## Frontend Widget Map

```
ChatScreen
├── SciFiBackground        (animated grid + particles)
├── AppBar                 (status dot + tools pill + character btn)
├── Body (Stack)
│   ├── CharacterWebView   (SVG pet cat, bottom-right 130x200)
│   ├── _Msgs              (full-screen transparent chat)
│   │   ├── _bubble        (gradient avatar + glass card)
│   │   └── _streamBubble  (with typing indicator)
│   └── Status indicators  (connecting bar, TTS chip)
├── _InputBar              (text/attach/voice floating row)
└── ToolsPanel             (full-screen overlay)
    ├── Sidebar            (7 icon menu items)
    ├── _CalendarContent
    ├── _ExpenseContent    (week/month toggle + edit dialog)
    ├── _NotesContent      (list + add dialog)
    ├── _OcrContent        (pick image → result)
    ├── _MoodContent       (emoji picker + week stats)
    ├── _ConversionContent (file pick + convert + history)
    └── _EmailContent      (send button + sent history)
```

## Skills (8 registered)

| Skill | Intent | What it does |
|-------|--------|-------------|
| weather | weather | IP geolocation + wttr.in API |
| calendar | calendar | LLM extract time/title → CalendarEvent |
| expense | expense | LLM extract amount/category → ExpenseRecord |
| search | search | SearXNG + LLM summarize |
| convert | convert | File format detection → conversion |
| briefing | briefing | Morning report: weather+calendar+expenses |
| email | email | Summarize conversation → SMTP send |
| email_skill | email | Same (conversation-triggered) |

## Configuration (.env)

```env
DEEPSEEK_API_KEY=sk-xxx
QWEN_API_KEY=sk-xxx
JWT_SECRET=lingxi-dev-jwt-secret-2026
DATABASE_URL=postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi
SMTP_HOST=smtp.126.com
SMTP_PORT=465
SMTP_USERNAME=lvxiang639@126.com
SMTP_PASSWORD=<authorization-code>
SMTP_FROM_EMAIL=lvxiang639@126.com
```

## Platform Notes

- **macOS file_picker:** needs `com.apple.security.files.user-selected.read-only` entitlement
- **iOS microphone:** `NSMicrophoneUsageDescription` in Info.plist
- **iOS calendar:** `NSCalendarsUsageDescription` in Info.plist  
- **3D/Vector character:** SVG-based in WebView, works on all platforms
- **SMTP:** uses SSL port 465 for 126.com
- **Font paths:** `conversion_service.py` CJK fonts are macOS-specific
- **Timezones:** backend uses Beijing time (UTC+8) for all date filtering

## Ports

| Service | Port |
|---------|------|
| FastAPI | 8000 |
| PostgreSQL | 5432 |
| MinIO | 9000 (API), 9001 (Console) |
