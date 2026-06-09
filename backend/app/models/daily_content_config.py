import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Boolean, Integer, Text, func, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class DailyContentConfig(Base):
    """Configurable daily content types — add new types by inserting rows."""
    __tablename__ = "daily_content_configs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    content_type: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), default="")
    prompt: Mapped[str] = mapped_column(Text, default="")
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    priority: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
