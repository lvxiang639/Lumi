"""User repository — abstracts user DB queries."""

from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.models.user_memory import UserMemory
from app.models.emotion_state import UserEmotionState


class UserRepository:
    """Repository for User aggregate root and related entities."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: UUID) -> User | None:
        r = await self.db.execute(select(User).where(User.id == user_id))
        return r.scalar_one_or_none()

    async def get_by_phone(self, phone: str) -> User | None:
        r = await self.db.execute(select(User).where(User.phone == phone))
        return r.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        r = await self.db.execute(select(User).where(User.email == email))
        return r.scalar_one_or_none()

    async def add(self, user: User) -> User:
        self.db.add(user)
        await self.db.flush()
        return user

    async def get_memories(self, user_id: UUID, limit: int = 10) -> list[UserMemory]:
        r = await self.db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(limit)
        )
        return list(r.scalars().all())

    async def get_memory_count(self, user_id: UUID) -> int:
        from sqlalchemy import func
        r = await self.db.execute(
            select(func.count(UserMemory.id)).where(UserMemory.user_id == user_id)
        )
        return r.scalar() or 0

    async def get_emotion(self, user_id: UUID) -> UserEmotionState | None:
        r = await self.db.execute(
            select(UserEmotionState).where(UserEmotionState.user_id == user_id)
        )
        return r.scalar_one_or_none()
