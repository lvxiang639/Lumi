import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Float, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class UserEmotionState(Base):
    __tablename__ = "user_emotion_states"

    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), primary_key=True
    )
    current_emotion: Mapped[str] = mapped_column(
        String(20), nullable=False, default="calm"
    )
    intensity: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    last_updated: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    last_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
