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

### 2.2 API 层（10 模块）

| 文件 | 路由 | 职责 |
|------|------|------|
| `auth.py` | `/api/auth` | 手机号登录/注册、Token 刷新、个人资料 |
| `characters.py` | `/api/characters` | 角色初始化、配置、背包、装备切换 |
| `conversations.py` | `/api/conversations` | 会话列表/消息历史/删除/改标题 |
| `shop.py` | `/api/shop` | 服装/声音商店列表、购买 |
| `calendar.py` | `/api/calendar` | 日历事件 CRUD |
| `expenses.py` | `/api/expenses` | 记账 CRUD + 分类统计 |
| `sync.py` | `/api/data` | 批量同步（last_write_wins） |
| `ws_chat.py` | `/ws/chat` | WebSocket 实时对话，JWT 鉴权 |
| `deps.py` | — | `get_current_user` 依赖注入 |
| `seed.py` | — | 启动时插入默认服装和声音包 |

### 2.3 数据模型（9 表）

| 表 | 关键字段 | 关系 |
|------|------|------|
| `users` | phone(unique), nickname, avatar | 1:N conversations/calendar_events/expense_records, 1:1 character |
| `conversations` | user_id, title, updated_at | 1:N messages |
| `messages` | conv_id, role(user/assistant), type(text/voice), content | — |
| `characters` | user_id(unique), name, outfit_id, voice_pack_id | FK→outfits, voice_packs |
| `user_inventory` | user_id, item_type, item_id, equipped | 关联 outfits/voice_packs |
| `outfits` | name, model_file, price | — |
| `voice_packs` | name, cosyvoice_id, price | — |
| `calendar_events` | user_id, title, time, repeat_rule, notified | — |
| `expense_records` | user_id, amount, category, remark, recorded_at | — |

### 2.4 服务层

**AI 服务（3 个）：**

| 文件 | 功能 |
|------|------|
| `asr_service.py` | DashScope SDK `qwen3-asr-flash`，接受 WAV base64，返回文本 |
| `llm_service.py` | `deepseek-v4-flash`（默认）+ `qwen-plus`（工具调用），OpenAI 兼容流式 |
| `tts_service.py` | `qwen3-tts-flash`（DashScope SDK）+ `synthesize_cosyvoice`（角色定制） |

**技能系统（skills/）：**

| 技能 | 实现 |
|------|------|
| `weather` | LLM 提取城市 → wttr.in JSON API → 返回温度/湿度/体感 |
| `search` | **三步：** LLM 提取搜索词 → SearXNG(Google+Bing+百度) → LLM 总结结果 |
| `calendar` | LLM 提取标题+时间+重复规则 → 写入 `calendar_events` 表 |
| `expense` | LLM 提取金额+类别+备注 → 写入 `expense_records` 表 |

每个技能的 LLM 提取提示词使用 `{{ }}` 转义 JSON 花括号，避免 `str.format()` 冲突。

**对话编排：**

`chat_orchestrator.py` — 意图分类 → 技能执行/流式 LLM → **查角色 VoicePack** → TTS → 消息持久化。

关键细节：
- TTS 前查询 `Character` 表获取已装备的 `voice_pack.cosyvoice_id`
- 查询使用 `selectinload(Character.voice_pack)` 预加载关联，避免异步 lazy load 报错
- 若有 CosyVoice 端点则走定制音色，否则传给 `qwen3-tts-flash` 作为 voice 参数

**通知服务：**

`notification_service.py` — asyncio 后台任务，每 60 秒轮询 `notified=False AND time <= now()` 的事件，标记已提醒。在 `main.py` startup/shutdown 事件中管理生命周期。

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

| 层 | 文件 | 说明 |
|------|------|------|
| 入口 | `main.dart`, `app.dart`, `config.dart` | MultiProvider + MaterialApp，默认 `localhost:8000` |
| 模型 | `models/*.dart` | 8 个数据类，`fromJson()` 反序列化 |
| 服务 | `services/*.dart` | api_client, auth, ws, audio_recorder(wav), tts_player, calendar, expense, sync |
| 状态 | `providers/*.dart` | 5 个 ChangeNotifier：auth/chat/character/calendar/expense |
| 页面 | `screens/*.dart` | login, home(4 tab), chat, calendar, expense, character, shop |
| 组件 | `widgets/*.dart` | chat_bubble, voice_record_button, live2d_view(占位) |

**重要：录音使用 WAV 格式（`AudioEncoder.wav`），匹配后端 ASR 服务。Web 平台不支持录音，须用原生平台运行。**

---

## 六、扩展点

| 位置 | 方式 |
|------|------|
| 新技能 | 实现 `BaseSkill` → 注册到 `skill_registry.py` → `classify_intent()` 加标签 |
| 新 LLM | `llm_service.py` 添加 AsyncOpenAI client |
| 新服装/声音 | 插入 `outfits`/`voice_packs` 表 |
| 离线 ASR | `asr_local_service.dart` 集成 whisper.cpp FFI |
| Live2D | 替换 `live2d_view.dart` 占位符为 Cubism SDK |
| 推送通知 | `notification_service.py` 接入 APNs/FCM |
