from app.services.skills.base import BaseSkill
from app.services.skills.weather import weather_skill
from app.services.skills.calendar_skill import calendar_skill
from app.services.skills.expense_skill import expense_skill
from app.services.skills.search import search_skill


class SkillRegistry:
    def __init__(self):
        self._skills: dict[str, BaseSkill] = {
            "weather": weather_skill,
            "calendar": calendar_skill,
            "expense": expense_skill,
            "search": search_skill,
        }

    def get(self, name: str) -> BaseSkill | None:
        return self._skills.get(name)


skill_registry = SkillRegistry()
