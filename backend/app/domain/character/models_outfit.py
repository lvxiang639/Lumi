import uuid
from sqlalchemy import String, Numeric
from sqlalchemy import Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class Outfit(Base):
    __tablename__ = "outfits"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    model_file: Mapped[str] = mapped_column(String(300), nullable=False)
    thumbnail: Mapped[str] = mapped_column(String(500), default="")
    price: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
