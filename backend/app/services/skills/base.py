from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class SkillResult:
    text: str
    data: dict | None = None


class BaseSkill(ABC):
    name: str = ""

    @abstractmethod
    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        ...
