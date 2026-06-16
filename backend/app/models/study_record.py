import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, Boolean, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class StudyChild(Base):
    """A child/student belonging to a user, for grouping study records."""
    __tablename__ = "study_children"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(50), default="")
    grade: Mapped[str] = mapped_column(String(20), default="")  # e.g. "三年级"
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    records = relationship("StudyRecord", back_populates="child")


class StudyRecord(Base):
    __tablename__ = "study_records"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    child_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, ForeignKey("study_children.id", ondelete="SET NULL"), nullable=True, index=True)
    child_name: Mapped[str] = mapped_column(String(50), default="")  # denormalized for quick display / backward compat
    subject: Mapped[str] = mapped_column(String(20), default="")  # 语文/数学/英语
    tags: Mapped[str] = mapped_column(String(200), default="")  # comma-separated
    question: Mapped[str] = mapped_column(Text, default="")
    answer: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str] = mapped_column(String(500), default="")
    status: Mapped[str] = mapped_column(String(20), default="未掌握")  # 未掌握/已掌握
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    child = relationship("StudyChild", back_populates="records")


class PracticePush(Base):
    __tablename__ = "practice_pushes"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    record_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("study_records.id", ondelete="SET NULL"), nullable=True)
    question: Mapped[str] = mapped_column(Text, default="")
    answer: Mapped[str] = mapped_column(Text, default="")
    solved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
