from app.services.skills.base import BaseSkill, SkillResult


class CalendarSkill(BaseSkill):
    name = "calendar"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        # Future: use LLM to extract time and title from user_input
        text = "日历提醒功能需要通过对话提取时间和事件信息"
        return SkillResult(text=text)


calendar_skill = CalendarSkill()
