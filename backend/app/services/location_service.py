import logging

import httpx

from app.config import settings

logger = logging.getLogger("location")

GEO_API_URL = "http://ip-api.com/json"


async def get_city(
    client_ip: str | None = None,
    user_id: str | None = None,
) -> str:
    """Detect user's city with multi-layered fallback.

    1. Passed client_ip (X-Forwarded-For / X-Real-IP)
    2. Server IP geolocation (ip-api.com)
    3. User memory (LLM-extracted city from past conversations)
    4. Hard fallback: "Beijing"
    """

    # Layer 1: client IP from HTTP header
    if client_ip:
        city = await _geo_lookup(client_ip)
        if city:
            return city

    # Layer 2: server IP geolocation
    city = await _geo_lookup(None)
    if city and city != "Beijing":
        return city

    # Layer 3: user memory lookup
    if user_id:
        city = await _from_user_memory(user_id)
        if city:
            return city

    # Layer 4: hard fallback
    return "Beijing"


async def _geo_lookup(client_ip: str | None) -> str | None:
    try:
        async with httpx.AsyncClient() as client:
            url = f"{GEO_API_URL}/{client_ip}" if client_ip else GEO_API_URL
            resp = await client.get(url, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                city = data.get("city", "")
                if city:
                    logger.debug("IP geolocation: %s", city)
                    return city
    except Exception:
        pass
    return None


async def get_timezone(client_ip: str | None = None) -> str | None:
    """Get timezone string from IP address (e.g. 'Asia/Dubai', 'Asia/Shanghai')."""
    try:
        async with httpx.AsyncClient() as client:
            url = f"{GEO_API_URL}/{client_ip}" if client_ip else GEO_API_URL
            resp = await client.get(url, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                tz = data.get("timezone", "")
                if tz:
                    logger.debug("IP timezone: %s", tz)
                    return tz
    except Exception:
        pass
    return None


async def _from_user_memory(user_id: str) -> str | None:
    """Check if the user has mentioned their city in past conversations."""
    try:
        from uuid import UUID
        from app.database import async_session
        from sqlalchemy import select
        from app.models import UserMemory

        uid = UUID(user_id)
        async with async_session() as db:
            result = await db.execute(
                select(UserMemory).where(
                    UserMemory.user_id == uid,
                    UserMemory.key == "city",
                )
            )
            mem = result.scalar_one_or_none()
            if mem and mem.value:
                logger.info("User city from memory: %s", mem.value)
                return mem.value
    except Exception:
        pass
    return None
