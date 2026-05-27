from pydantic import BaseModel
from datetime import datetime


class SyncAction(BaseModel):
    id: str
    action: str  # "create", "update", "delete"
    data: dict


class SyncRequest(BaseModel):
    events: list[SyncAction] = []
    expenses: list[SyncAction] = []
    last_sync_at: datetime


class SyncResponse(BaseModel):
    server_changes: dict
    sync_at: datetime
