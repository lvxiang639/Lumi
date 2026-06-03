import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, ForeignKey, Enum, func
from sqlalchemy import Uuid
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

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    conv_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("conversations.id"), nullable=False)
    role: Mapped[MessageRole] = mapped_column(Enum(MessageRole), nullable=False)
    type: Mapped[MessageType] = mapped_column(Enum(MessageType), nullable=False)
    content: Mapped[str] = mapped_column(Text, default="")
    audio_url: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")
