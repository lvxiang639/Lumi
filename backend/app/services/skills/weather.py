import json
import logging
import httpx
from app.services.skills.base import BaseSkill, SkillResult
from app.services.llm_service import llm_router

logger = logging.getLogger("weather_skill")

CITY_PROMPT = """从用户输入中提取城市名称，以JSON格式返回。如果用户没有指定具体城市，返回null。

返回格式: {{"city": "城市名"}}

用户输入: {user_input}
JSON:"""

DEFAULT_CITY = "Beijing"


class WeatherSkill(BaseSkill):
    name = "weather"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            city = await self._extract_city(user_input)
            logger.info("extracted city=%s from input=%s", city, user_input[:60])

            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"https://wttr.in/{city}?format=j1",
                    timeout=10,
                )
                resp.raise_for_status()
                data = resp.json()
                current = data["current_condition"][0]
                temp = current["temp_C"]
                desc = current["weatherDesc"][0]["value"]
                humidity = current.get("humidity", "")
                feels_like = current.get("FeelsLikeC", "")

                display_name = data.get("nearest_area", [{}])[0].get("areaName", [{}])[0].get("value", city)
                text = f"{display_name}当前温度{temp}度，{desc}"
                if humidity:
                    text += f"，湿度{humidity}%"
                if feels_like:
                    text += f"，体感温度{feels_like}度"

                return SkillResult(
                    text=text,
                    data={"city": display_name, "temp": temp, "desc": desc, "humidity": humidity},
                )
        except Exception:
            logger.exception("weather skill failed")
            return SkillResult(text="暂时无法获取天气信息，请稍后再试")

    async def _extract_city(self, user_input: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": CITY_PROMPT.format(user_input=user_input)},
            ])
            data = self._parse_json(raw)
            city = data.get("city") if data else None
            if city and isinstance(city, str) and city.strip():
                return city.strip()
        except Exception:
            logger.exception("city extraction failed")
        return DEFAULT_CITY

    def _parse_json(self, raw: str) -> dict | None:
        raw = raw.strip()
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        import re
        match = re.search(r'\{[^{}]*\}', raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
        return None


weather_skill = WeatherSkill()
