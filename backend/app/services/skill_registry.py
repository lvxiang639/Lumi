from app.services.skills.base import BaseSkill
from app.services.skills.search import search_skill


class SkillRegistry:
    def __init__(self):
        self._skills: dict[str, BaseSkill] = {
            "search": search_skill,
        }

    def get(self, name: str) -> BaseSkill | None:
        return self._skills.get(name)

    def has(self, name: str) -> bool:
        return name in self._skills


skill_registry = SkillRegistry()
