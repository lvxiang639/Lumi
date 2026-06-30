import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, func, Uuid, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserMemory(Base):
    __tablename__ = "user_memories"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False, index=True
    )
    key: Mapped[str] = mapped_column(String(100), nullable=False)
    value: Mapped[str] = mapped_column(Text, nullable=False)
    source_conv_id: Mapped[uuid.UUID | None] = mapped_column(
        Uuid, ForeignKey("conversations.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
