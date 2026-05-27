from sqlalchemy import select
from app.database import async_session
from app.models import Outfit, VoicePack


async def seed_defaults():
    async with async_session() as db:
        existing = await db.execute(select(Outfit).where(Outfit.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            db.add(Outfit(name="默认服装", model_file="default.model3.json", thumbnail="", price=0))
        existing = await db.execute(select(VoicePack).where(VoicePack.price == 0).limit(1))
        if existing.scalar_one_or_none() is None:
            db.add(VoicePack(name="默认女声", type="甜美", cosyvoice_id="default-female", price=0, preview_url=""))
        await db.commit()
