# 灵犀 AI 虚拟伴侣 — 技术设计文档

## 1. 产品概述

一个跨平台 AI 虚拟伴侣 App，包含可换装、可换声的 Live2D 虚拟角色，支持语音对话、信息查询和日常工具（天气、日历提醒、记账）。

### 1.1 MVP 功能范围

| 功能 | 说明 |
|------|------|
| 语音对话 | ASR → LLM → TTS 全链路，支持流式响应 |
| Live2D 角色 | 虚拟角色渲染 + 表情动画 + 口型同步 |
| 网页搜索 | AI Search Agent，多源信息检索 |
| 天气查询 | 当前天气、预报查询 |
| 日历提醒 | 自然语言创建事件/提醒，单向写入系统日历 |
| 记账 | 语音录入，LLM 自动分类，收支统计 |

### 1.2 后续迭代

- 服装/声音商城商业化
- 3D 角色渲染（Unity 集成）
- 微信消息监听与自动回复（iLink Bot API）
- 邮件监听与自动回复
- 打开第三方 App / 电商搜索

---

## 2. 技术栈

| 层 | 选型 | 理由 |
|---|------|------|
| 客户端 | Flutter | 跨平台，动画性能好，后期可集成 Unity 3D |
| 后端 | Python FastAPI | AI 生态最成熟，大模型 SDK 支持最好 |
| 数据库 | PostgreSQL + Redis | 关系存储 + 缓存/会话 |
| 文件存储 | MinIO | 音频文件、Live2D 模型、图片 |
| 大模型 | DeepSeek + Qwen（路由） | 按场景分发，闲聊/工具调用各取所长 |
| ASR | Qwen3-ASR-Flash（主力）+ 端侧 Whisper | 高精度 / 离线兜底 |
| TTS | CosyVoice + Qwen3-TTS-Flash | 角色音色 / 实时低延迟 |

---

## 3. 架构设计

```
┌────────────────── Flutter App ──────────────────┐
│  ┌─ UI 层 ───────────────────────────────────┐  │
│  │  Live2D 渲染 | 对话界面 | 功能卡片        │  │
│  ├─ 端侧引擎 ───────────────────────────────┤  │
│  │  Whisper(ASR) | 音频采集 | VAD | SQLite  │  │
│  └───────────────────────────────────────────┘  │
│              │ WebSocket (长连接)                │
└──────────────┼──────────────────────────────────┘
               │
┌──────────────┼── FastAPI 后端 ──────────────────┐
│  ┌─ API 网关 ────────────────────────────────┐  │
│  │  路由分发 | JWT 鉴权 | 限流                │  │
│  ├─ 对话编排 ───────────────────────────────┤  │
│  │  ASR路由 → LLM路由 → 意图识别 → TTS路由   │  │
│  ├─ 技能插件 ───────────────────────────────┤  │
│  │  搜索 Agent | 天气 | 日历 | 记账          │  │
│  └───────────────────────────────────────────┘  │
│  PostgreSQL | Redis | MinIO                     │
└─────────────────────────────────────────────────┘
```

### 3.1 模型路由策略

- **ASR**：网络正常 → Qwen3-ASR-Flash；无网 → 端侧 Whisper
- **LLM**：闲聊 → DeepSeek；工具调用/复杂推理 → Qwen
- **TTS**：实时对话 → Qwen3-TTS-Flash（97ms）；指定角色音色 → CosyVoice

### 3.2 技能插件机制

```
用户消息 ──▶ LLM 意图识别 ──▶ 分发到对应插件
                  │
      ┌───────────┼───────────┬───────────┐
      ▼           ▼           ▼           ▼
    搜索        天气        日历        记账
```

---

## 4. 数据模型

### 4.1 User（用户表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 用户唯一标识 |
| phone | VARCHAR | 手机号（登录凭证） |
| nickname | VARCHAR | 用户昵称 |
| avatar | VARCHAR | 头像 URL |
| created_at | TIMESTAMP | 注册时间 |

### 4.2 Conversation（对话会话表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 会话唯一标识 |
| user_id | UUID → User.id | 所属用户（一对多） |
| title | VARCHAR | 自动生成的会话标题 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 最后活跃时间（新消息到达时更新，用于排序） |

### 4.3 Message（消息表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 消息唯一标识 |
| conv_id | UUID → Conversation.id | 所属会话（一对多） |
| role | ENUM(user,assistant) | 发送方 |
| type | ENUM(text,voice) | 消息类型 |
| content | TEXT | 文本内容 |
| audio_url | VARCHAR | 语音消息的音频文件 URL |
| created_at | TIMESTAMP | 发送时间 |

### 4.4 Character（角色配置表）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| user_id | UUID → User.id | 所属用户（一对一） |
| name | VARCHAR | 用户给角色起的名字 |
| live2d_model | VARCHAR | 当前 Live2D 模型文件名 |
| outfit_id | UUID → Outfit.id | 当前服装 |
| voice_pack_id | UUID → VoicePack.id | 当前声音包 |

### 4.5 UserInventory（用户背包）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| user_id | UUID → User.id | 所属用户 |
| item_type | ENUM(outfit,voice_pack) | 物品类型 |
| item_id | UUID | 对应的 Outfit.id 或 VoicePack.id |
| equipped | BOOLEAN | 是否当前正在使用，同类型只能一个 |
| purchased_at | TIMESTAMP | 购买时间 |

