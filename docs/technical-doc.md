# 灵犀 AI 虚拟伴侣 — 技术文档

## 一、项目结构

```
lingxi/
├── readme.md                          # 启动指南 & API 速查
├── docs/
│   ├── technical-doc.md               # 本文档
│   ├── voice-pipeline.md              # 语音对话全链路流程
│   └── superpowers/                   # 设计文档 & 实现计划
├── backend/                           # Python FastAPI 后端
│   ├── Dockerfile
│   ├── docker-compose.yml             # 5 服务：api/db/redis/minio/searxng
│   ├── searxng-settings.yml           # SearXNG 配置（启用百度）
│   ├── requirements.txt
│   ├── alembic.ini + alembic/
│   ├── app/
│   │   ├── main.py                    # FastAPI 入口 + 启动/关闭事件
│   │   ├── config.py                  # pydantic-settings 配置中心
│   │   ├── database.py                # 异步 SQLAlchemy
│   │   ├── api/                       # REST + WebSocket 路由（10 模块）
│   │   ├── models/                    # SQLAlchemy ORM（9 表）
│   │   ├── schemas/                   # Pydantic 请求/响应模型
│   │   ├── services/                  # AI 服务 + 技能 + 编排 + 通知
│   │   └── core/                      # JWT 安全 + 日志
│   └── tests/                         # pytest（22 个用例）
└── frontend/                          # Flutter 跨平台客户端
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart / app.dart / config.dart
    │   ├── models/                    # 数据模型（fromJson）
    │   ├── services/                  # API/WS/录音/TTS/日历/记账/同步
    │   ├── providers/                 # 5 个 ChangeNotifier
    │   ├── screens/                   # 7 个页面
    │   └── widgets/                   # Live2D/聊天气泡/语音按钮
    └── test/
```

---

## 二、后端架构

### 2.1 基础设施

| 服务 | 端口 | 说明 |
|------|------|------|
| FastAPI | 8000 | uvicorn 热重载 |
| PostgreSQL 16 | 5432 | 主数据库 |
| Redis 7 | 6379 | 缓存/会话 |
| MinIO | 9000/9001 | 文件存储/管理界面 |
| SearXNG | 8080 | 元搜索引擎，挂载 `searxng-settings.yml` 启用百度 |

### 2.2 API 层（17 模块）

| 文件 | 路由 | 职责 |
|------|------|------|
| `auth.py` | `/api/auth` | 手机/邮箱登录注册、Token 刷新、个人资料 |
| `characters.py` | `/api/characters` | 角色初始化、配置、背包、装备切换 |
| `conversations.py` | `/api/conversations` | 会话 CRUD、导出、日记、邮件摘要 |
| `shop.py` | `/api/shop` | 服装/声音商店 |
| `calendar.py` | `/api/calendar` | 日历事件 CRUD |
| `expenses.py` | `/api/expenses` | 记账 CRUD + 分类统计 + 周洞察 |
| `sync.py` | `/api/data` | 批量同步 |
| `ws_chat.py` | `/ws/chat` | WebSocket 实时对话 |
| `tools.py` | `/api/tools` | 文件转换、OCR 识别 |
| `notes.py` | `/api/notes` | 笔记 CRUD + 心情记录 |
| `countdown.py` | `/api/countdown` | 倒数日 CRUD |
| `knowledge.py` | `/api/knowledge` | 知识库上传 + RAG 问答 |
| `study.py` | `/api/study` | 解题辅导 + 薄弱分析 + 练习题 |
| `homophone.py` | `/api/study/homophone` | 同音字填空闯关 |
| `agents.py` | `/api/agents` | AI Agent CRUD + 执行 |
| `admin.py` | `/admin` | 管理面板 |
| `deps.py` | — | `get_current_user` 依赖注入 |

### 2.3 数据模型（21+ 表）

| 域 | 表 |
|------|------|
| 用户 | users, user_memories, user_emotion_states |
| 对话 | conversations, messages, conv_memories |
| 日历 | calendar_events |
| 记账 | expense_records |
| 角色 | characters, outfits, voice_packs, user_inventory |
| 工具 | converted_files, sent_emails, notes, mood_logs, countdowns, ocr_records |
| 知识 | knowledge_bases, knowledge_chunks |
| 学习 | study_records, practice_pushes, homophone_exercises |
| 推送 | proactive_pushes, reminder_schedules, daily_contents, daily_content_configs |
| Agent | user_agents, agent_steps |
| 管理 | fcm_tokens |

### 2.4 服务层

**AI 服务：**

| 文件 | 功能 |
|------|------|
| `llm_service.py` | DeepSeek + Qwen，OpenAI 兼容，Semaphore(8) 限流，支持自定义 max_tokens |
| `chat_orchestrator.py` | 意图分类 → 技能执行 → LLM 流式 → TTS → 快捷回复 → 消息持久化 |
| `emotion_service.py` | 对话情绪分析，6 种情绪 |
| `memory_service.py` | 长期记忆提取和注入 |

**技能系统（skills/）：**

