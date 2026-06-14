import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class HomophoneExercise(Base):
    __tablename__ = "homophone_exercises"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False, index=True
    )

    # LLM-generated questions JSON:
    # [{"target_char":"同","pinyin":"tóng","hint":"...","expected_count":3}, ...]
    questions: Mapped[str] = mapped_column(Text, default="")

    # Student's submitted answers JSON:
    # [{"target_char":"同","items":[{"char":"童","word":"童话"},...]}, ...]
    answers: Mapped[str] = mapped_column(Text, default="")

    # LLM grading result JSON:
    # [{"target_char":"同","results":[{"char":"童","word":"童话","correct":true,"feedback":"..."}], "missing":[...]}, ...]
    grading: Mapped[str] = mapped_column(Text, default="")

    # Score as string like "12/15"
    score: Mapped[str] = mapped_column(String(20), default="")

    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending | completed
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
