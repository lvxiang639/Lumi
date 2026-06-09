import uuid
from datetime import datetime, time
from sqlalchemy import String, DateTime, Boolean, Time, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class ReminderSchedule(Base):
    __tablename__ = "reminder_schedules"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    content: Mapped[str] = mapped_column(String(500), nullable=False)
    rule: Mapped[str] = mapped_column(String(20), default="daily")
    time_of_day: Mapped[time] = mapped_column(Time, nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
