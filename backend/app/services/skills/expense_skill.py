from app.services.skills.base import BaseSkill, SkillResult


class ExpenseSkill(BaseSkill):
    name = "expense"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        # Future: use LLM to extract amount, category, remark from user_input
        text = "记账功能需要通过对话提取金额和类别信息"
        return SkillResult(text=text)


expense_skill = ExpenseSkill()
