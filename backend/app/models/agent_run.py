import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Text, func, Uuid, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base


class AgentRun(Base):
    __tablename__ = "agent_runs"

    id: Mapped[uuid.UUID] = mapped_column(Uuid, primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("users.id"), nullable=False, index=True)
    agent_id: Mapped[uuid.UUID] = mapped_column(Uuid, ForeignKey("user_agents.id", ondelete="CASCADE"), nullable=False)
    agent_name: Mapped[str] = mapped_column(String(100), default="")
    answers: Mapped[str] = mapped_column(Text, default="{}")  # JSON
    result: Mapped[str] = mapped_column(Text, default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
