# 灵犀 AI 虚拟伴侣

## 环境要求

- Python 3.12+
- Docker Desktop（运行 PostgreSQL、Redis、MinIO、SearXNG）
- Flutter 3.22+（移动端开发）
- Xcode（macOS/iOS 运行，含 CocoaPods）

## 快速启动

### 1. 启动基础服务

```bash
# 确认 Docker 已启动，然后：
cd backend

# 启动所有基础服务
docker compose up -d db redis minio searxng

# 检查服务状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "postgres|redis|minio|searxng"
```

| 服务 | 端口 | 说明 |
|------|------|------|
| FastAPI 后端 | 8000 | API + WebSocket |
| PostgreSQL | 5432 | 数据库 |
| Redis | 6379 | 缓存 |
| MinIO API | 9000 | 文件存储 |
| MinIO Console | 9001 | MinIO 管理界面 |
| SearXNG | 8080 | 元搜索引擎（搜索技能必需） |

### 2. 配置环境变量

```bash
cd backend

cat > .env << 'EOF'
DEEPSEEK_API_KEY=sk-xxx
QWEN_API_KEY=sk-xxx
JWT_SECRET=lingxi-dev-jwt-secret-2026
DATABASE_URL=postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi
EOF
```

### 3. 安装依赖 & 数据库迁移

```bash
cd backend

# 安装 Python 依赖
pip install -r requirements.txt

# 运行数据库迁移
alembic upgrade head
```

### 4. 启动后端

```bash
cd backend

# 开发模式（热重载）
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 或后台启动
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/lingxi.log 2>&1 &
```

### 5. 验证后端

```bash
curl http://localhost:8000/health
# → {"status":"ok"}

# 登录测试
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}'
# → {"access_token":"eyJ...", "is_new_user":false}
```

### 6. 启动 Flutter 前端

```bash
cd frontend
flutter pub get

# macOS 桌面（支持录音）
flutter run -d macos

# iOS 模拟器（支持录音，需先装 CocoaPods: sudo gem install cocoapods）
flutter run -d ios

# Android 模拟器（需覆盖 API 地址）
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**注意：Flutter Web（Chrome）不支持录音。** `record` 插件仅支持原生平台（macOS/iOS/Android）。如需语音功能，请用 `flutter run -d macos` 或 `-d ios`。

**默认 API 地址：** `http://localhost:8000`，适用于 macOS 桌面和 iOS 模拟器。Android 模拟器 / iOS 真机需 `--dart-define` 覆盖：
- Android 模拟器：`--dart-define=API_BASE_URL=http://10.0.2.2:8000`
- iOS 真机：`--dart-define=API_BASE_URL=http://<Mac局域网IP>:8000`

## API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 登录/注册（手机号，无密码） |
| POST | `/api/auth/refresh` | 刷新 Token |
| GET | `/api/auth/profile` | 获取个人信息 |
| PUT | `/api/auth/profile` | 修改昵称/头像 |
| POST | `/api/characters/init` | 初始化角色（新用户必须先调用） |
| GET | `/api/characters/config` | 角色配置 |
| PUT | `/api/characters/config` | 修改角色名 |
| GET | `/api/characters/outfits` | 已拥有服装 |
| GET | `/api/characters/voices` | 已拥有声音 |
| PUT | `/api/characters/equip` | 切换装备 |
| GET | `/api/conversations` | 对话列表 |
| GET | `/api/conversations/{id}/messages` | 消息历史 |
| DELETE | `/api/conversations/{id}` | 删除会话 |
| PUT | `/api/conversations/{id}/title` | 修改标题 |
| GET | `/api/shop/outfits` | 服装商店 |
| GET | `/api/shop/voices` | 声音商店 |
| POST | `/api/shop/purchase` | 购买 |
| GET | `/api/calendar/events` | 日历事件 |
| POST | `/api/calendar/events` | 创建事件 |
| PUT | `/api/calendar/events/{id}` | 修改事件 |
| DELETE | `/api/calendar/events/{id}` | 删除事件 |
| GET | `/api/expenses` | 记账列表 |
| POST | `/api/expenses` | 记账 |
| GET | `/api/expenses/stats` | 记账统计 |
| POST | `/api/data/sync` | 数据同步 |
| WS | `/ws/chat?token=xxx` | 实时对话 |

## WebSocket 协议

**客户端发送：**
```json
{"type": "text", "content": "消息内容", "conversation_id": "可选"}
{"type": "voice", "audio": "<base64 wav>", "conversation_id": "可选"}
```

**服务端返回（流式）：**
```json
{"type": "asr_result", "text": "语音识别结果"}
{"type": "skill_call", "skill": "weather", "status": "done"}
{"type": "llm_stream", "delta": "流式回复"}
{"type": "tts_audio", "audio": "<base64>", "text": "语音文本"}
{"type": "done", "conversation_id": "xxx"}
```

## 技能系统

对话时自动识别意图并调用对应技能。技能执行流程均含 LLM 结构化提取：

| 技能 | 触发示例 | 流程 |
|------|---------|------|
| 天气 | "今天天气"、"上海天气" | LLM 提取城市 → wttr.in 查询 → 返回温度/湿度/体感 |
| 搜索 | "搜索 iPhone 17" | LLM 提取关键词 → SearXNG(Google+Bing+百度) → LLM 总结结果 |
| 日历 | "提醒我明天下午3点开会" | LLM 提取标题+时间 → 写入 DB → 后台定时通知 |
| 记账 | "午餐花了50元"、"收了200红包" | LLM 提取金额+类别 → 写入 DB，自动区分收入/支出 |

### 搜索使用说明

搜索依赖 **SearXNG**（已集成到 docker-compose）。内置 `searxng-settings.yml` 启用了百度引擎。

```bash
# 启动 SearXNG
cd backend && docker compose up -d searxng

# 验证
curl "http://localhost:8080/search?q=test&format=json"
```

搜索三步流程：
1. **LLM 提取搜索词** — 去掉"帮我搜一下"等口语前缀
2. **SearXNG 多引擎搜索** — 同时查 Google + Bing + 百度，取 Top 5
3. **LLM 总结** — 把搜索结果总结为 1-2 句简洁回答

## 模型路由

| 用途 | 模型 |
|------|------|
| 闲聊对话 | DeepSeek V4 Flash (`deepseek-v4-flash`) |
| 意图分类 | DeepSeek V4 Flash |
| 技能数据提取 | DeepSeek V4 Flash |
| 工具调用 | Qwen Plus (`qwen-plus`) |
| 语音识别 (ASR) | Qwen3-ASR-Flash |
| 语音合成 (TTS) | Qwen3-TTS-Flash（默认 Cherry 音色） |

角色装备不同 VoicePack 后，TTS 自动切换音色。

## 日历提醒通知

后台每 60 秒轮询一次，到期事件自动标记为已提醒。日志查看：

```bash
tail -f /tmp/lingxi.log | grep NOTIFY
```

## 运行测试

```bash
# 后端
cd backend && python -m pytest tests/ -v

# 前端
cd frontend && flutter analyze
cd frontend && flutter test
```

## 常用日志

```bash
# 后端日志
tail -f /tmp/lingxi.log

# Docker 服务日志
docker compose -f backend/docker-compose.yml logs -f db
docker compose -f backend/docker-compose.yml logs -f searxng
```
