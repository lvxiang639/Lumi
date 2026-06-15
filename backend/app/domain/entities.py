"""Domain entities for all aggregates — pure dataclasses, zero infrastructure deps."""

from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID


@dataclass
class CalendarEntity:
    id: UUID | None = None
    user_id: UUID | None = None
    title: str = ""
    time: datetime | None = None
    repeat_rule: str = ""
    notified: bool = False
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class ExpenseEntity:
    id: UUID | None = None
    user_id: UUID | None = None
    amount: float = 0.0
    category: str = ""
    remark: str = ""
    recorded_at: datetime | None = None
    created_at: datetime | None = None


@dataclass
class NoteEntity:
    id: UUID | None = None
    user_id: UUID | None = None
    title: str = ""
    content: str = ""
    note_type: str = "note"  # 'note' | 'diary' | 'mood'
    created_at: datetime | None = None
    updated_at: datetime | None = None


@dataclass
class CountdownEntity:
    id: UUID | None = None
    user_id: UUID | None = None
    title: str = ""
    target_date: datetime | None = None
    created_at: datetime | None = None
