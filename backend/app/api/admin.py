"""Admin API — table browser, content manager, user manager."""

import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, text, inspect
from app.database import get_db
from app.models import User
from app.api.deps import get_current_user
from pathlib import Path

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/admin", tags=["admin"])


# ── Auth guard ──

async def admin_only(current_user: User = Depends(get_current_user)):
    """Restrict admin access (placeholder — extend with role check)."""
    return current_user


# ── Dashboard stats ──

@router.get("/stats")
async def dashboard_stats(
    _: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Dashboard overview."""
    tables = [
        "users", "conversations", "messages", "user_memories",
        "calendar_events", "expense_records", "notes", "mood_logs",
        "countdowns", "knowledge_bases", "proactive_pushes",
        "daily_content_configs",
    ]
    stats = {}
    for t in tables:
        try:
            r = await db.execute(text(f"SELECT COUNT(*) FROM {t}"))
            stats[t] = r.scalar() or 0
        except Exception:
            stats[t] = "N/A"
    return stats


# ── Table browser ──

@router.get("/tables/{table_name}")
async def browse_table(
    table_name: str,
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    _: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Browse any table rows."""
    allowed = {
        "users", "conversations", "messages", "calendar_events",
        "expense_records", "notes", "mood_logs", "countdowns",
        "knowledge_bases", "knowledge_chunks", "proactive_pushes",
        "daily_content_configs", "reminder_schedules", "user_memories",
        "user_emotion_states", "converted_files", "sent_emails",
    }
    if table_name not in allowed:
        raise HTTPException(400, f"Table not allowed: {table_name}")

    offset = (page - 1) * limit
    try:
        r = await db.execute(text(f"SELECT * FROM {table_name} ORDER BY created_at DESC NULLS LAST LIMIT {limit} OFFSET {offset}"))
    except Exception:
        r = await db.execute(text(f"SELECT * FROM {table_name} LIMIT {limit} OFFSET {offset}"))
    columns = list(r.keys())
    rows = []
    for row in r.fetchall():
        d = {}
        for i, col in enumerate(columns):
            val = row[i]
            if isinstance(val, UUID):
                val = str(val)[:8]
            elif hasattr(val, 'isoformat'):
                val = val.isoformat()
            d[col] = str(val) if val is not None else None
        rows.append(d)

    count_r = await db.execute(text(f"SELECT COUNT(*) FROM {table_name}"))
    total = count_r.scalar() or 0

    return {"columns": columns, "rows": rows, "total": total, "page": page, "limit": limit}


# ── Generic row CRUD ──

@router.delete("/tables/{table_name}/{row_id}")
async def delete_row(
    table_name: str, row_id: str,
    _: User = Depends(admin_only), db: AsyncSession = Depends(get_db),
):
    allowed = {"conversations","messages","calendar_events","expense_records","notes","mood_logs","countdowns","knowledge_chunks","proactive_pushes","daily_content_configs","reminder_schedules","user_memories","converted_files","sent_emails","knowledge_bases"}
    if table_name not in allowed: raise HTTPException(400, "Not allowed")
    try:
        uid = UUID(row_id)
        # Nullify FK refs before deleting conversations
        if table_name == "conversations":
            await db.execute(text("UPDATE user_memories SET source_conv_id = NULL WHERE source_conv_id = :id"), {"id": uid})
        await db.execute(text(f"DELETE FROM {table_name} WHERE id = :id"), {"id": uid})
    except Exception:
        if table_name == "conversations":
            await db.execute(text("UPDATE user_memories SET source_conv_id = NULL WHERE source_conv_id = :id"), {"id": row_id})
        await db.execute(text(f"DELETE FROM {table_name} WHERE id = :id"), {"id": row_id})
    await db.commit()
    return {"status": "deleted"}


@router.put("/tables/{table_name}/{row_id}")
async def update_row(
    table_name: str, row_id: str, body: dict,
    _: User = Depends(admin_only), db: AsyncSession = Depends(get_db),
):
    allowed = {"conversations","messages","calendar_events","expense_records","notes","mood_logs","countdowns","daily_content_configs","reminder_schedules","user_memories","converted_files","sent_emails","knowledge_bases"}
    if table_name not in allowed: raise HTTPException(400, "Not allowed")
    sets = ", ".join(f"{k} = :{k}" for k in body if k != "id")
    if not sets: raise HTTPException(400, "No fields to update")
    try:
        uid = UUID(row_id)
        await db.execute(text(f"UPDATE {table_name} SET {sets} WHERE id = :id"), {**body, "id": uid})
    except Exception:
        await db.execute(text(f"UPDATE {table_name} SET {sets} WHERE id = :id"), {**body, "id": row_id})
    await db.commit()
    return {"status": "updated"}


# ── Content configs CRUD ──

@router.get("/content-configs")
async def list_content_configs(
    _: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app.models.daily_content_config import DailyContentConfig
    r = await db.execute(select(DailyContentConfig).order_by(DailyContentConfig.priority))
    return {
        "items": [
            {"id": str(c.id), "content_type": c.content_type, "display_name": c.display_name,
             "prompt": c.prompt, "priority": c.priority, "enabled": c.enabled}
            for c in r.scalars().all()
        ]
    }


@router.put("/content-configs/{config_id}")
async def update_content_config(
    config_id: UUID,
    body: dict,
    _: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app.models.daily_content_config import DailyContentConfig
    r = await db.execute(select(DailyContentConfig).where(DailyContentConfig.id == config_id))
    cfg = r.scalar_one_or_none()
    if not cfg:
        raise HTTPException(404, "Not found")
    for key in ("display_name", "prompt", "priority", "enabled"):
        if key in body:
            setattr(cfg, key, body[key])
    await db.commit()
    return {"status": "updated"}


@router.post("/content-configs")
async def create_content_config(
    body: dict,
    _: User = Depends(admin_only),
    db: AsyncSession = Depends(get_db),
):
    from app.models.daily_content_config import DailyContentConfig
    cfg = DailyContentConfig(
        content_type=body.get("content_type", "custom"),
        display_name=body.get("display_name", ""),
        prompt=body.get("prompt", ""),
        priority=body.get("priority", 99),
        enabled=body.get("enabled", True),
    )
    db.add(cfg)
    await db.commit()
    await db.refresh(cfg)
    return {"id": str(cfg.id), "status": "created"}


# ── Serve admin static page ──

@router.get("/panel", response_class=HTMLResponse)
async def admin_panel():
    admin_html = Path(__file__).parent.parent.parent / "admin" / "index.html"
    if admin_html.exists():
        return admin_html.read_text(encoding="utf-8")
    return "<h1>Admin panel not found</h1>"
