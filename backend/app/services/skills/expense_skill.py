import json
import uuid
import logging
from datetime import datetime, timezone, timedelta

from app.services.skills.base import BaseSkill, SkillResult
from app.services.llm_service import llm_router
from app.models import ExpenseRecord

logger = logging.getLogger("expense_skill")

EXTRACTION_PROMPT = """从用户输入中提取记账信息，以JSON格式返回。
- amount: 金额数字。支出用正数（如50），收入用负数（如-100）。如果用户说的是"花了""用了""买了"等为支出，"收了""赚了""入账"为收入。
- category: 严格从以下选择：餐饮、交通、购物、娱乐、住房、医疗、教育、其他
- remark: 简短备注（≤20字）
- recorded_at: ISO8601时间字符串，如果用户没有指定具体时间则为null

返回格式: {{"amount": 50, "category": "餐饮", "remark": "午餐", "recorded_at": null}}

用户输入: {user_input}
JSON:"""

CATEGORIES = ["餐饮", "交通", "购物", "娱乐", "住房", "医疗", "教育", "其他"]
BEIJING_TZ = timezone(timedelta(hours=8))


class ExpenseSkill(BaseSkill):
    name = "expense"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            now = datetime.now(BEIJING_TZ)
            system_msg = f"当前时间是{now.strftime('%Y-%m-%d %H:%M')}（北京时间）。如果用户没有指定消费时间，recorded_at设为null。"

            raw = await llm_router.chat([
                {"role": "system", "content": system_msg},
                {"role": "user", "content": EXTRACTION_PROMPT.format(user_input=user_input)},
            ])

            data = self._parse_json(raw)
            logger.info("extracted: %s", data)

            amount = data.get("amount")
            if amount is None:
                return SkillResult(text='没能理解金额，可以说得更具体一点吗？比如"午餐花了50元"')

            amount = float(amount)
            category = data.get("category", "其他") or "其他"
            if category not in CATEGORIES:
                category = "其他"

            remark = (data.get("remark") or "")[:500]

            recorded_at = now
            time_str = data.get("recorded_at")
            if time_str:
                try:
                    recorded_at = datetime.fromisoformat(time_str)
                except (ValueError, TypeError):
                    pass

            record = ExpenseRecord(
                user_id=uuid.UUID(user_id),
                amount=amount,
                category=category,
                remark=remark,
                recorded_at=recorded_at,
            )
            db.add(record)
            await db.commit()

            direction = "收入" if amount < 0 else "支出"
            abs_amount = abs(amount)
            text = f"已记录：{direction} {category} {abs_amount:.2f}元"
            if remark:
                text += f"，备注：{remark}"

            return SkillResult(text=text, data={
                "id": str(record.id),
                "amount": amount,
                "category": category,
            })

        except Exception:
            logger.exception("expense skill failed")
            return SkillResult(text="记账失败，请稍后再试")

    def _parse_json(self, raw: str) -> dict:
        raw = raw.strip()
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        if "```" in raw:
            lines = raw.split("\n")
            inside = False
            parts = []
            for line in lines:
                if "```" in line:
                    if inside:
                        break
                    inside = True
                    continue
                if inside:
                    parts.append(line)
            if parts:
                try:
                    return json.loads("\n".join(parts))
                except json.JSONDecodeError:
                    pass
        import re
        match = re.search(r'\{[^{}]*\}', raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
        return {}


expense_skill = ExpenseSkill()
