import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy import select
from app.main import app
from app.database import Base, get_db
from app.config import settings
from app.models import Outfit, VoicePack

TEST_DATABASE_URL = "sqlite+aiosqlite://"

@pytest_asyncio.fixture(scope="session", autouse=True)
async def setup_database():
    """Create tables, seed defaults, and override DB dependency for tests."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    test_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    # Seed default outfits and voice packs for test isolation
    async with test_session() as session:
        existing = await session.execute(select(Outfit).where(Outfit.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            session.add(Outfit(name="默认服装", model_file="default.model3.json", thumbnail="", price=0))
        existing = await session.execute(select(VoicePack).where(VoicePack.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            session.add(VoicePack(name="默认女声", type="甜美", cosyvoice_id="default-female", price=0, preview_url=""))
        await session.commit()

    async def get_test_db():
        async with test_session() as session:
            yield session

    app.dependency_overrides[get_db] = get_test_db

    yield

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()
    app.dependency_overrides.clear()

@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
