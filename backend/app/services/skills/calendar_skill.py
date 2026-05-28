import json
import uuid
import logging
from datetime import datetime, timezone, timedelta

from app.services.skills.base import BaseSkill, SkillResult
from app.services.llm_service import llm_router
from app.models import CalendarEvent

logger = logging.getLogger("calendar_skill")

EXTRACTION_PROMPT = """从用户输入中提取日历事件信息，以JSON格式返回。
- time: ISO8601格式的日期时间字符串。如果用户说的是相对时间（如"明天下午3点"、"下周一下午2点"），请基于当前时间推算。
- repeat_rule: 严格从 none/daily/weekly/monthly/yearly 中选择。
- 如果某个字段无法确定，对应值设为null。

返回格式: {{"title": "事件标题", "time": "ISO8601时间", "repeat_rule": "none"}}

用户输入: {user_input}
JSON:"""

# Beijing timezone for relative time calculations
BEIJING_TZ = timezone(timedelta(hours=8))


class CalendarSkill(BaseSkill):
    name = "calendar"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            # Get current time hint for the LLM
            now = datetime.now(BEIJING_TZ)
            prompt = EXTRACTION_PROMPT.format(user_input=user_input)
            system_msg = f"当前时间是{now.strftime('%Y-%m-%d %H:%M:%S')}（北京时间，星期{['一','二','三','四','五','六','日'][now.weekday()]}）。请基于此时间推算相对时间。"

            raw = await llm_router.chat([
                {"role": "system", "content": system_msg},
                {"role": "user", "content": prompt},
            ])

            # Extract JSON from response
            data = self._parse_json(raw)
            logger.info("extracted: %s", data)

            title = data.get("title")
            if not title:
                return SkillResult(text='没能理解你想提醒什么，可以说得更具体一点吗？比如"提醒我明天下午3点开会"')

            time_str = data.get("time")
            if not time_str:
                return SkillResult(text='没能理解提醒时间，可以说得更具体一点吗？比如"明天下午3点"')

            event_time = datetime.fromisoformat(time_str)
            repeat_rule = data.get("repeat_rule", "none") or "none"
            if repeat_rule not in ("none", "daily", "weekly", "monthly", "yearly"):
                repeat_rule = "none"

            event = CalendarEvent(
                user_id=uuid.UUID(user_id),
                title=title,
                time=event_time,
                repeat_rule=repeat_rule,
            )
            db.add(event)
            await db.commit()

            time_display = event_time.strftime("%m月%d日 %H:%M")
            repeat_hint = {"daily": "每天", "weekly": "每周", "monthly": "每月", "yearly": "每年"}.get(repeat_rule, "")
            text = f"已添加日历提醒：{title}，时间{time_display}"
            if repeat_hint:
                text += f"，{repeat_hint}重复"

            return SkillResult(text=text, data={"event_id": str(event.id)})

        except Exception:
            logger.exception("calendar skill failed")
            return SkillResult(text="添加日历提醒失败，请稍后再试")

    def _parse_json(self, raw: str) -> dict:
        raw = raw.strip()
        # Try direct parse
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        # Try to extract JSON block from markdown code fence
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
        # Try to find JSON object in text
        import re
        match = re.search(r'\{[^{}]*\}', raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
        return {}


calendar_skill = CalendarSkill()
