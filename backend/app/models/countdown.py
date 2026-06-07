import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Countdown(Base):
    __tablename__ = "countdowns"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    target_date: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    note: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
