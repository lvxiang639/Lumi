import uuid
import logging

from app.services.skills.base import BaseSkill, SkillResult
from app.services.briefing_service import generate_briefing

logger = logging.getLogger("briefing_skill")


class BriefingSkill(BaseSkill):
    name = "briefing"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            uid = uuid.UUID(user_id)
            text = await generate_briefing(uid)
            if text:
                return SkillResult(text=text.strip())
            return SkillResult(text="今天还没有什么特别的安排，好好享受这一天吧~")
        except Exception:
            logger.exception("briefing skill failed")
            return SkillResult(text="简报生成失败，请稍后再试")


briefing_skill = BriefingSkill()
