# 灵犀重构设计：对话列表 + 纯文本 + 对话级记忆

> 日期：2026-06-06 | 状态：设计阶段

## 目标

将灵犀从"单一聊天页面"重构为"微信式对话列表"应用：
- 用户可以创建多个对话，在历史对话中继续聊天
- 每个对话自动生成标题，支持手动重命名
- 全局记忆 + 对话级记忆并存
- 所有工具（搜索、邮件、日历等）在任何对话中均可触发
- 语音功能（TTS/ASR）注释掉，纯文本交流
- 角色宠物保留简化版（静态展示 + 表情变化）

## 一、前端变化

### 1.1 页面结构

```
LoginScreen → ConversationListScreen → ChatScreen
```

| 页面 | 状态 | 说明 |
|------|------|------|
| `LoginScreen` | 不变 | 登录页 |
| `ConversationListScreen` | **新增** | 对话列表，微信风格 |
| `ChatScreen` | **重构** | 接收 conversationId，加载历史 |
| `HomeScreen` | **删除** | 不再需要，直接进列表页 |

### 1.2 ConversationListScreen（对话列表页）

**布局：**
```
┌─────────────────────────────────┐
│  灵犀                    角色按钮 │  ← AppBar
├─────────────────────────────────┤
│  ┌─────────────────────────────┐│
│  │ 🐱 旅游计划                ││  ← 对话卡片
│  │    上次聊到去日本... 3分钟前││
│  └─────────────────────────────┘│
│  ┌─────────────────────────────┐│
│  │ 🌤 今天天气怎么样           ││
│  │    北京今天晴...    1小时前 ││
│  └─────────────────────────────┘│
│  ...                            │
│                                 │
│                        ┌──────┐ │
│                        │  ✏️  │ │  ← FAB 新建对话
│                        └──────┘ │
└─────────────────────────────────┘
```

**功能：**
- 显示当前用户的所有对话，按 `updated_at` 倒序
- 每个卡片显示：标题、最后一条消息预览、时间
- 点击卡片 → 进入 `ChatScreen(conversationId)`
- 长按卡片 → 弹出菜单（重命名 / 删除）
- 右下角 FAB → 新建对话 → 进入空白 `ChatScreen`
- 下拉刷新

### 1.3 ChatScreen（聊天页重构）

**变化：**
- 接收 `conversationId` 参数（可选，新建时为空）
- 进入时加载历史消息（通过 REST API `GET /api/conversations/{id}/messages`）
- 首次发送消息时创建新对话（后端已有 `_get_or_create_conv` 逻辑）
- AppBar 显示对话标题，左侧返回按钮回到列表
- 工具面板（ToolsPanel）保持不变，可在任何对话中打开
- 角色宠物保留在右下角，去掉嘴部动画，保留表情变化
- 语音按钮注释掉

### 1.4 文件变更清单（前端）

| 文件 | 操作 | 说明 |
|------|------|------|
| `screens/conversation_list_screen.dart` | **新建** | 对话列表页 |
| `screens/chat_screen.dart` | **重构** | 接收 convId，加载历史，去掉语音 |
| `screens/home_screen.dart` | **删除** | 不再需要 |
| `app.dart` | **修改** | 路由改为 ConversationListScreen |
| `providers/chat_provider.dart` | **重构** | 支持加载历史消息，去掉 TTS 相关 |
| `widgets/voice_record_button.dart` | **注释** | 语音按钮组件注释掉 |
| `services/tts_player_service.dart` | **注释** | TTS 播放服务注释掉 |
| `services/asr_local_service.dart` | **注释** | 本地 ASR 服务注释掉 |
| `services/audio_recorder_service.dart` | **注释** | 录音服务注释掉 |
| `services/ws_service.dart` | **修改** | 去掉 voice 消息类型 |
| `widgets/character_webview.dart` | **修改** | 简化版，去掉 mouthOpen 动画 |
| `widgets/chat_bubble.dart` | 不变 | 聊天气泡保持不变 |
| `widgets/tools_panel.dart` | 不变 | 工具面板保持不变 |
| `widgets/sci_fi_bg.dart` | 不变 | 背景保持不变 |

## 二、后端变化

