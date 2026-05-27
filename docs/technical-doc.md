# 灵犀 AI 虚拟伴侣 — 技术文档

## 一、项目结构总览

```
lingxi/
├── readme.md                          # 启动指南 & API 速查
├── docs/
│   └── superpowers/
│       ├── specs/                     # 设计文档
│       └── plans/                     # 实现计划
├── backend/                           # Python FastAPI 后端
│   ├── Dockerfile                     # 容器构建文件
│   ├── docker-compose.yml             # 开发环境编排（DB/Redis/MinIO）
│   ├── requirements.txt               # Python 依赖
│   ├── alembic.ini                    # 数据库迁移配置
│   ├── alembic/                       # 迁移脚本
│   ├── app/                           # 应用代码
│   └── tests/                         # 测试
└── frontend/                          # Flutter 跨平台客户端
    ├── pubspec.yaml                   # Flutter 依赖
    ├── lib/                           # Dart 源码
    └── test/                          # Flutter 测试
```

---

## 二、后端（backend/）

### 2.1 基础设施

| 文件 | 功能 |
|------|------|
| `Dockerfile` | 基于 Python 3.12-slim，安装依赖后通过 uvicorn 启动 |
| `docker-compose.yml` | 编排 4 个服务：api(8000)、db(5432)、redis(6379)、minio(9000) |
| `requirements.txt` | FastAPI + SQLAlchemy + Redis + MinIO + OpenAI SDK + JWT 等 |
| `alembic.ini` + `alembic/` | 异步数据库迁移配置，自动从模型生成 SQL |

### 2.2 app/ — 应用核心

```
app/
├── main.py           # 入口：FastAPI 实例、CORS、路由注册、启动事件
├── config.py         # 配置中心：从 .env / 环境变量读取所有配置
├── database.py       # 异步 SQLAlchemy 引擎、Session 工厂、get_db 依赖
├── api/              # REST + WebSocket 路由层
├── models/           # 数据库模型（ORM）
├── schemas/          # Pydantic 请求/响应模型
├── services/         # AI 服务 + 技能系统 + 对话编排
└── core/             # 安全模块：JWT 签发/验证
```

#### 2.2.1 config.py — 配置中心

- 使用 `pydantic-settings` 自动加载 `.env` 文件
- 管理：数据库连接串、Redis、MinIO、JWT 密钥、DeepSeek/Qwen API Key、ASR/TTS 端点

#### 2.2.2 database.py — 数据库层

- SQLAlchemy 异步引擎（asyncpg 驱动）
- `Base` 声明式基类
- `get_db()` — FastAPI 依赖注入，自动管理会话生命周期

#### 2.2.3 api/ — 路由层（8 个模块）

| 文件 | 路由前缀 | 职责 |
|------|---------|------|
| `auth.py` | `/api/auth` | 手机号登录/注册、Token 刷新、个人资料 |
| `characters.py` | `/api/characters` | 角色初始化、配置读写、背包查询、装备切换 |
| `conversations.py` | `/api/conversations` | 会话列表/消息历史/删除/改标题 |
| `shop.py` | `/api/shop` | 服装/声音商店列表、购买 |
| `calendar.py` | `/api/calendar` | 日历事件的增删改查 |
| `expenses.py` | `/api/expenses` | 记账记录的增删改查 + 分类统计 |
| `sync.py` | `/api/data` | 批量同步日历和记账数据 |
| `ws_chat.py` | `/ws/chat` | WebSocket 实时对话，JWT 鉴权 |
| `deps.py` | — | `get_current_user` 依赖：从 Bearer Token 解析当前用户 |
| `seed.py` | — | 启动时自动插入默认服装和声音包 |

#### 2.2.4 models/ — 数据模型（9 个 ORM 类）

| 文件 | 表名 | 说明 |
|------|------|------|
| `user.py` | `users` | 用户（手机号、昵称、头像），关联所有子表 |
| `conversation.py` | `conversations` | 对话会话，`updated_at` 追踪活跃时间 |
| `message.py` | `messages` | 单条消息，枚举 `role`(user/assistant) 和 `type`(text/voice) |
| `character.py` | `characters` | 角色配置（名字、Live2D 模型、当前服装/声音），与 User 一对一 |
| `inventory.py` | `user_inventory` | 背包：拥有的服装和声音包，`equipped` 标记当前使用 |
| `outfit.py` | `outfits` | 服装商品（模型文件、缩略图、价格） |
| `voice_pack.py` | `voice_packs` | 声音包商品（CosyVoice ID、声音类型、试听 URL、价格） |
| `calendar_event.py` | `calendar_events` | 日历事件（时间、重复规则、是否已提醒） |
| `expense_record.py` | `expense_records` | 记账记录（金额、类别、备注、实际日期） |

