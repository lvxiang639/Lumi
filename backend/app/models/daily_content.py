import uuid
from datetime import datetime, date

from sqlalchemy import String, DateTime, Text, Date, func, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DailyContent(Base):
    """Stores generated daily content — one row per day.
    Discover page loads from here so offline users don't miss it."""

    __tablename__ = "daily_contents"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    date: Mapped[date] = mapped_column(Date, unique=True, nullable=False, index=True)
    content: Mapped[str] = mapped_column(Text, default="")  # JSON of all content types
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
