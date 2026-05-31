import logging

import httpx

from app.config import settings

logger = logging.getLogger("location")

# Free IP geolocation — no API key required for non-commercial use
GEO_API_URL = "http://ip-api.com/json"


async def get_city_from_ip(client_ip: str | None = None) -> str:
    """Detect user's city from IP address. Falls back to Beijing."""
    try:
        async with httpx.AsyncClient() as client:
            if client_ip:
                resp = await client.get(f"{GEO_API_URL}/{client_ip}", timeout=5)
            else:
                resp = await client.get(GEO_API_URL, timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                city = data.get("city", "")
                if city:
                    logger.info("IP geolocation: %s, %s", city, data.get("country", ""))
                    return city
    except Exception:
        logger.exception("IP geolocation failed")
    return "Beijing"
