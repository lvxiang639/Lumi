from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.auth import router as auth_router
from app.api.characters import router as character_router
from app.api.conversations import router as conversation_router
from app.api.shop import router as shop_router
from app.api.calendar import router as calendar_router
from app.api.expenses import router as expense_router
from app.api.sync import router as sync_router
from app.api.ws_chat import router as ws_router

app = FastAPI(title="灵犀 API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(character_router)
app.include_router(conversation_router)
app.include_router(shop_router)
app.include_router(calendar_router)
app.include_router(expense_router)
app.include_router(sync_router)
app.include_router(ws_router)


@app.on_event("startup")
async def startup():
    from app.api.seed import seed_defaults
    await seed_defaults()


@app.get("/health")
async def health():
    return {"status": "ok"}
