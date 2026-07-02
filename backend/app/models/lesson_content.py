"""Cached lesson content — AI-generated, stored for reuse."""

import uuid
from datetime import datetime
from sqlalchemy import String, Text, DateTime, func, Uuid, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class LessonContent(Base):
    __tablename__ = "lesson_contents"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    subject: Mapped[str] = mapped_column(String(20), index=True)
    grade: Mapped[int] = mapped_column(Integer, default=3)
    lesson_name: Mapped[str] = mapped_column(String(200), index=True)
    content: Mapped[str] = mapped_column(Text, default="")
    key_points: Mapped[str] = mapped_column(Text, default="")  # JSON array string
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
