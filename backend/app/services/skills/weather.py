import asyncio
import logging
import httpx
from app.config import settings
from app.services.skills.base import BaseSkill, SkillResult
from app.services.skills.utils import parse_json
from app.services.llm_service import llm_router

logger = logging.getLogger("weather_skill")

CITY_PROMPT = """从用户输入中提取城市名称，以JSON格式返回。如果用户没有指定具体城市，返回null。

返回格式: {{"city": "城市名"}}

用户输入: {user_input}
JSON:"""

LLM_WEATHER_PROMPT = """请查询并提供以下城市的当前天气信息，包括温度、天气状况、湿度等：

{city}

请直接提供天气数据，格式清晰。"""

SUMMARIZE_PROMPT = """根据以下多来源信息，简洁地报告天气。综合API数据和大模型信息，以API数据为准。1-2句话即可。

用户问题: {user_input}

API天气数据:
{api_data}

大模型回答:
{llm_answer}

天气报告:"""


class WeatherSkill(BaseSkill):
    name = "weather"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            city = await self._extract_city(user_input)
            logger.info("extracted city=%s from input=%s", city, user_input[:60])

            # Parallel: weather API + LLM
            api_task = asyncio.create_task(self._fetch_weather(city))
            llm_task = asyncio.create_task(self._ask_llm(city))
            api_data, llm_answer = await asyncio.gather(api_task, llm_task)

            if api_data:
                # Format API data
                api_text = (
                    f"温度{api_data['temp']}度，{api_data['desc']}"
                    f"，湿度{api_data['humidity']}%，体感{api_data['feels_like']}度"
                )
                # Summarize with LLM answer
                summary = await self._summarize(user_input, api_text, llm_answer or "")
                text = summary if summary else f"{api_data['display']}当前{api_text}"
                return SkillResult(
                    text=text,
                    data={"city": api_data["display"], "temp": api_data["temp"],
                          "desc": api_data["desc"], "humidity": api_data["humidity"]},
                )
            elif llm_answer:
                return SkillResult(text=llm_answer.strip()[:300], data={"city": city})
            else:
                return SkillResult(text=f"未找到{city}的天气信息")
        except Exception:
            logger.exception("weather skill failed")
            return SkillResult(text="暂时无法获取天气信息，请稍后再试")

    async def _fetch_weather(self, city: str) -> dict | None:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{settings.weather_api_url}/{city}?format=j1",
                    timeout=10,
                )
                resp.raise_for_status()
                data = resp.json()
                current_cond = data.get("current_condition")
                if not current_cond:
                    return None
                current = current_cond[0]
                desc_list = current.get("weatherDesc", [])
                nearest = data.get("nearest_area", [{}])
                area_names = nearest[0].get("areaName", [{}]) if nearest else [{}]
                display_name = area_names[0].get("value", city) if area_names else city
                return {
                    "display": display_name,
                    "temp": current.get("temp_C", "?"),
                    "desc": desc_list[0].get("value", "") if desc_list else "",
                    "humidity": current.get("humidity", ""),
                    "feels_like": current.get("FeelsLikeC", ""),
                }
        except Exception:
            logger.exception("weather API failed")
            return None

    async def _ask_llm(self, city: str) -> str:
        try:
            return await llm_router.chat([
                {"role": "user", "content": LLM_WEATHER_PROMPT.format(city=city)},
            ])
        except Exception:
            logger.exception("llm weather failed")
            return ""

    async def _extract_city(self, user_input: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": CITY_PROMPT.format(user_input=user_input)},
            ])
            data = parse_json(raw)
            city = data.get("city") if data else None
            if city and isinstance(city, str) and city.strip():
                return city.strip()
        except Exception:
            logger.exception("city extraction failed")
        return "Beijing"

    async def _summarize(self, user_input: str, api_data: str, llm_answer: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": SUMMARIZE_PROMPT.format(
                    user_input=user_input, api_data=api_data, llm_answer=llm_answer,
                )},
            ])
            return raw.strip()
        except Exception:
            return ""


weather_skill = WeatherSkill()
