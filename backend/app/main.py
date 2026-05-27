from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.auth import router as auth_router
from app.api.characters import router as character_router

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


@app.on_event("startup")
async def startup():
    from app.api.seed import seed_defaults
    await seed_defaults()


@app.get("/health")
async def health():
    return {"status": "ok"}