**核心关系：**
- User 1:N Conversation、CalendarEvent、ExpenseRecord
- User 1:1 Character
- UserInventory 通过 `item_type` + `item_id` 关联 Outfit 或 VoicePack
- Character 通过 FK 指向当前使用的 Outfit 和 VoicePack

#### 2.2.5 schemas/ — 请求/响应模型

每个 API 模块有独立的 Pydantic schema 文件，定义请求体和响应体的字段校验规则。与 `api/` 目录一一对应。

#### 2.2.6 services/ — 核心业务逻辑

**AI 服务（3 个）：**

| 文件 | 类 | 功能 |
|------|-----|------|
| `asr_service.py` | `ASRService` | 调用 Qwen3-ASR-Flash 语音转文字 |
| `llm_service.py` | `LLMRouter` | 多模型路由：闲聊→DeepSeek，工具调用→Qwen；流式输出 + 意图分类 |
| `tts_service.py` | `TTSService` | 文字转语音：Qwen3-TTS-Flash（快速，97ms）+ CosyVoice（角色音色） |

**技能系统（skills/）：**

| 文件 | 技能名 | 功能 |
|------|--------|------|
| `base.py` | — | 抽象基类 `BaseSkill` + `SkillResult` 数据类 |
| `weather.py` | `weather` | 调用 wttr.in 获取天气信息 |
| `search.py` | `search` | 对接 SearXNG 元搜索引擎 |
| `calendar_skill.py` | `calendar` | 日历事件提取（预留 LLM 提取升级） |
| `expense_skill.py` | `expense` | 记账金额/类别提取（预留 LLM 提取升级） |
| `skill_registry.py` | — | 技能注册表，按意图名称分发到对应技能 |

**对话编排：**

| 文件 | 功能 |
|------|------|
| `chat_orchestrator.py` | 核心调度：意图分类 → 技能分发/LLM 对话 → 消息存储 → TTS 合成 |

处理流程：
```
用户消息 → 意图分类(LLM) → 技能执行/流式 LLM → 消息持久化 → TTS → 返回客户端
```

#### 2.2.7 core/ — 安全模块

| 文件 | 功能 |
|------|------|
| `security.py` | JWT 签发（create_access_token）、解码（decode_access_token）、bcrypt 密码哈希 |

---

## 三、前端（frontend/lib/）

### 3.1 入口文件

| 文件 | 功能 |
|------|------|
| `main.dart` | App 入口，初始化 Flutter 绑定和本地通知插件 |
| `app.dart` | 顶层 Widget：MultiProvider 注册所有 Provider + MaterialApp 配置 + 登录态路由 |
| `config.dart` | 运行时配置：API 和 WebSocket 地址（`--dart-define` 注入） |

### 3.2 models/ — 数据模型（8 个类）

与后端 schemas 一一对应，每个类包含 `fromJson()` 工厂方法。需 `toJson()` 的类（CalendarEvent、ExpenseRecord）也实现序列化。文件：`user.dart`, `message.dart`, `conversation.dart`, `character_config.dart`, `outfit.dart`, `voice_pack.dart`, `calendar_event.dart`, `expense_record.dart`。

### 3.3 services/ — API 与服务层（9 个模块）

| 文件 | 功能 |
|------|------|
| `api_client.dart` | HTTP 客户端封装：GET/POST/PUT/DELETE，自动附带 Bearer Token |
| `auth_service.dart` | 认证：登录、获取/更新资料、登出、Token 持久化 |
| `ws_service.dart` | WebSocket 管理：连接/断开/发送文本/发送语音，广播 Stream |
| `calendar_service.dart` | 日历：CRUD 调用后端 API |
| `expense_service.dart` | 记账：CRUD + 统计查询 |
| `sync_service.dart` | 数据同步：批量上传事件和记账变更 |
| `audio_recorder_service.dart` | 音频录制封装（record 插件） |
| `asr_local_service.dart` | 本地语音识别预留（whisper.cpp FFI） |
| `tts_player_service.dart` | TTS 音频回放（audioplayers 插件） |

