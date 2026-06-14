import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class OcrRecord(Base):
    __tablename__ = "ocr_records"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False, index=True
    )
    image_base64: Mapped[str] = mapped_column(Text, default="")  # base64-encoded image
    text: Mapped[str] = mapped_column(Text, default="")  # extracted text
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
