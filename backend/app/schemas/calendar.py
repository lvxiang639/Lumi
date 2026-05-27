from pydantic import BaseModel
from datetime import datetime


class CalendarEventItem(BaseModel):
    id: str
    title: str
    time: datetime
    repeat_rule: str
    notified: bool
    created_at: datetime
    updated_at: datetime


class CreateCalendarEvent(BaseModel):
    title: str
    time: datetime
    repeat_rule: str = "none"


class UpdateCalendarEvent(BaseModel):
    title: str | None = None
    time: datetime | None = None
    repeat_rule: str | None = None
