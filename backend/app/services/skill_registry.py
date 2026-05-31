from app.services.skills.base import BaseSkill
from app.services.skills.weather import weather_skill
from app.services.skills.calendar_skill import calendar_skill
from app.services.skills.expense_skill import expense_skill
from app.services.skills.search import search_skill
from app.services.skills.convert_skill import convert_skill
from app.services.skills.briefing_skill import briefing_skill


class SkillRegistry:
    def __init__(self):
        self._skills: dict[str, BaseSkill] = {
            "weather": weather_skill,
            "calendar": calendar_skill,
            "expense": expense_skill,
            "search": search_skill,
            "convert": convert_skill,
            "briefing": briefing_skill,
        }

    def get(self, name: str) -> BaseSkill | None:
        return self._skills.get(name)

    def has(self, name: str) -> bool:
        return name in self._skills


skill_registry = SkillRegistry()
