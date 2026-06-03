import uuid
from datetime import datetime
from sqlalchemy import Boolean, DateTime, ForeignKey, Enum, func
from sqlalchemy import Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
import enum


class ItemType(str, enum.Enum):
    outfit = "outfit"
    voice_pack = "voice_pack"


class UserInventory(Base):
    __tablename__ = "user_inventory"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    item_type: Mapped[ItemType] = mapped_column(Enum(ItemType), nullable=False)
    item_id: Mapped[uuid.UUID] = mapped_column(Uuid, nullable=False)
    equipped: Mapped[bool] = mapped_column(Boolean, default=False)
    purchased_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="inventory")
