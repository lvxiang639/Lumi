import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class FcmToken(Base):
    __tablename__ = "fcm_tokens"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    token: Mapped[str] = mapped_column(String(500), unique=True, nullable=False)
    platform: Mapped[str] = mapped_column(String(20), default="unknown")  # ios / android
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
