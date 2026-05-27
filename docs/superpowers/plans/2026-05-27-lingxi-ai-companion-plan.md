# 灵犀 AI 虚拟伴侣 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform AI companion app with Live2D virtual character, voice chat, and daily tools (search, weather, calendar, expense tracking).

**Architecture:** Flutter frontend communicates with FastAPI backend via WebSocket (chat) and REST (CRUD). Backend orchestrates ASR → LLM → TTS pipeline with model routing, dispatches to plugin-based skill system for tools, and persists data in PostgreSQL with Redis caching and MinIO for files.

**Tech Stack:** Flutter 3.x, FastAPI, PostgreSQL, Redis, MinIO, DeepSeek/Qwen APIs, Qwen3-ASR-Flash, CosyVoice/Qwen3-TTS-Flash, whisper.cpp, Cubism SDK for Native

---

## File Structure

```
lingxi/
├── backend/
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── alembic.ini
│   ├── alembic/
│   │   └── env.py
│   │   └── versions/
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py                  # FastAPI app, CORS, router mounts
│   │   ├── config.py                # Settings from env vars
│   │   ├── database.py              # SQLAlchemy engine + session
│   │   ├── models/
│   │   │   ├── __init__.py          # re-export all models
│   │   │   ├── user.py
│   │   │   ├── conversation.py
│   │   │   ├── message.py
│   │   │   ├── character.py
│   │   │   ├── inventory.py
│   │   │   ├── voice_pack.py
│   │   │   ├── outfit.py
│   │   │   ├── calendar_event.py
│   │   │   └── expense_record.py
│   │   ├── schemas/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py
│   │   │   ├── user.py
│   │   │   ├── conversation.py
│   │   │   ├── character.py
│   │   │   ├── shop.py
│   │   │   ├── calendar.py
│   │   │   ├── expense.py
│   │   │   └── sync.py
│   │   ├── api/
│   │   │   ├── __init__.py
│   │   │   ├── deps.py             # get_current_user, get_db
│   │   │   ├── auth.py
│   │   │   ├── conversations.py
│   │   │   ├── characters.py
│   │   │   ├── shop.py
│   │   │   ├── calendar.py
│   │   │   ├── expenses.py
│   │   │   ├── sync.py
│   │   │   └── ws_chat.py
│   │   ├── services/
│   │   │   ├── __init__.py
│   │   │   ├── asr_service.py       # Qwen3-ASR-Flash wrapper
│   │   │   ├── llm_service.py       # DeepSeek + Qwen router
│   │   │   ├── tts_service.py       # CosyVoice + Qwen3-TTS-Flash
│   │   │   ├── skill_registry.py    # Plugin dispatch
│   │   │   ├── skills/
│   │   │   │   ├── __init__.py
│   │   │   │   ├── base.py          # Abstract Skill
│   │   │   │   ├── search.py
│   │   │   │   ├── weather.py
│   │   │   │   ├── calendar_skill.py
│   │   │   │   └── expense_skill.py
│   │   │   └── chat_orchestrator.py # ASR → intent → LLM → skill → TTS
│   │   └── core/
│   │       ├── __init__.py
│   │       ├── security.py          # JWT encode/decode, password hashing
│   │       └── storage.py           # MinIO client wrapper
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py
│       ├── test_auth.py
│       ├── test_conversations.py
│       ├── test_characters.py
│       ├── test_calendar.py
│       ├── test_expenses.py
│       ├── test_sync.py
│       └── test_ws_chat.py
│
├── frontend/
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── config.dart
│   │   ├── models/
│   │   │   ├── user.dart
│   │   │   ├── conversation.dart
│   │   │   ├── message.dart
│   │   │   ├── character_config.dart
│   │   │   ├── inventory_item.dart
│   │   │   ├── voice_pack.dart
│   │   │   ├── outfit.dart
│   │   │   ├── calendar_event.dart
│   │   │   └── expense_record.dart
│   │   ├── services/
│   │   │   ├── api_client.dart
│   │   │   ├── auth_service.dart
│   │   │   ├── ws_service.dart
│   │   │   ├── audio_recorder_service.dart
│   │   │   ├── asr_local_service.dart
│   │   │   ├── tts_player_service.dart
│   │   │   ├── calendar_service.dart
│   │   │   ├── expense_service.dart
│   │   │   └── sync_service.dart
│   │   ├── providers/
│   │   │   ├── auth_provider.dart
│   │   │   ├── chat_provider.dart
│   │   │   ├── character_provider.dart
│   │   │   ├── calendar_provider.dart
│   │   │   └── expense_provider.dart
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── character_screen.dart
│   │   │   ├── calendar_screen.dart
│   │   │   ├── expense_screen.dart
│   │   │   └── shop_screen.dart
│   │   └── widgets/
│   │       ├── live2d_view.dart
│   │       ├── chat_bubble.dart
│   │       └── voice_record_button.dart
│   └── test/
│       ├── services/
│       │   ├── auth_service_test.dart
│       │   ├── ws_service_test.dart
│       │   ├── calendar_service_test.dart
│       │   └── expense_service_test.dart
│       └── providers/
│           ├── auth_provider_test.dart
│           ├── chat_provider_test.dart
│           └── expense_provider_test.dart
│
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-27-lingxi-ai-companion-design.md
```

---

## Phase 1: Project Scaffolding & Infrastructure

### Task 1: Backend project setup with Docker Compose

**Files:**
- Create: `backend/requirements.txt`
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.yml`
- Create: `backend/app/__init__.py`
- Create: `backend/app/main.py`
- Create: `backend/app/config.py`
- Create: `backend/app/database.py`

- [ ] **Step 1: Create requirements.txt**

```txt
fastapi==0.115.0
uvicorn[standard]==0.30.0
sqlalchemy==2.0.35
asyncpg==0.29.0
alembic==1.13.0
pydantic==2.9.0
pydantic-settings==2.5.0
redis==5.0.0
minio==7.2.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
httpx==0.27.0
openai==1.50.0
websockets==13.0
python-multipart==0.0.9
pytest==8.3.0
pytest-asyncio==0.24.0
httpx-ws==0.6.0
```

- [ ] **Step 2: Create Dockerfile**

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

- [ ] **Step 3: Create docker-compose.yml**

```yaml
version: "3.9"
services:
  api:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgresql+asyncpg://lingxi:lingxi@db:5432/lingxi
      - REDIS_URL=redis://redis:6379/0
      - MINIO_ENDPOINT=minio:9000
      - JWT_SECRET=dev-secret-change-in-production
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
      - QWEN_API_KEY=${QWEN_API_KEY}
    depends_on:
      - db
      - redis
      - minio

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: lingxi
      POSTGRES_PASSWORD: lingxi
      POSTGRES_DB: lingxi
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - miniodata:/data

volumes:
  pgdata:
  miniodata:
```

- [ ] **Step 4: Create app/config.py**

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi"
    redis_url: str = "redis://localhost:6379/0"
    minio_endpoint: str = "localhost:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket: str = "lingxi"
    jwt_secret: str = "zq/JgecQhnwoKx8yAihHON4PS6kPmAA0VNUTOLjBW+ipeEZP7FJMsmD/j8vRK81fKpivSd+f7AePD1vTUPg1zw=="
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 7
    deepseek_api_key: str = ""
    deepseek_base_url: str = "https://api.deepseek.com/v1"
    qwen_api_key: str = ""
    qwen_base_url: str = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    asr_api_url: str = "https://dashscope.aliyuncs.com/api/v1/services/audio/asr/asr"
    tts_api_url: str = "https://dashscope.aliyuncs.com/api/v1/services/audio/tts/tts"
    cosyvoice_endpoint: str = ""

    model_config = {"env_file": ".env"}

settings = Settings()
```

- [ ] **Step 5: Create app/database.py**

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

engine = create_async_engine(settings.database_url, echo=False)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

class Base(DeclarativeBase):
    pass

async def get_db() -> AsyncSession:
    async with async_session() as session:
        yield session
```

- [ ] **Step 6: Create app/main.py**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="灵犀 API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health():
    return {"status": "ok"}
```

- [ ] **Step 7: Run and verify**

```bash
cd backend && docker compose up -d db redis minio
sleep 5
pip install -r requirements.txt
uvicorn app.main:app --reload &
sleep 2
curl http://localhost:8000/health
```
Expected: `{"status":"ok"}`

- [ ] **Step 8: Commit**

```bash
git add backend/
git commit -m "feat: backend project scaffolding with Docker Compose"
```

---

### Task 2: Frontend project setup

**Files:**
- Create: `frontend/pubspec.yaml`
- Create: `frontend/analysis_options.yaml`
- Create: `frontend/lib/main.dart`
- Create: `frontend/lib/app.dart`
- Create: `frontend/lib/config.dart`

- [ ] **Step 1: Create Flutter project**

```bash
flutter create --org com.lingxi --project-name lingxi frontend --platforms android,ios
```

