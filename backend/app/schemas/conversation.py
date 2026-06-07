from pydantic import BaseModel
from datetime import datetime


class ConversationItem(BaseModel):
    id: str
    title: str
    last_message: str | None = None
    created_at: datetime
    updated_at: datetime


class MessageItem(BaseModel):
    id: str
    role: str
    type: str
    content: str
    audio_url: str
    created_at: datetime


class UpdateTitleRequest(BaseModel):
    title: str
