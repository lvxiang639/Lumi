"""SQLAlchemy implementation of UserRepository."""

from uuid import UUID
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.user import User
from app.models.user_memory import UserMemory
from app.models.emotion_state import UserEmotionState
from app.domain.repositories.user_repo import (
    UserRepository, UserEntity, MemoryEntity, EmotionEntity,
)


class SqlUserRepository(UserRepository):
    """SQLAlchemy-backed repository for User aggregate and related entities."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_by_id(self, user_id: UUID) -> UserEntity | None:
        r = await self.db.execute(select(User).where(User.id == user_id))
        row = r.scalar_one_or_none()
        return _to_user_entity(row) if row else None

    async def get_by_phone(self, phone: str) -> UserEntity | None:
        r = await self.db.execute(select(User).where(User.phone == phone))
        row = r.scalar_one_or_none()
        return _to_user_entity(row) if row else None

    async def get_by_email(self, email: str) -> UserEntity | None:
        r = await self.db.execute(select(User).where(User.email == email))
        row = r.scalar_one_or_none()
        return _to_user_entity(row) if row else None

    async def add(self, user: UserEntity) -> UserEntity:
        record = User(
            id=user.id,
            phone=user.phone or f"em_{user.email}"[:30] if user.email else "",
            email=user.email,
            nickname=user.nickname,
            hashed_password=user.hashed_password,
        )
        self.db.add(record)
        await self.db.flush()
        return _to_user_entity(record)

    async def get_memories(self, user_id: UUID, limit: int = 10) -> list[MemoryEntity]:
        r = await self.db.execute(
            select(UserMemory)
            .where(UserMemory.user_id == user_id)
            .order_by(UserMemory.updated_at.desc())
            .limit(limit)
        )
        return [_to_memory_entity(row) for row in r.scalars().all()]

    async def get_memory_count(self, user_id: UUID) -> int:
        r = await self.db.execute(
            select(func.count(UserMemory.id)).where(UserMemory.user_id == user_id)
        )
        return r.scalar() or 0

    async def get_emotion(self, user_id: UUID) -> EmotionEntity | None:
        r = await self.db.execute(
            select(UserEmotionState).where(UserEmotionState.user_id == user_id)
        )
        row = r.scalar_one_or_none()
        return _to_emotion_entity(row) if row else None


def _to_user_entity(row: User) -> UserEntity:
    return UserEntity(
        id=row.id, phone=row.phone or "", email=row.email,
        nickname=row.nickname or "", avatar_url=row.avatar_url or "",
        persona=row.persona or "小猫",
        hashed_password=row.hashed_password,
        last_briefing_date=row.last_briefing_date,
        created_at=row.created_at,
    )


def _to_memory_entity(row: UserMemory) -> MemoryEntity:
    return MemoryEntity(
        id=row.id, user_id=row.user_id, key=row.key, value=row.value or "",
        source_conv_id=row.source_conv_id,
        created_at=row.created_at, updated_at=row.updated_at,
    )


def _to_emotion_entity(row: UserEmotionState) -> EmotionEntity:
    return EmotionEntity(
        id=row.id, user_id=row.user_id,
        current_emotion=row.current_emotion or "",
        intensity=row.intensity or 0.0,
        updated_at=row.updated_at,
    )