- [ ] **Step 2: Update frontend/pubspec.yaml dependencies**

```yaml
name: lingxi
description: 灵犀 AI 虚拟伴侣
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.4.0 <4.0.0"
  flutter: ">=3.22.0"

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.0
  web_socket_channel: ^3.0.0
  web_socket_link: ^1.0.1
  http: ^1.2.0
  json_annotation: ^4.9.0
  shared_preferences: ^2.3.0
  sqflite: ^2.4.0
  path: ^1.9.0
  path_provider: ^2.1.0
  record: ^5.1.0
  audioplayers: ^6.1.0
  intl: ^0.19.0
  flutter_local_notifications: ^18.0.0
  device_calendar: ^4.3.0
  permission_handler: ^11.3.0
  uuid: ^4.5.0
  freezed_annotation: ^2.4.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
  freezed: ^2.5.0
  mockito: ^5.4.0
  mocktail: ^1.0.0
```

- [ ] **Step 3: Create frontend/lib/config.dart**

```dart
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:8000',
  );
}
```

- [ ] **Step 4: Create frontend/lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class LingxiApp extends StatelessWidget {
  const LingxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: '灵犀',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isAuthenticated) return const HomeScreen();
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create frontend/lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LingxiApp());
}
```

- [ ] **Step 6: Verify project builds**

```bash
cd frontend && flutter pub get && flutter analyze
```
Expected: No errors.

- [ ] **Step 7: Commit**

```bash
git add frontend/
git commit -m "feat: Flutter project scaffolding with dependencies"
```

---

## Phase 2: Backend Data Models & Core Auth

### Task 3: SQLAlchemy models

**Files:**
- Create: `backend/app/models/__init__.py`
- Create: `backend/app/models/user.py`
- Create: `backend/app/models/conversation.py`
- Create: `backend/app/models/message.py`
- Create: `backend/app/models/character.py`
- Create: `backend/app/models/inventory.py`
- Create: `backend/app/models/voice_pack.py`
- Create: `backend/app/models/outfit.py`
- Create: `backend/app/models/calendar_event.py`
- Create: `backend/app/models/expense_record.py`

- [ ] **Step 1: Create app/models/user.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True, nullable=False)
    nickname: Mapped[str] = mapped_column(String(50), default="")
    avatar: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversations = relationship("Conversation", back_populates="user", cascade="all, delete-orphan")
    character = relationship("Character", back_populates="user", uselist=False, cascade="all, delete-orphan")
    inventory = relationship("UserInventory", back_populates="user", cascade="all, delete-orphan")
    calendar_events = relationship("CalendarEvent", back_populates="user", cascade="all, delete-orphan")
    expenses = relationship("ExpenseRecord", back_populates="user", cascade="all, delete-orphan")
```

- [ ] **Step 2: Create app/models/conversation.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Conversation(Base):
    __tablename__ = "conversations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(200), default="新对话")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="conversations")
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan", order_by="Message.created_at")
```

- [ ] **Step 3: Create app/models/message.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, Enum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
import enum

class MessageRole(str, enum.Enum):
    user = "user"
    assistant = "assistant"

class MessageType(str, enum.Enum):
    text = "text"
    voice = "voice"

class Message(Base):
    __tablename__ = "messages"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    conv_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("conversations.id"), nullable=False)
    role: Mapped[MessageRole] = mapped_column(Enum(MessageRole), nullable=False)
    type: Mapped[MessageType] = mapped_column(Enum(MessageType), nullable=False)
    content: Mapped[str] = mapped_column(Text, default="")
    audio_url: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")
```

- [ ] **Step 4: Create app/models/outfit.py**

```python
import uuid
from sqlalchemy import String, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class Outfit(Base):
    __tablename__ = "outfits"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    model_file: Mapped[str] = mapped_column(String(300), nullable=False)
    thumbnail: Mapped[str] = mapped_column(String(500), default="")
    price: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
```

- [ ] **Step 5: Create app/models/voice_pack.py**

```python
import uuid
from sqlalchemy import String, Numeric
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class VoicePack(Base):
    __tablename__ = "voice_packs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    type: Mapped[str] = mapped_column(String(50), nullable=False)
    cosyvoice_id: Mapped[str] = mapped_column(String(100), nullable=False)
    price: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    preview_url: Mapped[str] = mapped_column(String(500), default="")
```

- [ ] **Step 6: Create app/models/character.py**

```python
import uuid
from sqlalchemy import String, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Character(Base):
    __tablename__ = "characters"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(50), default="小灵")
    live2d_model: Mapped[str] = mapped_column(String(300), default="default.model3.json")
    outfit_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("outfits.id"), nullable=True)
    voice_pack_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("voice_packs.id"), nullable=True)

    user = relationship("User", back_populates="character")
    outfit = relationship("Outfit")
    voice_pack = relationship("VoicePack")
```

- [ ] **Step 7: Create app/models/inventory.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Enum, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
import enum

class ItemType(str, enum.Enum):
    outfit = "outfit"
    voice_pack = "voice_pack"

class UserInventory(Base):
    __tablename__ = "user_inventory"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    item_type: Mapped[ItemType] = mapped_column(Enum(ItemType), nullable=False)
    item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    equipped: Mapped[bool] = mapped_column(Boolean, default=False)
    purchased_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="inventory")
```

- [ ] **Step 8: Create app/models/calendar_event.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, Boolean, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class CalendarEvent(Base):
    __tablename__ = "calendar_events"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    repeat_rule: Mapped[str] = mapped_column(String(20), default="none")
    notified: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="calendar_events")
```

- [ ] **Step 9: Create app/models/expense_record.py**

```python
import uuid
from datetime import datetime
from sqlalchemy import String, Numeric, DateTime, ForeignKey, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class ExpenseRecord(Base):
    __tablename__ = "expense_records"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    amount: Mapped[float] = mapped_column(Numeric(12, 2), nullable=False)
    category: Mapped[str] = mapped_column(String(20), default="其他")
    remark: Mapped[str] = mapped_column(String(500), default="")
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="expenses")
```

- [ ] **Step 10: Create app/models/__init__.py**

```python
from app.models.user import User
from app.models.conversation import Conversation
from app.models.message import Message, MessageRole, MessageType
from app.models.character import Character
from app.models.inventory import UserInventory, ItemType
from app.models.voice_pack import VoicePack
from app.models.outfit import Outfit
from app.models.calendar_event import CalendarEvent
from app.models.expense_record import ExpenseRecord
from app.database import Base

__all__ = [
    "Base", "User", "Conversation", "Message", "MessageRole", "MessageType",
    "Character", "UserInventory", "ItemType", "VoicePack", "Outfit",
    "CalendarEvent", "ExpenseRecord",
]
```

- [ ] **Step 11: Commit**

```bash
git add backend/app/models/
git commit -m "feat: add all SQLAlchemy models"
```

---

### Task 4: Alembic migration setup and core security

**Files:**
- Create: `backend/alembic.ini`
- Create: `backend/alembic/env.py`
- Create: `backend/app/core/__init__.py`
- Create: `backend/app/core/security.py`
- Create: `backend/app/api/__init__.py`
- Create: `backend/app/api/deps.py`

- [ ] **Step 1: Initialize Alembic**

```bash
cd backend && alembic init alembic
```

- [ ] **Step 2: Update backend/alembic/env.py for async**

```python
import asyncio
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config
from alembic import context

from app.config import settings
from app.models import Base

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()

def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)
    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()

def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

- [ ] **Step 3: Create app/core/security.py**

```python
from datetime import datetime, timedelta, timezone
from jose import JWTError, jwt
from passlib.context import CryptContext
from app.config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=settings.jwt_expire_minutes))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.jwt_secret, algorithm=settings.jwt_algorithm)

def decode_access_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError:
        return None
```

- [ ] **Step 4: Create app/api/deps.py**

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.core.security import decode_access_token
from app.models import User

security_scheme = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
```

- [ ] **Step 5: Generate initial migration and apply**

```bash
cd backend
export DATABASE_URL="postgresql+asyncpg://lingxi:lingxi@localhost:5432/lingxi"
alembic revision --autogenerate -m "init"
alembic upgrade head
```

Expected: All 9 tables created in PostgreSQL.

- [ ] **Step 6: Commit**

```bash
git add backend/alembic.ini backend/alembic/ backend/app/core/ backend/app/api/deps.py
git commit -m "feat: Alembic setup, JWT security, and auth dependency"
```

---

### Task 5: Auth schemas and API

**Files:**
- Create: `backend/app/schemas/__init__.py`
- Create: `backend/app/schemas/auth.py`
- Create: `backend/app/api/auth.py`

- [ ] **Step 1: Create app/schemas/auth.py**

```python
from pydantic import BaseModel, Field

class LoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    is_new_user: bool = False

class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserProfile(BaseModel):
    id: str
    phone: str
    nickname: str
    avatar: str

class UpdateProfileRequest(BaseModel):
    nickname: str | None = None
    avatar: str | None = None
```

