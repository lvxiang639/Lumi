"""SQLAlchemy implementations of Calendar, Expense, Note, Countdown repositories."""

from uuid import UUID
from sqlalchemy import select, func, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models import CalendarEvent, ExpenseRecord
from app.models.note import Note
from app.models.countdown import Countdown
from app.domain.entities import CalendarEntity, ExpenseEntity, NoteEntity, CountdownEntity
from app.domain.repositories.base import CalendarRepository, ExpenseRepository, NoteRepository, CountdownRepository


class SqlCalendarRepository(CalendarRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_by_user(self, user_id: UUID) -> list[CalendarEntity]:
        r = await self.db.execute(
            select(CalendarEvent).where(CalendarEvent.user_id == user_id)
            .order_by(CalendarEvent.time.desc())
        )
        return [_cal_to_entity(row) for row in r.scalars().all()]

    async def get_by_id(self, event_id: UUID, user_id: UUID) -> CalendarEntity | None:
        r = await self.db.execute(
            select(CalendarEvent).where(CalendarEvent.id == event_id, CalendarEvent.user_id == user_id)
        )
        row = r.scalar_one_or_none()
        return _cal_to_entity(row) if row else None

    async def add(self, entity: CalendarEntity) -> CalendarEntity:
        record = CalendarEvent(user_id=entity.user_id, title=entity.title, time=entity.time, repeat_rule=entity.repeat_rule)
        self.db.add(record)
        await self.db.flush()
        return _cal_to_entity(record)

    async def update(self, entity: CalendarEntity) -> CalendarEntity:
        r = await self.db.execute(select(CalendarEvent).where(CalendarEvent.id == entity.id, CalendarEvent.user_id == entity.user_id))
        record = r.scalar_one_or_none()
        if not record: raise ValueError("not found")
        if entity.title: record.title = entity.title
        if entity.time: record.time = entity.time
        record.repeat_rule = entity.repeat_rule
        await self.db.flush()
        return _cal_to_entity(record)

    async def delete(self, event_id: UUID, user_id: UUID) -> bool:
        r = await self.db.execute(delete(CalendarEvent).where(CalendarEvent.id == event_id, CalendarEvent.user_id == user_id))
        await self.db.commit()
        return r.rowcount > 0


class SqlExpenseRepository(ExpenseRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_by_user(self, user_id: UUID) -> list[ExpenseEntity]:
        r = await self.db.execute(
            select(ExpenseRecord).where(ExpenseRecord.user_id == user_id).order_by(ExpenseRecord.recorded_at.desc())
        )
        return [_exp_to_entity(row) for row in r.scalars().all()]

    async def get_by_id(self, expense_id: UUID, user_id: UUID) -> ExpenseEntity | None:
        r = await self.db.execute(select(ExpenseRecord).where(ExpenseRecord.id == expense_id, ExpenseRecord.user_id == user_id))
        row = r.scalar_one_or_none()
        return _exp_to_entity(row) if row else None

    async def add(self, entity: ExpenseEntity) -> ExpenseEntity:
        record = ExpenseRecord(user_id=entity.user_id, amount=entity.amount, category=entity.category, remark=entity.remark, recorded_at=entity.recorded_at)
        self.db.add(record)
        await self.db.flush()
        return _exp_to_entity(record)

    async def update(self, entity: ExpenseEntity) -> ExpenseEntity:
        r = await self.db.execute(select(ExpenseRecord).where(ExpenseRecord.id == entity.id, ExpenseRecord.user_id == entity.user_id))
        record = r.scalar_one_or_none()
        if not record: raise ValueError("not found")
        if entity.amount: record.amount = entity.amount
        if entity.category: record.category = entity.category
        record.remark = entity.remark
        await self.db.flush()
        return _exp_to_entity(record)

    async def delete(self, expense_id: UUID, user_id: UUID) -> bool:
        r = await self.db.execute(delete(ExpenseRecord).where(ExpenseRecord.id == expense_id, ExpenseRecord.user_id == user_id))
        await self.db.commit()
        return r.rowcount > 0

    async def get_stats(self, user_id: UUID, since: str, until: str) -> dict:
        r = await self.db.execute(
            select(ExpenseRecord.category, func.sum(ExpenseRecord.amount))
            .where(ExpenseRecord.user_id == user_id, ExpenseRecord.recorded_at >= since, ExpenseRecord.recorded_at < until)
            .group_by(ExpenseRecord.category)
        )
        return {row[0]: float(row[1]) for row in r.all()}

    async def get_weekly_insights(self, user_id: UUID) -> dict:
        from app.domain.expense.service import ExpenseService
        return await ExpenseService.get_weekly_insights(user_id, self.db, None)


class SqlNoteRepository(NoteRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_by_user(self, user_id: UUID, note_type: str | None = None) -> list[NoteEntity]:
        q = select(Note).where(Note.user_id == user_id).order_by(Note.updated_at.desc())
        if note_type: q = q.where(Note.note_type == note_type)
        r = await self.db.execute(q)
        return [_note_to_entity(row) for row in r.scalars().all()]

    async def get_by_id(self, note_id: UUID, user_id: UUID) -> NoteEntity | None:
        r = await self.db.execute(select(Note).where(Note.id == note_id, Note.user_id == user_id))
        row = r.scalar_one_or_none()
        return _note_to_entity(row) if row else None

    async def add(self, entity: NoteEntity) -> NoteEntity:
        record = Note(user_id=entity.user_id, title=entity.title, content=entity.content, note_type=entity.note_type)
        self.db.add(record)
        await self.db.flush()
        return _note_to_entity(record)

    async def update(self, entity: NoteEntity) -> NoteEntity:
        r = await self.db.execute(select(Note).where(Note.id == entity.id, Note.user_id == entity.user_id))
        record = r.scalar_one_or_none()
        if not record: raise ValueError("not found")
        if entity.title: record.title = entity.title
        if entity.content: record.content = entity.content
        await self.db.flush()
        return _note_to_entity(record)

    async def delete(self, note_id: UUID, user_id: UUID) -> bool:
        r = await self.db.execute(delete(Note).where(Note.id == note_id, Note.user_id == user_id))
        await self.db.commit()
        return r.rowcount > 0


class SqlCountdownRepository(CountdownRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_by_user(self, user_id: UUID) -> list[CountdownEntity]:
        r = await self.db.execute(select(Countdown).where(Countdown.user_id == user_id).order_by(Countdown.created_at.desc()))
        return [_cd_to_entity(row) for row in r.scalars().all()]

    async def add(self, entity: CountdownEntity) -> CountdownEntity:
        record = Countdown(user_id=entity.user_id, title=entity.title, target_date=entity.target_date)
        self.db.add(record)
        await self.db.flush()
        return _cd_to_entity(record)

    async def delete(self, countdown_id: UUID, user_id: UUID) -> bool:
        r = await self.db.execute(delete(Countdown).where(Countdown.id == countdown_id, Countdown.user_id == user_id))
        await self.db.commit()
        return r.rowcount > 0


# ── Entity mappers ──

def _cal_to_entity(row: CalendarEvent) -> CalendarEntity:
    return CalendarEntity(id=row.id, user_id=row.user_id, title=row.title, time=row.time, repeat_rule=row.repeat_rule or "", notified=row.notified, created_at=row.created_at, updated_at=row.updated_at)

def _exp_to_entity(row: ExpenseRecord) -> ExpenseEntity:
    return ExpenseEntity(id=row.id, user_id=row.user_id, amount=float(row.amount), category=row.category or "", remark=row.remark or "", recorded_at=row.recorded_at, created_at=row.created_at)

def _note_to_entity(row: Note) -> NoteEntity:
    return NoteEntity(id=row.id, user_id=row.user_id, title=row.title or "", content=row.content or "", note_type=row.note_type or "note", created_at=row.created_at, updated_at=row.updated_at)

def _cd_to_entity(row: Countdown) -> CountdownEntity:
    return CountdownEntity(id=row.id, user_id=row.user_id, title=row.title or "", target_date=row.target_date, created_at=row.created_at)
