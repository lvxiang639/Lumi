# 灵犀 AI 虚拟伴侣

## 环境要求

- Python 3.12+
- Docker Desktop（运行 PostgreSQL、Redis、MinIO、SearXNG）
- Flutter 3.22+（移动端开发）

## 快速启动

### 1. 启动基础服务

```bash
# 确认 Docker 已启动，然后：
cd backend

# 启动所有基础服务（数据库 / 缓存 / 文件存储 / 搜索引擎）
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
| SearXNG | 8080 | 元搜索引擎（搜索技能依赖） |

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

### 4. 启动后端服务

```bash
cd backend

# 开发模式启动（热重载）
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# 或者后台启动
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/lingxi.log 2>&1 &
```

### 5. 验证服务

```bash
# 健康检查
curl http://localhost:8000/health
# → {"status":"ok"}

# 登录测试（自动注册新用户）
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"phone":"13800138000"}'
# → {"access_token":"eyJ...", "token_type":"bearer", "is_new_user":true}

# WebSocket 对话测试
python3 -c "
import asyncio, json
import httpx
from httpx_ws import aconnect_ws

async def test():
    async with httpx.AsyncClient() as c:
        r = await c.post('http://localhost:8000/api/auth/login', json={'phone':'13800138000'})
        token = r.json()['access_token']
        async with aconnect_ws(f'http://localhost:8000/ws/chat?token={token}', c) as ws:
            await ws.send_text(json.dumps({'type':'text','content':'你好'}))
            while True:
                m = json.loads(await ws.receive_text())
                if m['type'] == 'llm_stream': print(m['delta'], end='')
                elif m['type'] == 'done': break

asyncio.run(test())
"
```

### 6. 启动 Flutter 前端

```bash
cd frontend

# 安装依赖
flutter pub get

# 代码检查
flutter analyze

# macOS 桌面运行
flutter run -d macos

# iOS 模拟器运行
flutter run -d ios

# Android 模拟器运行（需指定地址，因为 10.0.2.2 是模拟器访问宿主机的别名）
flutter run -d android \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

**默认 API 地址：** `http://localhost:8000`，适用于 macOS 桌面和 iOS 模拟器（它们与宿主机共享网络栈）。Android 模拟器 / iOS 真机需用 `--dart-define` 覆盖：
- Android 模拟器：`--dart-define=API_BASE_URL=http://10.0.2.2:8000`
- iOS 真机：`--dart-define=API_BASE_URL=http://<Mac局域网IP>:8000`

## API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 登录/注册（手机号，无密码） |
| POST | `/api/auth/refresh` | 刷新 Token |
| GET | `/api/auth/profile` | 获取个人信息 |
| PUT | `/api/auth/profile` | 修改昵称/头像 |
| POST | `/api/characters/init` | 初始化角色（新用户必须调用） |
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
{"type": "voice", "audio": "<base64>", "conversation_id": "可选"}
```

**服务端返回（流式）：**
```json
{"type": "asr_result", "text": "语音识别结果"}
{"type": "llm_stream", "delta": "流式回复"}
{"type": "skill_call", "skill": "weather", "status": "done"}
{"type": "tts_audio", "audio": "<base64>", "text": "语音文本"}
{"type": "done", "conversation_id": "xxx"}
```

## 技能系统

对话时系统自动识别意图并调用对应技能，无需手动切换。

| 技能 | 触发示例 | 功能 |
|------|---------|------|
| 天气 | "今天天气怎么样"、"上海天气" | LLM 提取城市 → wttr.in 查询 |
| 搜索 | "搜索一下iPhone 17"、"查一下..." | SearXNG 元搜索引擎 → 返回 Top 5 结果 |
| 日历 | "提醒我明天下午3点开会" | LLM 提取标题+时间 → 写入数据库 → 后台定时提醒 |
| 记账 | "午餐花了50元"、"收了200红包" | LLM 提取金额+类别 → 写入数据库 |

### 搜索使用说明

搜索功能依赖 **SearXNG**（自部署的开源元搜索引擎），默认同时搜索 Google 和 Bing。

```bash
# 启动 SearXNG
cd backend && docker compose up -d searxng

# 验证 SearXNG 运行
curl http://localhost:8080/search?q=test&format=json
```

在 App 对话中说"搜索"开头的语句即可触发，例如：
- "帮我搜索一下今天天气"（注意：这会触发 search 技能而非 weather，取决于 LLM 意图分类）
- "搜索 iPhone 17 最新消息"
- "查一下附近的餐厅"

## 日历提醒

日历事件创建后，后台每 60 秒检查一次到期事件并自动标记为"已提醒"。日志中可见提醒记录：
```bash
tail -f /tmp/lingxi.log | grep NOTIFY
```

## 角色声音切换

角色装备不同的 VoicePack 后，TTS 自动使用对应音色。数据库默认种子数据包含"默认女声"（Cherry 音色）。切换方式：
```bash
# 查看已拥有的声音
curl http://localhost:8000/api/characters/voices \
  -H "Authorization: Bearer <token>"

# 切换到指定声音
curl -X PUT http://localhost:8000/api/characters/equip \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"item_type":"voice_pack","item_id":"<voice_pack_id>"}'
```

## 运行测试

```bash
# 后端测试
cd backend && python -m pytest tests/ -v

# 前端测试
cd frontend && flutter test

# 前端代码检查
cd frontend && flutter analyze
```

## 常用日志查看

```bash
# 后端日志
tail -f /tmp/lingxi.log

# Docker 服务日志
docker compose -f backend/docker-compose.yml logs -f db
docker compose -f backend/docker-compose.yml logs -f searxng
```
