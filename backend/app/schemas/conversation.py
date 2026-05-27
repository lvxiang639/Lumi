from pydantic import BaseModel
from datetime import datetime


class ConversationItem(BaseModel):
    id: str
    title: str
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
