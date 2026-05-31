# Daily Briefing + Long-term Memory Design

Date: 2026-05-31

## 1. Daily Briefing (每日简报)

### Trigger
- **Auto**: 8:00 AM local time, pushed via WebSocket to all online users
- **Manual**: User says "早上好" / "今日简报" / "今天有什么" — new `briefing` intent

### Content
```
☀️ 早安问候（LLM 生成一句，融入天气+心情）

📅 今日提醒
  · event 1
  · event 2

💰 昨日消费
  · 餐饮 ¥45.00
  · 交通 ¥12.00
  共 ¥57.00
```

### Technical Design

**Backend — auto push:**
- Extend `notification_service.py`: keep current 60s poll, add a check for hour == 8 and `last_briefing_date != today`
- New `briefing_service.py`: fetch weather + today's calendar events + yesterday's expenses → call LLM to format → push via WebSocket
- Track `last_briefing_date` per user (in Redis or a new column on User)
- Only send if WebSocket connected; skip if offline

**Backend — manual trigger:**
- Add `briefing` to `classify_intent()` labels
- New `briefing_skill.py`: calls briefing_service, returns formatted result
- Register in skill_registry

**Frontend:**
- Handle `briefing` message type in WebSocket stream
- `flutter_local_notifications`: schedule daily 8:00 AM local notification (taps open app)

### Dedup
- Each user gets at most 1 auto-briefing per day (`last_briefing_date == today → skip`)
- Manual trigger always works, no limit

---

## 2. Long-term Memory (长期记忆)

### Core Concept
After every conversation ends, LLM scans the dialogue asynchronously and extracts key facts/preferences about the user. These memories are injected into future conversations via the system prompt.

### Flow
```
Conversation ends
  → async LLM call: "extract user facts from this conversation"
  → save to user_memories table
  → merge/summarize if > 50 records

New conversation starts
  → load all memories for user
  → inject as system prompt: "用户信息: 喜欢周杰伦, 在北京工作, ..."
  → proceed with normal chat
```

### Data Model
```sql
user_memories:
  id: UUID PK
  user_id: UUID FK → users
  key: String(100)     -- e.g. "favorite_singer"
  value: String(500)   -- e.g. "周杰伦"
  source_conv_id: UUID FK → conversations (nullable)
  created_at: datetime
  updated_at: datetime
```

### Memory Extraction Prompt
```
从以下对话中提取关于用户的关键信息。只提取明确的信息，不要推测。
每个事实一行，格式: key: value

示例:
- favorite_singer: 周杰伦
- city: 北京
- job: 产品经理
- hobby: 摄影

对话:
{conversation_text}
```

### Memory Injection
System prompt prefix for every new conversation:
```
你是一个贴心的AI助手。以下是关于你正在对话的用户的信息，请在对话中自然地运用这些信息（不要刻意提及你知道这些）：

用户信息:
- 喜欢周杰伦
- 在北京工作
- 经常出差
- 养了一只猫叫奶茶
```

### Scale Control
- Max 50 memories per user
- When > 50, LLM merges/summarizes older ones
- User can say "忘记xxx" → delete specific memory (new intent or chat-driven)

### Privacy
- All data stays on local server
- Memories are per-user, never shared across users
- Delete cascade: when user is deleted, all memories are deleted

---

## 3. Implementation Order

1. Long-term memory model + extraction logic + injection
2. Briefing service (auto + manual)
3. Frontend notification + briefing display
