from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from app.core.logging import setup_logging
from app.api.auth import router as auth_router
from app.api.deps import get_current_user
import time, logging

setup_logging()
logger = logging.getLogger("main")
from app.api.characters import router as character_router
from app.api.conversations import router as conversation_router
from app.api.shop import router as shop_router
from app.api.calendar import router as calendar_router
from app.api.expenses import router as expense_router
from app.api.sync import router as sync_router
from app.api.tools import router as tools_router
from app.api.notes import router as notes_router
from app.api.ws_chat import router as ws_router
from app.api.countdown import router as countdown_router
from app.api.knowledge import router as knowledge_router
from app.api.study import router as study_router
from app.api.homophone import router as homophone_router
from app.api.agents import router as agents_router
from app.api.admin import router as admin_router

app = FastAPI(title="灵犀 API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request logging middleware ──
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = (time.time() - start) * 1000
    logger.info(f"{request.method:6} {response.status_code} {duration:6.0f}ms {request.url.path}")
    return response

app.include_router(auth_router)
app.include_router(character_router)
app.include_router(conversation_router)
app.include_router(shop_router)
app.include_router(calendar_router)
app.include_router(expense_router)
app.include_router(sync_router)
app.include_router(tools_router)
app.include_router(notes_router)
app.include_router(ws_router)
app.include_router(countdown_router)
app.include_router(knowledge_router)
app.include_router(admin_router)
app.include_router(agents_router)
app.include_router(study_router)
app.include_router(homophone_router)


@app.on_event("startup")
async def startup():
    from app.api.seed import seed_defaults
    await seed_defaults()
    from app.services.proactive_service import seed_daily_content_configs
    await seed_daily_content_configs()
    from app.services.notification_service import notification_service
    notification_service.start()
    from app.services.proactive_service import proactive_service
    proactive_service.start()
    # Pre-load OCR models in background
    import asyncio
    asyncio.create_task(_warmup_ocr())


async def _warmup_ocr():
    """Warm up OCR models in background after startup."""
    try:
        from app.services.ocr_service import ocr_service
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, ocr_service.warmup)
    except Exception:
        pass


@app.on_event("shutdown")
async def shutdown():
    from app.services.notification_service import notification_service
    await notification_service.stop()
    from app.services.proactive_service import proactive_service
    await proactive_service.stop()


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/discover/daily")
async def get_daily_content(
    current_user = Depends(get_current_user),
):
    """Return today's daily content for the discover page. Loads from DB."""
    import json
    from datetime import datetime, timezone, timedelta
    from app.database import async_session
    from sqlalchemy import select
    from app.models.daily_content import DailyContent

    # Use Beijing time for date consistency with generate_daily_content()
    beijing_tz = timezone(timedelta(hours=8))
    today = datetime.now(beijing_tz).date()
    async with async_session() as db:
        r = await db.execute(
            select(DailyContent).where(DailyContent.date == today)
        )
        row = r.scalar_one_or_none()
        if row and row.content:
            return {"date": str(row.date), "content": json.loads(row.content)}
        return {"date": str(today), "content": None}
