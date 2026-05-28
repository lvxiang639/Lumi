from typing import Literal
from pydantic import BaseModel, Field
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
    title: str = Field(max_length=200)
    time: datetime
    repeat_rule: Literal["none", "daily", "weekly", "monthly", "yearly"] = "none"


class UpdateCalendarEvent(BaseModel):
    title: str | None = Field(None, max_length=200)
    time: datetime | None = None
    repeat_rule: Literal["none", "daily", "weekly", "monthly", "yearly"] | None = None
