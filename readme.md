# 灵犀 AI 虚拟伴侣

## 环境要求

- Python 3.12+
- Docker Desktop（运行 PostgreSQL、Redis、MinIO）
- Flutter 3.22+（移动端开发）

## 快速启动

### 1. 启动基础服务（PostgreSQL / Redis / MinIO）

```bash
# 确认 Docker 已启动，然后：
cd backend

# 启动数据库和缓存服务
docker compose up -d db redis minio

# 检查服务状态
docker ps | grep -E "postgres|redis|minio"
```

MinIO 控制台：http://localhost:9001 （账号密码：minioadmin / minioadmin）

### 2. 配置环境变量

```bash
cd backend

# 创建 .env 文件（已配置好，重新配置可编辑）
cat > .env << 'EOF'
DEEPSEEK_API_KEY=sk-c4a189a549e6460898bfc2b3198ad812
QWEN_API_KEY=sk-0060a0b228914a95a2f3dc316dc3095a
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

# 登录测试
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

### 6. 启动 Flutter 前端（可选）

```bash
cd frontend

# 安装依赖
flutter pub get

# 代码检查
flutter analyze

# 在模拟器上运行
flutter run
```

## API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/login` | 登录/注册 |
| POST | `/api/auth/refresh` | 刷新 Token |
| GET | `/api/auth/profile` | 获取个人信息 |
| PUT | `/api/auth/profile` | 修改昵称/头像 |
| POST | `/api/characters/init` | 初始化角色 |
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

## 运行测试

```bash
# 后端测试
cd backend && python -m pytest tests/ -v

# 前端测试
cd frontend && flutter test

# 前端代码检查
cd frontend && flutter analyze
```

## 开发端口

| 服务 | 端口 |
|------|------|
| FastAPI 后端 | 8000 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| MinIO API | 9000 |
| MinIO Console | 9001 |

## 常用日志查看

```bash
# 后端日志
tail -f /tmp/lingxi.log

# Docker 服务日志
docker compose logs -f db
docker compose logs -f redis
```
