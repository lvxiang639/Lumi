import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ProactivePush(Base):
    """Records each proactive push to prevent duplicates across server restarts."""
    __tablename__ = "proactive_pushes"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    push_type: Mapped[str] = mapped_column(String(50), default="proactive")  # greeting / proactive / news
    message_preview: Mapped[str] = mapped_column(String(200), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
