import httpx
from app.services.skills.base import BaseSkill, SkillResult


class WeatherSkill(BaseSkill):
    name = "weather"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get("https://wttr.in/Beijing?format=j1", timeout=10)
                data = resp.json()
                current = data["current_condition"][0]
                temp = current["temp_C"]
                desc = current["weatherDesc"][0]["value"]
                text = f"北京当前温度{temp}度，{desc}"
                return SkillResult(text=text, data={"city": "北京", "temp": temp, "desc": desc})
        except Exception:
            return SkillResult(text="暂时无法获取天气信息，请稍后再试")


weather_skill = WeatherSkill()
