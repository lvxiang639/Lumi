from fastapi import FastAPI, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from app.core.logging import setup_logging
import time, logging, asyncio

setup_logging()
logger = logging.getLogger("main")

# ── Routers (education-only) ──
from app.api.auth import router as auth_router
from app.api.conversations import router as conversation_router
from app.api.ws_chat import router as ws_router
from app.api.tools import router as tools_router
from app.api.knowledge import router as knowledge_router
from app.api.study import router as study_router
from app.api.homophone import router as homophone_router

app = FastAPI(title="灵犀教育 API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = (time.time() - start) * 1000
    logger.info(f"{request.method:6} {response.status_code} {duration:6.0f}ms {request.url.path}")
    return response

app.include_router(auth_router)
app.include_router(conversation_router)
app.include_router(ws_router)
app.include_router(tools_router)
app.include_router(knowledge_router)
app.include_router(study_router)
app.include_router(homophone_router)


@app.on_event("startup")
async def startup():
    from app.api.seed import seed_defaults
    await seed_defaults()
    # Pre-load OCR + BGE-M3 in background
    asyncio.create_task(_warmup_ocr())
    from app.services.memory_service import compute_missing_embeddings
    asyncio.create_task(compute_missing_embeddings())


async def _warmup_ocr():
    try:
        from app.services.ocr_service import ocr_service
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(None, ocr_service.warmup)
    except Exception:
        pass


@app.get("/health")
async def health():
    return {"status": "ok"}