### 4.6 VoicePack（声音包）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| name | VARCHAR | 声音包名称 |
| type | VARCHAR | 声音标签：女帝/公主/御姐/甜妹等 |
| cosyvoice_id | VARCHAR | CosyVoice 音色 ID |
| price | DECIMAL | 售卖价格，0=免费 |
| preview_url | VARCHAR | 试听音频 URL |

### 4.7 Outfit（服装）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| name | VARCHAR | 服装名称 |
| model_file | VARCHAR | Live2D 模型文件名 |
| thumbnail | VARCHAR | 缩略图 URL |
| price | DECIMAL | 售卖价格，0=免费 |

### 4.8 CalendarEvent（日历事件）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| user_id | UUID → User.id | 所属用户 |
| title | VARCHAR | 事件标题 |
| time | TIMESTAMP | 提醒时间 |
| repeat_rule | VARCHAR | none/daily/weekly/monthly/yearly |
| notified | BOOLEAN | 是否已推送 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 最后修改时间（用于同步冲突解决） |

### 4.9 ExpenseRecord（记账记录）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 唯一标识 |
| user_id | UUID → User.id | 所属用户 |
| amount | DECIMAL | 金额（正=支出，负=收入） |
| category | VARCHAR | 餐饮/交通/购物/娱乐/住房/医疗/教育/其他 |
| remark | VARCHAR | 备注 |
| recorded_at | TIMESTAMP | 实际消费时间 |
| created_at | TIMESTAMP | 记录创建时间 |
| updated_at | TIMESTAMP | 最后修改时间（用于同步冲突解决） |

---

## 5. API 设计

### 5.1 WebSocket（核心对话通道）

```
ws://host/ws/chat?token=xxx
```

**客户端 → 服务端：**

```json
{"type": "voice", "audio": "<base64>", "conversation_id": "C1"}
{"type": "text", "content": "今天好热", "conversation_id": "C1"}
```

**服务端 → 客户端（流式阶段）：**

```json
{"type": "asr_result", "text": "今天好热啊"}
{"type": "llm_stream", "delta": "确实很热，北京今天"}
{"type": "skill_call", "skill": "weather", "status": "fetching"}
{"type": "tts_audio", "audio": "<base64>", "text": "..."}
{"type": "done"}
```

### 5.2 REST API 完整列表

#### Auth

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 登录/注册（短信验证码） |
| POST | `/api/auth/refresh` | 刷新 JWT Token |
| GET | `/api/auth/profile` | 获取用户信息 |
| PUT | `/api/auth/profile` | 修改昵称、头像 |

#### Character

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/characters/init` | 新用户初始化角色（默认服装+声音+起名） |
| GET | `/api/characters/config` | 获取当前角色配置 |
| PUT | `/api/characters/config` | 更新角色名字 |
| GET | `/api/characters/outfits` | 已拥有的服装列表 |
| GET | `/api/characters/voices` | 已拥有的声音包列表 |
| PUT | `/api/characters/equip` | 切换装备（服装或声音） |

```json
// PUT /api/characters/equip
{"item_type": "outfit", "item_id": "OF3"}
// 服务端：校验拥有 → 同类型 equipped 全置 false → 目标置 true → 更新 Character 表关联字段
```

#### Conversation

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/conversations` | 对话列表（分页） |
| GET | `/api/conversations/{id}/messages?cursor=&limit=` | 消息历史（游标分页） |
| DELETE | `/api/conversations/{id}` | 删除会话 |
| PUT | `/api/conversations/{id}/title` | 修改会话标题 |

#### Shop

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/shop/outfits` | 服装商店列表 |
| GET | `/api/shop/voices` | 声音包商店列表 |
| POST | `/api/shop/purchase` | 购买物品 |

#### Calendar

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/calendar/events` | 日历事件列表 |
| POST | `/api/calendar/events` | 创建事件 |
| PUT | `/api/calendar/events/{id}` | 修改事件 |
| DELETE | `/api/calendar/events/{id}` | 删除事件 |

#### Expense

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/expenses` | 记账记录列表（分页，支持按类别/月份筛选） |
| POST | `/api/expenses` | 创建记录 |
| PUT | `/api/expenses/{id}` | 修改记录 |
| DELETE | `/api/expenses/{id}` | 删除记录 |
| GET | `/api/expenses/stats` | 统计（按类别/月份汇总） |

#### Data Sync

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/data/sync` | 日历 + 记账批量同步 |

```json
// 请求
{
  "events": [{"id": "E1", "action": "create|update|delete", "data": {...}}],
  "expenses": [{"id": "X1", "action": "create|update|delete", "data": {...}}],
  "last_sync_at": "2026-05-27T14:00:00Z"
}
// 响应
{
  "server_changes": {"events": [...], "expenses": [...]},
  "sync_at": "2026-05-27T14:05:00Z"
}
```

---

## 6. 搜索设计

MVP 自部署 SearXNG（开源元搜索引擎），LLM 总结 + 引用标注；后期升级为多步 Search Agent。

---

## 7. 日历与记账数据策略

- **日历**：本地 SQLite + 云端 PostgreSQL + 单向写入系统日历（只写不读）
- **记账**：本地 SQLite 为主，后台同步到 PostgreSQL
- **冲突**：`last_write_wins`，不上报冲突让用户手动解决
