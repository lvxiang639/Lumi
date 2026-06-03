import uuid
from datetime import datetime

from sqlalchemy import String, DateTime, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ConvertedFile(Base):
    __tablename__ = "converted_files"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        Uuid, ForeignKey("users.id"), nullable=False, index=True
    )
    original_name: Mapped[str] = mapped_column(String(300), nullable=False)
    target_name: Mapped[str] = mapped_column(String(300), nullable=False)
    object_name: Mapped[str] = mapped_column(String(200), nullable=False)
    content_type: Mapped[str] = mapped_column(String(100), nullable=False)
    file_size: Mapped[int] = mapped_column(default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