| 技能 | 实现 |
|------|------|
| `weather` | LLM 提取城市 → wttr.in → 返回天气 |
| `search` | LLM 提取关键词 → SearXNG(多引擎) → LLM 总结 |
| `calendar` | LLM 提取时间+标题 → 写入 calendar_events |
| `expense` | LLM 提取金额+类别 → 写入 expense_records |
| `convert` | 文件 PDF↔DOCX 转换 |
| `briefing` | 晨间简报：天气+日历+记账汇总 |
| `email` | 对话总结发送到邮箱 |

**主动推送系统：**

| 组件 | 功能 |
|------|------|
| `proactive_service.py` | ~3h 轮询：天气预警+日历提醒+记账提醒+情绪关怀+记忆话题 |
| `push_daily_content()` | 每日精选：运势+笑话+冷知识+小贴士+名言（一次 LLM 调用） |
| `push_chinese_literature()` | 语文高频推送(~3h)：古诗词/成语/典故随机 |
| `generate_daily_content()` | 三级缓存：内存→DB→LLM生成，重启不重复调 LLM |

**通知服务：**

`notification_service.py` — 后台轮询日历事件提醒。`main.py` startup/shutdown 管理生命周期。

### 2.5 核心模块

| 文件 | 功能 |
|------|------|
| `core/security.py` | JWT 签发/验证（HS256），bcrypt 密码哈希 |
| `core/logging.py` | 统一日志格式：`时间 | 级别 | 模块:行号 | 函数 | 消息` |
| `config.py` | pydantic-settings 从 `.env` 读取全部配置 |

---

## 三、模型路由

| 场景 | 模型 |
|------|------|
| 闲聊对话 | `deepseek-v4-flash` |
| 意图分类（5 分类） | `deepseek-v4-flash`（max_tokens=10） |
| 技能数据提取（JSON） | `deepseek-v4-flash` |
| 搜索结果总结 | `deepseek-v4-flash` |
| 工具调用 | `qwen-plus` |
| 语音识别 | `qwen3-asr-flash`（DashScope SDK） |
| 语音合成 | `qwen3-tts-flash`（默认 Cherry）/ CosyVoice（角色定制） |

---

## 四、数据流

### 4.1 对话流程（WebSocket）

```
Flutter App                        FastAPI Backend
    │                                    │
    ├── WS connect(token) ──────────────►│ JWT 验证
    │                                    │
    ├── {"type":"voice","audio":"..."} ──►│
    │                                    ├── ASR (qwen3-asr-flash)
    │   ◄── {"type":"asr_result"}        │
    │                                    ├── classify_intent (deepseek-v4-flash)
    │                                    ├── 技能执行 / LLM 流式对话
    │   ◄── {"type":"llm_stream"}        │
    │                                    ├── 查 Character.voice_pack
    │                                    ├── TTS (qwen3-tts-flash / CosyVoice)
    │   ◄── {"type":"tts_audio"}         │
    │                                    ├── 保存 Message → commit
    │   ◄── {"type":"done"}              │
```

### 4.2 搜索流程

```
用户输入 → LLM 提取关键词 → SearXNG 多引擎搜索 → LLM 总结 → 返回
示例: "帮我搜一下iPhone 17" → "iPhone 17" → Top5结果 → "iPhone 17预计..." → 返回
```

### 4.3 日历/记账流程

```
自然语言 → classify_intent → calendar/expense skill
    → LLM 提取结构化数据（JSON）
    → 写入 PostgreSQL
    → 返回确认消息
```

---

## 五、前端架构

| 层 | 说明 |
|------|------|
| 入口 | `main.dart`, `app.dart`, `config.dart` — MultiProvider + MaterialApp |
| 模型 | `models/*.dart` — User, ExpenseRecord 等数据类 |
| 服务 | `services/*.dart` — ApiClient, WsService, 录音, TTS |
| 状态 | `providers/*.dart` — Auth, Chat, Character, Calendar, Discover |
| 页面 | `screens/*.dart` — 20+ 页面，详见下方 |
| 组件 | `widgets/*.dart` — 聊天气泡/输入栏/背景涂鸦/宠物猫/离线提示 |

**页面清单：**
```
MainScreen (4 Tab)
├── ConversationListScreen  聊天列表
├── DiscoverScreen          发现页（推送/每日精选/语文内容）
├── ToolsCenterScreen       工具中心（12 工具网格）
└── ProfileScreen           个人中心

工具页（12 个）:
Calendar / Expense / Notes / Mood / Email / File / Summary
Countdown / Knowledge / Ocr / Study(含同音字Tab) / AgentList

其他: Login / Chat / Shop / Privacy / Homophone
```

**重要：录音使用 WAV 格式。Web 平台不支持录音。**

---

## 六、扩展点

| 位置 | 方式 |
|------|------|
| 新技能 | 实现 `BaseSkill` → 注册 `skill_registry.py` → `classify_intent()` 加标签 |
| 新工具页 | 创建 Screen → 注册到 `tools_center_screen.dart` |
| 新 LLM | `llm_service.py` 添加 AsyncOpenAI client |
| 新模型 | 创建 model → `__init__.py` 注册 → 建表 |