### 2.1 TTS/ASR 注释掉

| 文件 | 改动 |
|------|------|
| `services/chat_orchestrator.py` | 注释掉步骤 7（TTS 合成），注释掉 `process_voice` 方法 |
| `services/tts_service.py` | 整个文件内容注释掉，保留接口定义 |
| `services/asr_service.py` | 整个文件内容注释掉，保留接口定义 |
| `api/ws_chat.py` | 注释掉 `voice` 消息类型处理 |

### 2.2 对话级记忆

当前 `UserMemory` 表结构：
```sql
user_memories: id, user_id, key, value, source_conv_id, created_at, updated_at
```

**变化：** 新增 `conv_memories` 表，存储对话级记忆。

```sql
conv_memories: id, user_id, conv_id, summary_text, created_at, updated_at
```

**记忆提取逻辑：**
- 每次对话完成后，LLM 提取对话关键信息
- 对话级记忆：存入 `conv_memories`（该对话的摘要）
- 全局记忆：存入 `user_memories`（跨对话的用户画像）
- 下次进入同一对话时，加载该对话的 `conv_memories` 作为上下文
- 全局记忆仍然注入所有对话的 system prompt

### 2.3 新增 API

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/conversations` | 已有，对话列表 |
| GET | `/api/conversations/{id}/messages` | 已有，消息历史 |
| PUT | `/api/conversations/{id}/title` | 已有，重命名 |
| DELETE | `/api/conversations/{id}` | 已有，删除对话 |
| GET | `/api/conversations/{id}/memory` | **新增**，获取对话级记忆 |

### 2.4 文件变更清单（后端）

| 文件 | 操作 | 说明 |
|------|------|------|
| `services/chat_orchestrator.py` | **修改** | 注释 TTS，简化流程 |
| `services/tts_service.py` | **注释** | 保留代码，注释掉 |
| `services/asr_service.py` | **注释** | 保留代码，注释掉 |
| `api/ws_chat.py` | **修改** | 注释 voice 处理 |
| `services/memory_service.py` | **扩展** | 新增对话级记忆 |
| `domain/chat/models.py` | **新增** | ConvMemory 模型 |
| `api/conversations.py` | **新增** | 对话记忆 API |

## 三、数据流

### 3.1 新建对话流程

```
用户在列表页点击 ✏️
  → 进入 ChatScreen(conversationId: null)
  → 用户输入第一条消息
  → WS 发送 {type: "text", content: "...", conversation_id: null}
  → 后端 _get_or_create_conv() 创建新对话
  → 标题 = 首条消息前 30 字
  → 返回 {type: "done", conversation_id: "xxx"}
  → 前端保存 conversationId，加入列表
```

### 3.2 继续历史对话流程

```
用户在列表页点击某个对话
  → 进入 ChatScreen(conversationId: "xxx")
  → REST API 加载历史消息
  → WS 连接，发送后续消息带 conversation_id
  → 后端加载对话级记忆 + 全局记忆
  → 注入 system prompt
  → LLM 回复
```

### 3.3 工具触发流程（不变）

```
任何对话中
  → 用户输入 "搜索xxx" / "今天天气" / "记账100"
  → 意图分类 → 匹配 skill
  → skill 执行 → 返回结果
  → 保存到当前对话
```

## 四、数据库变更

### 新增表：`conv_memories`

```sql
CREATE TABLE conv_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    conv_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_conv_memories_conv ON conv_memories(conv_id);
```

### 新增 Migration

在 `backend/alembic/versions/` 下新增一个 migration 文件。

## 五、注释策略（语音相关）

**原则：** 代码保留，用注释包裹，不删除。

```python
# ============================================================
# VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
# ============================================================
# ... 原有代码 ...
# ============================================================
```

```dart
// ============================================================
// VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
// ============================================================
// ... 原有代码 ...
// ============================================================
```

## 六、实现顺序

1. **后端修改**：注释 TTS/ASR，新增对话记忆
2. **数据库 Migration**：新增 conv_memories 表
3. **前端重构**：ConversationListScreen + ChatScreen 改造
4. **前端清理**：注释语音相关代码
5. **测试验证**：端到端流程测试