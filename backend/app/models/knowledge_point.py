"""Knowledge point tree model — grade → subject → topic → point."""

import uuid
from datetime import datetime
from sqlalchemy import String, Integer, DateTime, func, Uuid, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class KnowledgePoint(Base):
    __tablename__ = "knowledge_points"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    parent_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(100), default="")
    grade: Mapped[int] = mapped_column(Integer, default=0)  # 0=通用, 1-12
    subject: Mapped[str] = mapped_column(String(20), default="")  # 数学/语文/英语
    level: Mapped[int] = mapped_column(Integer, default=0)  # 0=根, 1=大类, 2=具体知识点
    keywords: Mapped[str] = mapped_column(String(200), default="")  # comma-separated, for auto-tagging
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
