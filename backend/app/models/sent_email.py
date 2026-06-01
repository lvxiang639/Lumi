import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, func, Uuid, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class SentEmail(Base):
    __tablename__ = "sent_emails"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    conv_title: Mapped[str] = mapped_column(String(200), nullable=False)
    recipient: Mapped[str] = mapped_column(String(200), nullable=False)
    summary_preview: Mapped[str] = mapped_column(Text, nullable=False)
    sent_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
