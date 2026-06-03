import uuid
from sqlalchemy import String, ForeignKey
from sqlalchemy import Uuid
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class Character(Base):
    __tablename__ = "characters"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(String(50), default="小灵")
    live2d_model: Mapped[str] = mapped_column(String(300), default="default.model3.json")
    outfit_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("outfits.id"), nullable=True)
    voice_pack_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("voice_packs.id"), nullable=True)

    user = relationship("User", back_populates="character")
    outfit = relationship("Outfit")
    voice_pack = relationship("VoicePack")