### 3.4 providers/ — 状态管理（5 个 ChangeNotifier）

使用 Provider 模式，每个 Provider 管理一块业务状态：

| 文件 | 管理状态 |
|------|---------|
| `auth_provider.dart` | 用户登录态、当前用户信息、loading/error |
| `chat_provider.dart` | WebSocket 生命周期、消息列表、流式文本、技能调用状态 |
| `character_provider.dart` | 角色配置、已拥有服装/声音、装备切换 |
| `calendar_provider.dart` | 日历事件列表、增删操作 |
| `expense_provider.dart` | 记账记录列表、分类统计、增删操作 |

### 3.5 screens/ — 页面（7 个 Screen）

| 文件 | 路由 | 功能 |
|------|------|------|
| `login_screen.dart` | 未登录首页 | 手机号输入 → 登录 → 新用户弹出起名 → 初始化角色 |
| `home_screen.dart` | 登录后首页 | 底部导航栏 4 Tab：聊天/日历/记账/角色 |
| `chat_screen.dart` | 对话页 | Live2D 区域 + 消息气泡 + 流式显示 + 语音/文字输入 |
| `calendar_screen.dart` | 日历页 | 事件列表 + 添加对话框 + 删除 |
| `expense_screen.dart` | 记账页 | 本月统计栏 + 记录列表（颜色区分收支）+ 长按删除 |
| `character_screen.dart` | 角色页 | 角色名/服装/声音信息 + 已拥有列表 + 一键切换 |
| `shop_screen.dart` | 商店页 | 服装列表 + 声音包列表 + 购买按钮 |

### 3.6 widgets/ — 可复用组件（3 个）

| 文件 | 功能 |
|------|------|
| `chat_bubble.dart` | 聊天气泡：根据 role 左右对齐、变色，流式消息显示动效 |
| `voice_record_button.dart` | 语音按钮：点击变色切换录制状态，带动画效果 |
| `live2d_view.dart` | Live2D 渲染区域（当前为占位符，后续集成 Cubism SDK） |

---

## 四、数据流

### 4.1 对话流程（WebSocket）

```
Flutter App                            FastAPI Backend
    │                                        │
    ├── WS connect(token) ──────────────────►│ JWT 验证
    │                                        │
    ├── {"type":"voice", "audio":"..."} ────►│
    │                                        ├── ASR (Qwen3-ASR-Flash)
    │   ◄── {"type":"asr_result", "text":""}│
    │                                        ├── 意图分类 (LLM)
    │                                        ├── 技能/LLM 聊天
    │   ◄── {"type":"llm_stream", "delta":""} 流式输出
    │                                        ├── TTS 合成
    │   ◄── {"type":"tts_audio", "audio":""}│
    │                                        ├── 保存 Message 到 DB
    │   ◄── {"type":"done", "conv_id":"x"}   │
```

### 4.2 日历/记账流程（REST + 本地优先）

```
Flutter App                      FastAPI              PostgreSQL
    │                               │                     │
    ├── SQLite 本地写入（离线）       │                     │
    ├── 显示本地数据（即时）          │                     │
    │                               │                     │
    ├── POST /api/data/sync ───────►│                     │
    │                               ├── last_write_wins ──┤
    │   ◄── 服务器端变更 ────────── │                     │
    │                               │                     │
    ├── 合并本地 & 服务器数据        │                     │
```

---

## 五、模型路由策略

| 场景 | ASR | LLM | TTS |
|------|-----|-----|-----|
| 正常网络 | Qwen3-ASR-Flash（高精度） | DeepSeek（闲聊）/ Qwen（工具调用） | Qwen3-TTS-Flash（97ms） |
| 离线/弱网 | 端侧 Whisper | 不可用 | 不可用 |
| 角色声音 | — | — | CosyVoice（定制音色） |

---

## 六、扩展点

| 位置 | 扩展方式 |
|------|---------|
| 新技能 | 实现 `BaseSkill`，在 `skill_registry.py` 注册 |
| 新 LLM | 在 `llm_service.py` 添加 Client 实例 |
| 新服装/声音 | 插入 `outfits` / `voice_packs` 表记录 |
| 离线 ASR | 在 `asr_local_service.dart` 集成 whisper.cpp |
| Live2D 渲染 | 替换 `live2d_view.dart` 占位符为 Cubism SDK |