- [ ] **Step 2: Create app/api/auth.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User
from app.schemas.auth import LoginRequest, LoginResponse, RefreshResponse, UserProfile, UpdateProfileRequest
from app.core.security import create_access_token, decode_access_token
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/login", response_model=LoginResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()
    is_new = False
    if user is None:
        user = User(phone=req.phone, nickname=f"用户{req.phone[-4:]}")
        db.add(user)
        await db.commit()
        await db.refresh(user)
        is_new = True
    token = create_access_token({"sub": str(user.id)})
    return LoginResponse(access_token=token, is_new_user=is_new)

@router.post("/refresh", response_model=RefreshResponse)
async def refresh_token(current_user: User = Depends(get_current_user)):
    token = create_access_token({"sub": str(current_user.id)})
    return RefreshResponse(access_token=token)

@router.get("/profile", response_model=UserProfile)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserProfile(id=str(current_user.id), phone=current_user.phone, nickname=current_user.nickname, avatar=current_user.avatar)

@router.put("/profile", response_model=UserProfile)
async def update_profile(req: UpdateProfileRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if req.nickname is not None:
        current_user.nickname = req.nickname
    if req.avatar is not None:
        current_user.avatar = req.avatar
    await db.commit()
    await db.refresh(current_user)
    return UserProfile(id=str(current_user.id), phone=current_user.phone, nickname=current_user.nickname, avatar=current_user.avatar)
```

- [ ] **Step 3: Register router in app/main.py — edit main.py**

Update `backend/app/main.py` to include:

```python
from app.api.auth import router as auth_router
app.include_router(auth_router)
```

- [ ] **Step 4: Write test**

Create `backend/tests/test_auth.py`:

```python
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

@pytest.mark.asyncio
async def test_login_new_user():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.post("/api/auth/login", json={"phone": "13800138001"})
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert data["is_new_user"] is True

@pytest.mark.asyncio
async def test_login_existing_user():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        await client.post("/api/auth/login", json={"phone": "13800138002"})
        resp = await client.post("/api/auth/login", json={"phone": "13800138002"})
        assert resp.status_code == 200
        assert resp.json()["is_new_user"] is False
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_auth.py -v
```
Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas/ backend/app/api/auth.py backend/app/main.py backend/tests/
git commit -m "feat: auth schemas and login/refresh/profile API"
```

---

### Task 6: Character API

**Files:**
- Create: `backend/app/schemas/character.py`
- Create: `backend/app/api/characters.py`

- [ ] **Step 1: Create app/schemas/character.py**

```python
from pydantic import BaseModel

class CharacterConfig(BaseModel):
    id: str
    name: str
    live2d_model: str
    outfit_id: str | None
    voice_pack_id: str | None
    outfit_name: str | None
    voice_pack_name: str | None

class InitCharacterRequest(BaseModel):
    name: str

class UpdateCharacterRequest(BaseModel):
    name: str | None = None

class EquipRequest(BaseModel):
    item_type: str  # "outfit" or "voice_pack"
    item_id: str

class InventoryItem(BaseModel):
    id: str
    item_type: str
    item_id: str
    item_name: str
    equipped: bool
    purchased_at: str

class OutfitItem(BaseModel):
    id: str
    name: str
    model_file: str
    thumbnail: str
    price: float
    equipped: bool
    owned: bool

class VoicePackItem(BaseModel):
    id: str
    name: str
    type: str
    cosyvoice_id: str
    price: float
    preview_url: str
    equipped: bool
    owned: bool
```

- [ ] **Step 2: Create app/api/characters.py**

```python
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from app.database import get_db
from app.models import Character, UserInventory, ItemType, Outfit, VoicePack
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.character import (
    CharacterConfig, InitCharacterRequest, UpdateCharacterRequest,
    EquipRequest, OutfitItem, VoicePackItem,
)

router = APIRouter(prefix="/api/characters", tags=["characters"])


def _char_to_config(c: Character) -> CharacterConfig:
    return CharacterConfig(
        id=str(c.id), name=c.name, live2d_model=c.live2d_model,
        outfit_id=str(c.outfit_id) if c.outfit_id else None,
        voice_pack_id=str(c.voice_pack_id) if c.voice_pack_id else None,
        outfit_name=c.outfit.name if c.outfit else None,
        voice_pack_name=c.voice_pack.name if c.voice_pack else None,
    )


@router.post("/init", response_model=CharacterConfig)
async def init_character(
    req: InitCharacterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(select(Character).where(Character.user_id == current_user.id))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Character already initialized")

    default_outfit = await db.execute(select(Outfit).where(Outfit.price == 0).limit(1))
    outfit = default_outfit.scalar_one_or_none()
    default_voice = await db.execute(select(VoicePack).where(VoicePack.price == 0).limit(1))
    voice = default_voice.scalar_one_or_none()

    char = Character(user_id=current_user.id, name=req.name,
                     outfit_id=outfit.id if outfit else None,
                     voice_pack_id=voice.id if voice else None)
    db.add(char)

    if outfit:
        db.add(UserInventory(user_id=current_user.id, item_type=ItemType.outfit,
                             item_id=outfit.id, equipped=True))
    if voice:
        db.add(UserInventory(user_id=current_user.id, item_type=ItemType.voice_pack,
                             item_id=voice.id, equipped=True))

    await db.commit()
    await db.refresh(char)
    return _char_to_config(char)


@router.get("/config", response_model=CharacterConfig)
async def get_character_config(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Character).where(Character.user_id == current_user.id))
    char = result.scalar_one_or_none()
    if not char:
        raise HTTPException(404, "Character not initialized")
    return _char_to_config(char)


@router.put("/config", response_model=CharacterConfig)
async def update_character(
    req: UpdateCharacterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Character).where(Character.user_id == current_user.id))
    char = result.scalar_one_or_none()
    if not char:
        raise HTTPException(404, "Character not initialized")
    if req.name is not None:
        char.name = req.name
    await db.commit()
    await db.refresh(char)
    return _char_to_config(char)


@router.get("/outfits")
async def get_my_outfits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OutfitItem]:
    result = await db.execute(
        select(UserInventory, Outfit)
        .join(Outfit, UserInventory.item_id == Outfit.id)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == ItemType.outfit)
    )
    rows = result.all()
    return [
        OutfitItem(id=str(o.id), name=o.name, model_file=o.model_file,
                   thumbnail=o.thumbnail, price=o.price,
                   equipped=inv.equipped, owned=True)
        for inv, o in rows
    ]


@router.get("/voices")
async def get_my_voices(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[VoicePackItem]:
    result = await db.execute(
        select(UserInventory, VoicePack)
        .join(VoicePack, UserInventory.item_id == VoicePack.id)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == ItemType.voice_pack)
    )
    rows = result.all()
    return [
        VoicePackItem(id=str(v.id), name=v.name, type=v.type, cosyvoice_id=v.cosyvoice_id,
                      price=v.price, preview_url=v.preview_url,
                      equipped=inv.equipped, owned=True)
        for inv, v in rows
    ]


@router.put("/equip")
async def equip_item(
    req: EquipRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    item_type = ItemType(req.item_type)
    item_id = UUID(req.item_id)

    # verify ownership
    inv_result = await db.execute(
        select(UserInventory).where(
            UserInventory.user_id == current_user.id,
            UserInventory.item_type == item_type,
            UserInventory.item_id == item_id,
        )
    )
    inv = inv_result.scalar_one_or_none()
    if not inv:
        raise HTTPException(400, "Item not owned")

    # unequip all of this type
    await db.execute(
        update(UserInventory)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == item_type)
        .values(equipped=False)
    )

    # equip the target
    inv.equipped = True

    # update Character table
    char_result = await db.execute(select(Character).where(Character.user_id == current_user.id))
    char = char_result.scalar_one_or_none()
    if char:
        if item_type == ItemType.outfit:
            char.outfit_id = item_id
        else:
            char.voice_pack_id = item_id

    await db.commit()
    return {"status": "ok"}
```

- [ ] **Step 3: Register router and seed default data**

Add to `backend/app/main.py`:

```python
from app.api.characters import router as character_router
app.include_router(character_router)
```

Create `backend/app/api/seed.py` for default outfit/voice:

```python
from sqlalchemy import select
from app.database import async_session
from app.models import Outfit, VoicePack

async def seed_defaults():
    async with async_session() as db:
        existing = await db.execute(select(Outfit).where(Outfit.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            db.add(Outfit(name="默认服装", model_file="default.model3.json", thumbnail="", price=0))
        existing = await db.execute(select(VoicePack).where(VoicePack.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            db.add(VoicePack(name="默认女声", type="甜美", cosyvoice_id="default-female", price=0, preview_url=""))
        await db.commit()
```

Add to `app/main.py` startup:

```python
@app.on_event("startup")
async def startup():
    from app.api.seed import seed_defaults
    await seed_defaults()
```

- [ ] **Step 4: Write test**

```python
# backend/tests/test_characters.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

async def _get_token(client: AsyncClient) -> str:
    resp = await client.post("/api/auth/login", json={"phone": "13800138003"})
    return resp.json()["access_token"]

@pytest.mark.asyncio
async def test_init_character():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await _get_token(client)
        headers = {"Authorization": f"Bearer {token}"}
        resp = await client.post("/api/characters/init", json={"name": "小白"}, headers=headers)
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "小白"

@pytest.mark.asyncio
async def test_get_owned_outfits():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        token = await _get_token(client)
        headers = {"Authorization": f"Bearer {token}"}
        await client.post("/api/characters/init", json={"name": "小黑"}, headers=headers)
        resp = await client.get("/api/characters/outfits", headers=headers)
        assert resp.status_code == 200
        assert len(resp.json()) >= 1
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_characters.py -v
```
Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas/character.py backend/app/api/characters.py backend/app/api/seed.py backend/app/main.py backend/tests/test_characters.py
git commit -m "feat: character init, config, inventory, equip API"
```

---

### Task 7: Conversation, Shop, Calendar, Expense, Sync APIs

**Files:**
- Create: `backend/app/schemas/conversation.py`
- Create: `backend/app/api/conversations.py`
- Create: `backend/app/schemas/shop.py`
- Create: `backend/app/api/shop.py`
- Create: `backend/app/schemas/calendar.py`
- Create: `backend/app/api/calendar.py`
- Create: `backend/app/schemas/expense.py`
- Create: `backend/app/api/expenses.py`
- Create: `backend/app/schemas/sync.py`
- Create: `backend/app/api/sync.py`

- [ ] **Step 1: Create app/schemas/conversation.py**

```python
from pydantic import BaseModel
from datetime import datetime

class ConversationItem(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime

class MessageItem(BaseModel):
    id: str
    role: str
    type: str
    content: str
    audio_url: str
    created_at: datetime

class UpdateTitleRequest(BaseModel):
    title: str
```

- [ ] **Step 2: Create app/api/conversations.py**

```python
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc, delete as sql_delete
from app.database import get_db
from app.models import Conversation, Message, User
from app.api.deps import get_current_user
from app.schemas.conversation import ConversationItem, MessageItem, UpdateTitleRequest

router = APIRouter(prefix="/api/conversations", tags=["conversations"])


@router.get("")
async def list_conversations(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    offset = (page - 1) * page_size
    total_result = await db.execute(
        select(func.count(Conversation.id)).where(Conversation.user_id == current_user.id)
    )
    total = total_result.scalar()
    result = await db.execute(
        select(Conversation)
        .where(Conversation.user_id == current_user.id)
        .order_by(desc(Conversation.updated_at))
        .offset(offset).limit(page_size)
    )
    convs = result.scalars().all()
    return {
        "items": [
            ConversationItem(id=str(c.id), title=c.title,
                           created_at=c.created_at, updated_at=c.updated_at)
            for c in convs
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/{conv_id}/messages")
async def list_messages(
    conv_id: UUID,
    cursor: str = Query(None),
    limit: int = Query(20, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    # verify ownership
    conv_result = await db.execute(
        select(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
    if not conv_result.scalar_one_or_none():
        raise HTTPException(404, "Conversation not found")

    q = select(Message).where(Message.conv_id == conv_id).order_by(desc(Message.created_at))
    if cursor:
        q = q.where(Message.created_at < cursor)
    q = q.limit(limit)
    result = await db.execute(q)
    msgs = result.scalars().all()
    return {
        "items": [
            MessageItem(id=str(m.id), role=m.role.value, type=m.type.value,
                       content=m.content, audio_url=m.audio_url, created_at=m.created_at)
            for m in reversed(msgs)
        ],
        "next_cursor": str(msgs[-1].created_at) if len(msgs) == limit else None,
    }


@router.delete("/{conv_id}")
async def delete_conversation(
    conv_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        sql_delete(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
    await db.commit()
    return {"status": "deleted"}


@router.put("/{conv_id}/title")
async def update_title(
    conv_id: UUID,
    req: UpdateTitleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Conversation).where(Conversation.id == conv_id, Conversation.user_id == current_user.id)
    )
    conv = result.scalar_one_or_none()
    if not conv:
        raise HTTPException(404, "Conversation not found")
    conv.title = req.title
    await db.commit()
    return {"status": "ok"}
```

- [ ] **Step 3: Create remaining schemas and APIs**

For brevity, the pattern follows the same structure. Create each:

`app/schemas/shop.py`:
```python
from pydantic import BaseModel

class ShopOutfitItem(BaseModel):
    id: str
    name: str
    model_file: str
    thumbnail: str
    price: float
    owned: bool

class ShopVoiceItem(BaseModel):
    id: str
    name: str
    type: str
    price: float
    preview_url: str
    owned: bool

class PurchaseRequest(BaseModel):
    item_type: str  # "outfit" or "voice_pack"
    item_id: str
```

`app/api/shop.py` — queries outfits/voice_packs, checks `UserInventory` for `owned` flag, creates inventory record on purchase.

`app/schemas/calendar.py`:
```python
from pydantic import BaseModel
from datetime import datetime

class CalendarEventItem(BaseModel):
    id: str
    title: str
    time: datetime
    repeat_rule: str
    notified: bool
    created_at: datetime
    updated_at: datetime

class CreateCalendarEvent(BaseModel):
    title: str
    time: datetime
    repeat_rule: str = "none"

class UpdateCalendarEvent(BaseModel):
    title: str | None = None
    time: datetime | None = None
    repeat_rule: str | None = None
```

`app/api/calendar.py` — standard CRUD on `CalendarEvent`, filtered by `current_user.id`.

`app/schemas/expense.py`:
```python
from pydantic import BaseModel
from datetime import datetime

class ExpenseItem(BaseModel):
    id: str
    amount: float
    category: str
    remark: str
    recorded_at: datetime
    created_at: datetime

class CreateExpense(BaseModel):
    amount: float
    category: str = "其他"
    remark: str = ""
    recorded_at: datetime | None = None

class UpdateExpense(BaseModel):
    amount: float | None = None
    category: str | None = None
    remark: str | None = None

class ExpenseStats(BaseModel):
    total_expense: float
    total_income: float
    by_category: dict[str, float]
```

`app/api/expenses.py` — CRUD + stats aggregation with `func.sum()` grouped by category.

`app/schemas/sync.py`:
```python
from pydantic import BaseModel
from datetime import datetime

class SyncAction(BaseModel):
    id: str
    action: str  # create, update, delete
    data: dict

class SyncRequest(BaseModel):
    events: list[SyncAction] = []
    expenses: list[SyncAction] = []
    last_sync_at: datetime

class SyncResponse(BaseModel):
    server_changes: dict  # {"events": [...], "expenses": [...]}
    sync_at: datetime
```

`app/api/sync.py` — processes batch actions, returns server-side changes newer than `last_sync_at`.

- [ ] **Step 4: Register all routers in app/main.py**

```python
from app.api.conversations import router as conv_router
from app.api.shop import router as shop_router
from app.api.calendar import router as calendar_router
from app.api.expenses import router as expense_router
from app.api.sync import router as sync_router

app.include_router(conv_router)
app.include_router(shop_router)
app.include_router(calendar_router)
app.include_router(expense_router)
app.include_router(sync_router)
```

- [ ] **Step 5: Write tests for each module and verify**

```bash
cd backend && python -m pytest tests/ -v
```
Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/schemas/ backend/app/api/
git commit -m "feat: conversation, shop, calendar, expense, sync REST APIs"
```

---

## Phase 3: AI Services & WebSocket Chat

### Task 8: ASR, LLM, TTS services

**Files:**
- Create: `backend/app/services/__init__.py`
- Create: `backend/app/services/asr_service.py`
- Create: `backend/app/services/llm_service.py`
- Create: `backend/app/services/tts_service.py`

- [ ] **Step 1: Create app/services/asr_service.py**

```python
import httpx
from app.config import settings

class ASRService:
    def __init__(self):
        self.api_key = settings.qwen_api_key
        self.api_url = settings.asr_api_url

    async def transcribe(self, audio_base64: str, audio_format: str = "wav") -> str:
        headers = {"Authorization": f"Bearer {self.api_key}"}
        data = {"model": "qwen3-asr-flash", "input": {"audio": audio_base64, "format": audio_format}}
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(self.api_url, json=data, headers=headers)
            resp.raise_for_status()
            result = resp.json()
            return result.get("output", {}).get("text", "")

asr_service = ASRService()
```

- [ ] **Step 2: Create app/services/llm_service.py**

```python
from openai import AsyncOpenAI
from app.config import settings

class LLMRouter:
    def __init__(self):
        self.deepseek = AsyncOpenAI(api_key=settings.deepseek_api_key, base_url=settings.deepseek_base_url)
        self.qwen = AsyncOpenAI(api_key=settings.qwen_api_key, base_url=settings.qwen_base_url)
        self.tools = []

    def register_tools(self, tools: list[dict]):
        self.tools = tools

    async def chat(self, messages: list[dict], force_model: str | None = None) -> str:
        client = self.qwen if force_model == "qwen" else self.deepseek
        model = "qwen-plus" if force_model == "qwen" else "deepseek-chat"

        response = await client.chat.completions.create(
            model=model,
            messages=messages,
            tools=self.tools if self.tools else None,
            stream=False,
        )
        choice = response.choices[0]
        return choice.message.content or ""

    async def chat_stream(self, messages: list[dict], force_model: str | None = None):
        client = self.qwen if force_model == "qwen" else self.deepseek
        model = "qwen-plus" if force_model == "qwen" else "deepseek-chat"

        stream = await client.chat.completions.create(
            model=model,
            messages=messages,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta
            if delta.content:
                yield delta.content

    async def classify_intent(self, text: str) -> str:
        """Returns: chat, search, weather, calendar, expense"""
        prompt = f"""分析用户意图，只返回一个标签:
- chat: 普通闲聊
- search: 需要搜索信息
- weather: 查询天气
- calendar: 日历提醒相关
- expense: 记账相关

用户输入: {text}
标签:"""
        response = await self.deepseek.chat.completions.create(
            model="deepseek-chat",
            messages=[{"role": "user", "content": prompt}],
            stream=False,
            max_tokens=10,
        )
        return response.choices[0].message.content.strip().lower()

llm_router = LLMRouter()
```

- [ ] **Step 3: Create app/services/tts_service.py**

```python
import httpx
from app.config import settings

class TTSService:
    def __init__(self):
        self.api_key = settings.qwen_api_key
        self.tts_url = settings.tts_api_url

    async def synthesize_flash(self, text: str, voice: str = "female-1") -> bytes:
        """Use Qwen3-TTS-Flash for fast synthesis."""
        headers = {"Authorization": f"Bearer {self.api_key}"}
        data = {"model": "qwen3-tts-flash", "input": {"text": text}, "parameters": {"voice": voice}}
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(self.tts_url, json=data, headers=headers)
            resp.raise_for_status()
            result = resp.json()
            # response contains audio_url or audio_base64
            audio_url = result.get("output", {}).get("audio_url", "")
            if audio_url:
                async with httpx.AsyncClient() as audio_client:
                    audio_resp = await audio_client.get(audio_url)
                    return audio_resp.content
            return b""

    async def synthesize_cosyvoice(self, text: str, cosyvoice_id: str) -> bytes:
        """Use CosyVoice for character voices."""
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{settings.cosyvoice_endpoint}/synthesize",
                json={"text": text, "voice_id": cosyvoice_id},
            )
            resp.raise_for_status()
            return resp.content

tts_service = TTSService()
```

- [ ] **Step 4: Commit**

```bash
git add backend/app/services/
git commit -m "feat: ASR, LLM router, and TTS services"
```

---

### Task 9: Skill system

**Files:**
- Create: `backend/app/services/skills/__init__.py`
- Create: `backend/app/services/skills/base.py`
- Create: `backend/app/services/skills/weather.py`
- Create: `backend/app/services/skills/calendar_skill.py`
- Create: `backend/app/services/skills/expense_skill.py`
- Create: `backend/app/services/skills/search.py`
- Create: `backend/app/services/skill_registry.py`

- [ ] **Step 1: Create app/services/skills/base.py**

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class SkillResult:
    text: str  # response text to speak
    data: dict | None = None  # structured data for UI

class BaseSkill(ABC):
    name: str = ""

    @abstractmethod
    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        ...
```

- [ ] **Step 2: Create app/services/skills/weather.py**

```python
import httpx
from app.services.skills.base import BaseSkill, SkillResult

class WeatherSkill(BaseSkill):
    name = "weather"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        # Extract city from user_input using LLM, then call weather API
        # Simplified: default to Beijing for MVP
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                "https://wttr.in/Beijing?format=j1",
                timeout=10,
            )
            data = resp.json()
            current = data["current_condition"][0]
            temp = current["temp_C"]
            desc = current["weatherDesc"][0]["value"]
            text = f"北京当前温度{temp}度，{desc}"
            return SkillResult(text=text, data={"city": "北京", "temp": temp, "desc": desc})

weather_skill = WeatherSkill()
```

- [ ] **Step 3: Create calendar_skill.py, expense_skill.py, search.py**

`calendar_skill.py`:
```python
from datetime import datetime
from app.services.skills.base import BaseSkill, SkillResult
from app.models import CalendarEvent

class CalendarSkill(BaseSkill):
    name = "calendar"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        # Use LLM to extract time and title, simplified here
        # Real implementation: call llm_router to extract structured data
        text = "日历提醒功能需要通过对话提取时间和事件信息"
        return SkillResult(text=text)

calendar_skill = CalendarSkill()
```

`expense_skill.py`:
```python
from datetime import datetime
from app.services.skills.base import BaseSkill, SkillResult

class ExpenseSkill(BaseSkill):
    name = "expense"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        # Use LLM to extract amount, category, remark
        text = "记账功能需要通过对话提取金额和类别信息"
        return SkillResult(text=text)

expense_skill = ExpenseSkill()
```

`search.py`:
```python
import httpx
from app.services.skills.base import BaseSkill, SkillResult

class SearchSkill(BaseSkill):
    name = "search"

    def __init__(self, searxng_url: str = "http://searxng:8080"):
        self.searxng_url = searxng_url

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.searxng_url}/search",
                params={"q": user_input, "format": "json", "engines": "google,bing"},
                timeout=10,
            )
            data = resp.json()
            results = data.get("results", [])[:5]
            if not results:
                return SkillResult(text="没有找到相关信息")
            lines = [f"- {r['title']}: {r.get('content', '')[:100]}" for r in results]
            text = "搜索到以下结果:\n" + "\n".join(lines)
            return SkillResult(text=text, data={"results": results})

search_skill = SearchSkill()
```

- [ ] **Step 4: Create app/services/skill_registry.py**

```python
from app.services.skills.base import BaseSkill
from app.services.skills.weather import weather_skill
from app.services.skills.calendar_skill import calendar_skill
from app.services.skills.expense_skill import expense_skill
from app.services.skills.search import search_skill

class SkillRegistry:
    def __init__(self):
        self._skills: dict[str, BaseSkill] = {
            "weather": weather_skill,
            "calendar": calendar_skill,
            "expense": expense_skill,
            "search": search_skill,
        }

    def get(self, name: str) -> BaseSkill | None:
        return self._skills.get(name)

skill_registry = SkillRegistry()
```

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/skills/ backend/app/services/skill_registry.py
git commit -m "feat: skill system with weather, calendar, expense, search plugins"
```

---

### Task 10: Chat orchestrator and WebSocket endpoint

**Files:**
- Create: `backend/app/services/chat_orchestrator.py`
- Create: `backend/app/api/ws_chat.py`

- [ ] **Step 1: Create app/services/chat_orchestrator.py**

```python
import json
import uuid
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models import Conversation, Message, MessageRole, MessageType
from app.services.llm_service import llm_router
from app.services.tts_service import tts_service
from app.services.skill_registry import skill_registry

class ChatOrchestrator:
    async def process_text(
        self,
        user_id: str,
        text: str,
        conversation_id: str | None,
        db: AsyncSession,
        send_message,
    ):
        # 1. Get or create conversation
        conv = await self._get_or_create_conv(user_id, conversation_id, db, text)

        # 2. Save user message
        user_msg = Message(conv_id=conv.id, role=MessageRole.user, type=MessageType.text, content=text)
        db.add(user_msg)

        # 3. Classify intent
        intent = await llm_router.classify_intent(text)

        # 4. Execute skill or chat
        if intent != "chat" and intent in skill_registry._skills:
            skill = skill_registry.get(intent)
            result = await skill.execute(user_id, text, db)
            response_text = result.text
            await send_message({"type": "skill_call", "skill": intent, "status": "done"})
        else:
            # Build conversation history (last 20 messages)
            msgs_result = await db.execute(
                select(Message).where(Message.conv_id == conv.id).order_by(Message.created_at.desc()).limit(20)
            )
            history = msgs_result.scalars().all()
            history.reverse()
            llm_messages = [{"role": m.role.value, "content": m.content} for m in history]
            llm_messages.append({"role": "user", "content": text})

            # Stream LLM response
            full_response = ""
            async for delta in llm_router.chat_stream(llm_messages):
                full_response += delta
                await send_message({"type": "llm_stream", "delta": delta})

            response_text = full_response

        # 5. Save assistant message
        assistant_msg = Message(conv_id=conv.id, role=MessageRole.assistant, type=MessageType.text, content=response_text)
        db.add(assistant_msg)
        conv.updated_at = datetime.utcnow()
        await db.commit()

        # 6. Synthesize TTS
        try:
            audio_bytes = await tts_service.synthesize_flash(response_text)
            if audio_bytes:
                import base64
                await send_message({"type": "tts_audio", "audio": base64.b64encode(audio_bytes).decode(), "text": response_text})
        except Exception:
            pass  # TTS failure is non-fatal

        # 7. Done
        await send_message({"type": "done", "conversation_id": str(conv.id)})

    async def process_voice(
        self,
        user_id: str,
        audio_base64: str,
        conversation_id: str | None,
        db: AsyncSession,
        send_message,
    ):
        from app.services.asr_service import asr_service

        # 1. ASR
        text = await asr_service.transcribe(audio_base64)
        await send_message({"type": "asr_result", "text": text})

        if not text.strip():
            await send_message({"type": "done"})
            return

        # 2. Continue with text processing
        await self.process_text(user_id, text, conversation_id, db, send_message)

    async def _get_or_create_conv(self, user_id: str, conv_id: str | None, db: AsyncSession, text: str):
        if conv_id:
            result = await db.execute(select(Conversation).where(Conversation.id == conv_id, Conversation.user_id == user_id))
            conv = result.scalar_one_or_none()
            if conv:
                return conv
        conv = Conversation(user_id=user_id, title=text[:30] if len(text) <= 30 else text[:30] + "...")
        db.add(conv)
        await db.commit()
        await db.refresh(conv)
        return conv

chat_orchestrator = ChatOrchestrator()
```

- [ ] **Step 2: Create app/api/ws_chat.py**

```python
import json
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import async_session
from app.core.security import decode_access_token
from app.services.chat_orchestrator import chat_orchestrator

router = APIRouter()

@router.websocket("/ws/chat")
async def websocket_chat(ws: WebSocket):
    token = ws.query_params.get("token", "")
    payload = decode_access_token(token)
    if payload is None:
        await ws.close(code=4001)
        return

    user_id = payload["sub"]
    await ws.accept()

    async def send_message(msg: dict):
        await ws.send_text(json.dumps(msg, ensure_ascii=False))

    async with async_session() as db:
        try:
            while True:
                raw = await ws.receive_text()
                data = json.loads(raw)
                msg_type = data.get("type")

                if msg_type == "text":
                    await chat_orchestrator.process_text(
                        user_id, data["content"], data.get("conversation_id"), db, send_message
                    )
                elif msg_type == "voice":
                    await chat_orchestrator.process_voice(
                        user_id, data["audio"], data.get("conversation_id"), db, send_message
                    )
                else:
                    await send_message({"type": "error", "message": f"Unknown type: {msg_type}"})

        except WebSocketDisconnect:
            pass
```

- [ ] **Step 3: Register WS router in app/main.py**

```python
from app.api.ws_chat import router as ws_router
app.include_router(ws_router)
```

- [ ] **Step 4: Write WebSocket test**

```python
# backend/tests/test_ws_chat.py
import pytest
from httpx import AsyncClient, ASGITransport
from httpx_ws import aconnect_ws
from app.main import app

@pytest.mark.asyncio
async def test_ws_text_chat():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # login first
        resp = await client.post("/api/auth/login", json={"phone": "13800138005"})
        token = resp.json()["access_token"]

        async with aconnect_ws(f"http://test/ws/chat?token={token}", client) as ws:
            await ws.send_text('{"type": "text", "content": "你好"}')
            # should receive streaming response
            messages = []
            while True:
                msg = await ws.receive_text()
                data = json.loads(msg)
                messages.append(data)
                if data["type"] == "done":
                    break
            assert any(m["type"] == "llm_stream" for m in messages)
```

- [ ] **Step 5: Run tests**

```bash
cd backend && python -m pytest tests/test_ws_chat.py -v
```
Expected: Pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/chat_orchestrator.py backend/app/api/ws_chat.py backend/app/main.py backend/tests/test_ws_chat.py
git commit -m "feat: chat orchestrator and WebSocket endpoint"
```

---

## Phase 4: Flutter Data Layer

### Task 11: Flutter data models and API client

**Files:**
- Create: `frontend/lib/models/user.dart`
- Create: `frontend/lib/models/conversation.dart`
- Create: `frontend/lib/models/message.dart`
- Create: `frontend/lib/models/character_config.dart`
- Create: `frontend/lib/models/inventory_item.dart`
- Create: `frontend/lib/models/voice_pack.dart`
- Create: `frontend/lib/models/outfit.dart`
- Create: `frontend/lib/models/calendar_event.dart`
- Create: `frontend/lib/models/expense_record.dart`
- Create: `frontend/lib/services/api_client.dart`

- [ ] **Step 1: Create frontend/lib/models/user.dart**

```dart
class User {
  final String id;
  final String phone;
  final String nickname;
  final String avatar;

  const User({required this.id, required this.phone, this.nickname = '', this.avatar = ''});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    phone: json['phone'] as String,
    nickname: json['nickname'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
  );
}
```

- [ ] **Step 2: Create the remaining models similarly**

`message.dart`:
```dart
class Message {
  final String id;
  final String role; // user, assistant
  final String type; // text, voice
  final String content;
  final String audioUrl;
  final DateTime createdAt;

  const Message({required this.id, required this.role, required this.type, required this.content, this.audioUrl = '', required this.createdAt});

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    role: json['role'] as String,
    type: json['type'] as String,
    content: json['content'] as String? ?? '',
    audioUrl: json['audio_url'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
```

`conversation.dart`:
```dart
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({required this.id, required this.title, required this.createdAt, required this.updatedAt});

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}
```

`calendar_event.dart`:
```dart
class CalendarEvent {
  final String id;
  final String title;
  final DateTime time;
  final String repeatRule;
  final bool notified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CalendarEvent({required this.id, required this.title, required this.time, this.repeatRule = 'none', this.notified = false, required this.createdAt, required this.updatedAt});

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    time: DateTime.parse(json['time'] as String),
    repeatRule: json['repeat_rule'] as String? ?? 'none',
    notified: json['notified'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'title': title, 'time': time.toIso8601String(),
    'repeat_rule': repeatRule,
  };
}
```

`expense_record.dart`:
```dart
class ExpenseRecord {
  final String id;
  final double amount;
  final String category;
  final String remark;
  final DateTime recordedAt;
  final DateTime createdAt;

  const ExpenseRecord({required this.id, required this.amount, this.category = '其他', this.remark = '', required this.recordedAt, required this.createdAt});

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    id: json['id'] as String,
    amount: (json['amount'] as num).toDouble(),
    category: json['category'] as String? ?? '其他',
    remark: json['remark'] as String? ?? '',
    recordedAt: DateTime.parse(json['recorded_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'amount': amount, 'category': category, 'remark': remark,
    'recorded_at': recordedAt.toIso8601String(),
  };
}
```

`character_config.dart`:
```dart
class CharacterConfig {
  final String id;
  final String name;
  final String live2dModel;
  final String? outfitId;
  final String? voicePackId;
  final String? outfitName;
  final String? voicePackName;

  const CharacterConfig({required this.id, required this.name, required this.live2dModel, this.outfitId, this.voicePackId, this.outfitName, this.voicePackName});

  factory CharacterConfig.fromJson(Map<String, dynamic> json) => CharacterConfig(
    id: json['id'] as String, name: json['name'] as String,
    live2dModel: json['live2d_model'] as String,
    outfitId: json['outfit_id'] as String?, voicePackId: json['voice_pack_id'] as String?,
    outfitName: json['outfit_name'] as String?, voicePackName: json['voice_pack_name'] as String?,
  );
}
```

`inventory_item.dart`, `voice_pack.dart`, `outfit.dart` follow the same `fromJson` pattern.

- [ ] **Step 3: Create frontend/lib/services/api_client.dart**

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ApiClient {
  final http.Client _client = http.Client();

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: queryParams);
    final resp = await _client.get(uri, headers: await _headers());
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.post(uri, headers: await _headers(), body: jsonEncode(body));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.put(uri, headers: await _headers(), body: jsonEncode(body));
    return _handleResponse(resp);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final resp = await _client.delete(uri, headers: await _headers());
    return _handleResponse(resp);
  }

  Map<String, dynamic> _handleResponse(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return {'status': 'ok'};
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw ApiException(resp.statusCode, resp.body);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}
```

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/models/ frontend/lib/services/api_client.dart
git commit -m "feat: Flutter data models and API client"
```

---

### Task 12: Flutter services (auth, WebSocket, calendar, expense, sync)

**Files:**
- Create: `frontend/lib/services/auth_service.dart`
- Create: `frontend/lib/services/ws_service.dart`
- Create: `frontend/lib/services/calendar_service.dart`
- Create: `frontend/lib/services/expense_service.dart`
- Create: `frontend/lib/services/sync_service.dart`

- [ ] **Step 1: Create frontend/lib/services/auth_service.dart**

```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  Future<LoginResult> login(String phone) async {
    final data = await _api.post('/api/auth/login', body: {'phone': phone});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', data['access_token'] as String);
    return LoginResult(
      accessToken: data['access_token'] as String,
      isNewUser: data['is_new_user'] as bool,
    );
  }

  Future<User> getProfile() async {
    final data = await _api.get('/api/auth/profile');
    return User.fromJson(data);
  }

  Future<void> updateProfile({String? nickname, String? avatar}) async {
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (avatar != null) body['avatar'] = avatar;
    await _api.put('/api/auth/profile', body: body);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('access_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
}

class LoginResult {
  final String accessToken;
  final bool isNewUser;

  LoginResult({required this.accessToken, required this.isNewUser});
}
```

- [ ] **Step 2: Create frontend/lib/services/ws_service.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

enum WsState { disconnected, connecting, connected }

class WsMessage {
  final String type;
  final Map<String, dynamic> data;
  WsMessage(this.type, this.data);
}

class WsService {
  WebSocketChannel? _channel;
  WsState _state = WsState.disconnected;
  final _controller = StreamController<WsMessage>.broadcast();
  String? conversationId;

  WsState get state => _state;
  Stream<WsMessage> get messages => _controller.stream;

  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    _state = WsState.connecting;
    _channel = WebSocketChannel.connect(
      Uri.parse('${AppConfig.wsBaseUrl}/ws/chat?token=$token'),
    );
    _state = WsState.connected;
    _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        _controller.add(WsMessage(json['type'] as String, json));
      },
      onDone: () { _state = WsState.disconnected; },
      onError: (_) { _state = WsState.disconnected; },
    );
  }

  void sendText(String text) {
    _channel?.sink.add(jsonEncode({
      'type': 'text',
      'content': text,
      'conversation_id': conversationId,
    }));
  }

  void sendVoice(String base64Audio) {
    _channel?.sink.add(jsonEncode({
      'type': 'voice',
      'audio': base64Audio,
      'conversation_id': conversationId,
    }));
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _state = WsState.disconnected;
    _controller.close();
    conversationId = null;
  }
}
```

- [ ] **Step 3: Create calendar_service.dart, expense_service.dart, sync_service.dart**

`calendar_service.dart`:
```dart
import '../models/calendar_event.dart';
import 'api_client.dart';

class CalendarService {
  final ApiClient _api = ApiClient();

  Future<List<CalendarEvent>> getEvents() async {
    final data = await _api.get('/api/calendar/events');
    final items = data['items'] as List? ?? [];
    return items.map((j) => CalendarEvent.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final data = await _api.post('/api/calendar/events', body: event.toJson());
    return CalendarEvent.fromJson(data);
  }

  Future<void> updateEvent(String id, CalendarEvent event) async {
    await _api.put('/api/calendar/events/$id', body: event.toJson());
  }

  Future<void> deleteEvent(String id) async {
    await _api.delete('/api/calendar/events/$id');
  }
}
```

`expense_service.dart`:
```dart
import '../models/expense_record.dart';
import 'api_client.dart';

class ExpenseService {
  final ApiClient _api = ApiClient();

  Future<List<ExpenseRecord>> getExpenses({String? category, String? month}) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (month != null) params['month'] = month;
    final data = await _api.get('/api/expenses', queryParams: params.isNotEmpty ? params : null);
    final items = data['items'] as List? ?? [];
    return items.map((j) => ExpenseRecord.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<ExpenseRecord> createExpense(ExpenseRecord record) async {
    final data = await _api.post('/api/expenses', body: record.toJson());
    return ExpenseRecord.fromJson(data);
  }

  Future<void> deleteExpense(String id) async {
    await _api.delete('/api/expenses/$id');
  }

  Future<Map<String, dynamic>> getStats() async {
    return await _api.get('/api/expenses/stats');
  }
}
```

`sync_service.dart`:
```dart
import 'api_client.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> sync({
    required List<Map<String, dynamic>> events,
    required List<Map<String, dynamic>> expenses,
    required DateTime lastSyncAt,
  }) async {
    return await _api.post('/api/data/sync', body: {
      'events': events,
      'expenses': expenses,
      'last_sync_at': lastSyncAt.toIso8601String(),
    });
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/services/
git commit -m "feat: Flutter auth, WebSocket, calendar, expense, sync services"
```

---

## Phase 5: Flutter State Management & UI

### Task 13: Providers (state management)

**Files:**
- Create: `frontend/lib/providers/auth_provider.dart`
- Create: `frontend/lib/providers/chat_provider.dart`
- Create: `frontend/lib/providers/character_provider.dart`
- Create: `frontend/lib/providers/calendar_provider.dart`
- Create: `frontend/lib/providers/expense_provider.dart`

- [ ] **Step 1: Create frontend/lib/providers/auth_provider.dart**

```dart
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;

  Future<void> checkAuth() async {
    if (await _auth.isLoggedIn()) {
      _loading = true;
      notifyListeners();
      try {
        _user = await _auth.getProfile();
      } catch (_) {
        await _auth.logout();
      }
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String phone) async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _auth.login(phone);
      _user = await _auth.getProfile();
      _loading = false;
      notifyListeners();
      return result.isNewUser;
    } catch (_) {
      _loading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    _user = null;
    notifyListeners();
  }
}
```

- [ ] **Step 2: Create chat_provider.dart**

```dart
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/ws_service.dart';

class ChatProvider extends ChangeNotifier {
  final WsService _ws = WsService();
  final List<Message> _messages = [];
  String _streamingText = "";
  bool _isProcessing = false;
  String? currentSkill;

  List<Message> get messages => List.unmodifiable(_messages);
  String get streamingText => _streamingText;
  bool get isProcessing => _isProcessing;
  WsService get ws => _ws;

  void startConversation({String? conversationId}) {
    _messages.clear();
    _streamingText = "";
    _ws.conversationId = conversationId;
    _ws.messages.listen(_onWsMessage);
    _ws.connect();
  }

  void sendText(String text) {
    _messages.add(Message(id: 'temp_${DateTime.now().millisecondsSinceEpoch}', role: 'user', type: 'text', content: text, createdAt: DateTime.now()));
    _isProcessing = true;
    _streamingText = "";
    notifyListeners();
    _ws.sendText(text);
  }

  void _onWsMessage(WsMessage msg) {
    switch (msg.type) {
      case 'asr_result':
        final text = msg.data['text'] as String;
        _messages.add(Message(id: 'temp_${DateTime.now().millisecondsSinceEpoch}', role: 'user', type: 'text', content: text, createdAt: DateTime.now()));
        break;
      case 'llm_stream':
        _streamingText += msg.data['delta'] as String;
        break;
      case 'skill_call':
        currentSkill = msg.data['skill'] as String?;
        break;
      case 'tts_audio':
        // TTS playback handled by TTS player service
        break;
      case 'done':
        if (_streamingText.isNotEmpty) {
          _messages.add(Message(id: 'msg_${DateTime.now().millisecondsSinceEpoch}', role: 'assistant', type: 'text', content: _streamingText, createdAt: DateTime.now()));
          _streamingText = "";
        }
        _isProcessing = false;
        currentSkill = null;
        if (msg.data['conversation_id'] != null) {
          _ws.conversationId = msg.data['conversation_id'] as String;
        }
        break;
    }
    notifyListeners();
  }

  Future<void> endConversation() async {
    await _ws.disconnect();
    _messages.clear();
    _streamingText = "";
    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _ws.disconnect();
    super.dispose();
  }
}
```

- [ ] **Step 3: Create character_provider.dart, calendar_provider.dart, expense_provider.dart**

`character_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/character_config.dart';
import '../services/api_client.dart';

class CharacterProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  CharacterConfig? _config;
  List<Map<String, dynamic>> _outfits = [];
  List<Map<String, dynamic>> _voices = [];
  bool _loading = false;

  CharacterConfig? get config => _config;
  List<Map<String, dynamic>> get outfits => _outfits;
  List<Map<String, dynamic>> get voices => _voices;
  bool get loading => _loading;

  Future<void> initCharacter(String name) async {
    final data = await _api.post('/api/characters/init', body: {'name': name});
    _config = CharacterConfig.fromJson(data);
    notifyListeners();
  }

  Future<void> loadConfig() async {
    _loading = true; notifyListeners();
    try {
      _config = CharacterConfig.fromJson(await _api.get('/api/characters/config'));
      final outfitsData = await _api.get('/api/characters/outfits');
      _outfits = (outfitsData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final voicesData = await _api.get('/api/characters/voices');
      _voices = (voicesData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> equip(String itemType, String itemId) async {
    await _api.put('/api/characters/equip', body: {'item_type': itemType, 'item_id': itemId});
    await loadConfig();
  }
}
```

`calendar_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarService _service = CalendarService();
  List<CalendarEvent> _events = [];
  bool _loading = false;

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;

  Future<void> loadEvents() async {
    _loading = true; notifyListeners();
    _events = await _service.getEvents();
    _loading = false; notifyListeners();
  }

  Future<void> createEvent(CalendarEvent event) async {
    await _service.createEvent(event);
    await loadEvents();
  }

  Future<void> deleteEvent(String id) async {
    await _service.deleteEvent(id);
    await loadEvents();
  }
}
```

`expense_provider.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../models/expense_record.dart';
import '../services/expense_service.dart';

class ExpenseProvider extends ChangeNotifier {
  final ExpenseService _service = ExpenseService();
  List<ExpenseRecord> _records = [];
  Map<String, dynamic>? _stats;
  bool _loading = false;

  List<ExpenseRecord> get records => List.unmodifiable(_records);
  Map<String, dynamic>? get stats => _stats;
  bool get loading => _loading;

  Future<void> load({String? category, String? month}) async {
    _loading = true; notifyListeners();
    try {
      _records = await _service.getExpenses(category: category, month: month);
      _stats = await _service.getStats();
    } catch (_) {}
    _loading = false; notifyListeners();
  }

  Future<void> create(ExpenseRecord record) async {
    await _service.createExpense(record);
    await load();
  }

  Future<void> delete(String id) async {
    await _service.deleteExpense(id);
    await load();
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/providers/
git commit -m "feat: Flutter providers for auth, chat, character, calendar, expense"
```

---

### Task 14: Screens and widgets

**Files:**
- Create: `frontend/lib/screens/login_screen.dart`
- Create: `frontend/lib/screens/home_screen.dart`
- Create: `frontend/lib/screens/chat_screen.dart`
- Create: `frontend/lib/screens/character_screen.dart`
- Create: `frontend/lib/screens/calendar_screen.dart`
- Create: `frontend/lib/screens/expense_screen.dart`
- Create: `frontend/lib/screens/shop_screen.dart`
- Create: `frontend/lib/widgets/chat_bubble.dart`
- Create: `frontend/lib/widgets/voice_record_button.dart`
- Create: `frontend/lib/widgets/live2d_view.dart`

- [ ] **Step 1: Create login_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正确的手机号')));
      return;
    }
    setState(() => _loading = true);
    try {
      final isNew = await context.read<AuthProvider>().login(phone);
      if (isNew && mounted) {
        _showNameDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录失败: $e')));
      }
    }
    setState(() => _loading = false);
  }

  void _showNameDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('给你的AI伴侣起个名字'),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: '如：小白、小灵')),
        actions: [
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await context.read<CharacterProvider>().initCharacter(name);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('灵犀', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.indigo)),
              const SizedBox(height: 8),
              const Text('AI 虚拟伴侣', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                decoration: const InputDecoration(labelText: '手机号', hintText: '请输入手机号', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading ? const CircularProgressIndicator() : const Text('登录 / 注册', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create home_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'character_screen.dart';
import 'calendar_screen.dart';
import 'expense_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _pages = const [
    ChatScreen(),
    CalendarScreen(),
    ExpenseScreen(),
    CharacterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: '对话'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: '日历'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: '记账'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '角色'),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Create chat_screen.dart**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/live2d_view.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ChatProvider>().startConversation();
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    context.read<ChatProvider>().sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('对话'), actions: [
            IconButton(icon: const Icon(Icons.shopping_bag), onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopScreen()));
            }),
          ]),
          body: Column(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const SizedBox(height: 200, child: Live2DView()),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chat.messages.length + (chat.streamingText.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < chat.messages.length) {
                            return ChatBubble(message: chat.messages[i]);
                          }
                          return ChatBubble(isStreaming: true, streamingText: chat.streamingText);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              if (chat.isProcessing)
                const LinearProgressIndicator()
              else if (chat.currentSkill != null)
                Padding(padding: const EdgeInsets.all(8), child: Chip(label: Text('执行: ${chat.currentSkill}')))
              ,
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const VoiceRecordButton(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(hintText: '输入消息...', border: OutlineInputBorder()),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.send), onPressed: _sendText),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Create widgets/chat_bubble.dart, voice_record_button.dart, live2d_view.dart**

`chat_bubble.dart`:
```dart
import 'package:flutter/material.dart';
import '../models/message.dart';

class ChatBubble extends StatelessWidget {
  final Message? message;
  final bool isStreaming;
  final String streamingText;

  const ChatBubble({super.key, this.message, this.isStreaming = false, this.streamingText = ''});

  @override
  Widget build(BuildContext context) {
    final isUser = message?.role == 'user';
    final text = isStreaming ? streamingText : (message?.content ?? '');
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.indigo.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: isStreaming
            ? Row(mainAxisSize: MainAxisSize.min, children: [Text(text), const SizedBox(width: 4), const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 1))])
            : Text(text),
      ),
    );
  }
}
```

`voice_record_button.dart`:
```dart
import 'package:flutter/material.dart';

class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({super.key});

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  bool _recording = false;

  void _toggleRecording() {
    setState(() => _recording = !_recording);
    // TODO: integrate with audio_recorder_service
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleRecording,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _recording ? Colors.red : Colors.indigo,
          shape: BoxShape.circle,
        ),
        child: Icon(_recording ? Icons.mic : Icons.mic_none, color: Colors.white),
      ),
    );
  }
}
```

`live2d_view.dart`:
```dart
import 'package:flutter/material.dart';

class Live2DView extends StatelessWidget {
  const Live2DView({super.key});

  @override
  Widget build(BuildContext context) {
    // MVP: placeholder for Live2D Cubism SDK integration
    return Container(
      color: Colors.indigo.shade50,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 80, color: Colors.indigo),
            SizedBox(height: 8),
            Text('Live2D 角色', style: TextStyle(color: Colors.indigo, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create remaining screens (calendar, expense, character, shop)**

`calendar_screen.dart` — displays list of calendar events with add/delete, uses `CalendarProvider`.

`expense_screen.dart` — displays expense records with stats summary, uses `ExpenseProvider`.

`character_screen.dart` — shows character config, outfit/voice switcher, uses `CharacterProvider`.

`shop_screen.dart` — lists available outfits and voices for purchase, uses `ApiClient`.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/screens/ frontend/lib/widgets/
git commit -m "feat: Flutter screens and widgets for all MVP features"
```

---

## Phase 6: Local Features & Integration

### Task 15: Local storage, ASR, TTS, calendar, notifications

**Files:**
- Create: `frontend/lib/services/audio_recorder_service.dart`
- Create: `frontend/lib/services/asr_local_service.dart`
- Create: `frontend/lib/services/tts_player_service.dart`
- Modify: `frontend/lib/services/calendar_service.dart` (add system calendar write)
- Modify: `frontend/lib/main.dart` (init notifications)

- [ ] **Step 1: Create audio_recorder_service.dart**

```dart
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav));
  }

  Future<String?> stop() async {
    final path = await _recorder.stop();
    return path;
  }

  void dispose() => _recorder.dispose();
}
```

- [ ] **Step 2: Create asr_local_service.dart**

```dart
// Placeholder for whisper.cpp FFI integration
// In MVP, uses the cloud ASR service via WebSocket.
// This will be implemented when offline support is needed.

class AsrLocalService {
  Future<String> transcribe(String audioPath) async {
    // TODO: integrate whisper.cpp via FFI for offline ASR
    return '';
  }
}
```

- [ ] **Step 3: Create tts_player_service.dart**

```dart
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

class TtsPlayerService {
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(Uint8List audioBytes) async {
    try {
      await _player.play(BytesSource(audioBytes));
    } catch (_) {}
  }

  Future<void> stop() async => _player.stop();
  void dispose() => _player.dispose();
}
```

- [ ] **Step 4: Update main.dart for notification init**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettingsIOS = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  runApp(const LingxiApp());
}
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/services/audio_recorder_service.dart frontend/lib/services/asr_local_service.dart frontend/lib/services/tts_player_service.dart frontend/lib/main.dart
git commit -m "feat: local audio recorder, TTS player, notification init"
```

---

### Task 16: Integration test and final wiring

- [ ] **Step 1: Run full backend test suite**

```bash
cd backend && python -m pytest tests/ -v
```
Expected: All tests pass.

- [ ] **Step 2: Run Flutter analyze**

```bash
cd frontend && flutter analyze
```
Expected: No issues found.

- [ ] **Step 3: Run Flutter tests**

```bash
cd frontend && flutter test
```
Expected: All tests pass.

- [ ] **Step 4: Start full stack and do smoke test**

```bash
cd backend && docker compose up -d
cd backend && uvicorn app.main:app --reload &
cd frontend && flutter run
```

Verify: Login → Init character → Send text message → Receive streaming response → Create calendar event → Add expense → View stats.

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete MVP — AI companion with voice chat, search, weather, calendar, and expense tracking"
```
