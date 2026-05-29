import uuid
import logging
from datetime import datetime, timezone, timedelta

from app.models import ExpenseRecord
from app.services.skills.base import BaseSkill, SkillResult
from app.services.skills.utils import parse_json
from app.services.llm_service import llm_router

logger = logging.getLogger("expense_skill")

EXTRACTION_PROMPT = """从用户输入中提取记账信息，以JSON格式返回。
- amount: 金额数字。支出用正数（如50），收入用负数（如-100）。如果用户说的是"花了""用了""买了"等为支出，"收了""赚了""入账"为收入。
- category: 严格从以下选择：餐饮、交通、购物、娱乐、住房、医疗、教育、其他
- remark: 简短备注（≤20字）
- recorded_at: ISO8601时间字符串，如果用户没有指定具体时间则为null

返回格式: {{"amount": 50, "category": "餐饮", "remark": "午餐", "recorded_at": null}}

用户输入: {user_input}
JSON:"""

CATEGORIES = frozenset({"餐饮", "交通", "购物", "娱乐", "住房", "医疗", "教育", "其他"})
BEIJING_TZ = timezone(timedelta(hours=8))


class ExpenseSkill(BaseSkill):
    name = "expense"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            now = datetime.now(BEIJING_TZ)
            system_msg = (
                f"当前时间是{now.strftime('%Y-%m-%d %H:%M')}（北京时间）。"
                f"如果用户没有指定消费时间，recorded_at设为null。"
            )

            raw = await llm_router.chat([
                {"role": "system", "content": system_msg},
                {"role": "user", "content": EXTRACTION_PROMPT.format(user_input=user_input)},
            ])

            data = parse_json(raw)
            logger.info("extracted: %s", data)

            amount = data.get("amount")
            if amount is None:
                return SkillResult(
                    text='没能理解金额，可以说得更具体一点吗？比如"午餐花了50元"'
                )

            try:
                amount = float(amount)
            except (ValueError, TypeError):
                return SkillResult(text="金额格式不正确，请重新说明")

            if amount == 0:
                return SkillResult(text="金额不能为零，请重新说明")

            category = data.get("category", "其他") or "其他"
            if category not in CATEGORIES:
                category = "其他"

            remark = (data.get("remark") or "")[:500]

            recorded_at = now
            time_str = data.get("recorded_at")
            if time_str:
                try:
                    recorded_at = datetime.fromisoformat(time_str)
                    if recorded_at.tzinfo is None:
                        recorded_at = recorded_at.replace(tzinfo=BEIJING_TZ)
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
            text = f"已记录：{direction} {category} {abs(amount):.2f}元"
            if remark:
                text += f"，备注：{remark}"

            return SkillResult(text=text, data={
                "id": str(record.id),
                "amount": amount,
                "category": category,
            })

        except ValueError:
            logger.exception("expense skill value error")
            return SkillResult(text="数据格式不正确，请重新说明")
        except Exception:
            logger.exception("expense skill failed")
            return SkillResult(text="记账失败，请稍后再试")


expense_skill = ExpenseSkill()
