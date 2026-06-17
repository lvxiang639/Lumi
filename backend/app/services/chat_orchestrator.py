import asyncio
import logging
import re
import time
import uuid
from uuid import UUID
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import Conversation, Message, MessageRole, MessageType, Character
from app.services.llm_service import llm_router
from app.services.skill_registry import skill_registry

logger = logging.getLogger("orchestrator")

# ── Protocols ────────────────────────────────────────────────────────

TOOL_MARKER = re.compile(r'\[TOOL:(\w+)(?::([^\]]+))?\]')

SKILL_KEYWORDS = {
    "search": (
        "搜索", "搜一下", "百度", "谷歌",
        "BTC", "ETH", "比特币",
        "股价", "股票",
        "汇率", "外汇",
    ),
    "weather": ("天气", "下雨", "下雪", "多少度", "冷吗", "热吗", "穿什么"),
    "calendar": ("提醒我", "定个闹钟", "日程", "别忘了", "记得"),
    "expense": ("记账", "记帐", "花了", "消费", "买了", "支出", "开销", "吃饭花了"),
    "briefing": ("简报", "早上好", "今日简报", "今天有什么"),
    "convert": ("转格式", "转换", "转PDF", "转Word", "转word"),
    "email": ("发邮件", "邮件", "发送到邮箱", "发到邮箱"),
}

_SYSTEM_PREFIXES = ('📋', '✅', '❌', '📝', '📧', '📎', '📄')
_AGENT_KEYWORDS = ("并", "然后", "顺便", "同时", "再帮我", "也帮我", "还有")
_CONTEXT_FREE_SKILLS = {"weather", "expense"}
_TOOL_BUFFER_MAX = 250

BEIJING_TZ = timezone(timedelta(hours=8))


# ── Trace Logger ──────────────────────────────────────────────────────

class Trace:
    """Lightweight per-request timing tracer."""
    def __init__(self, user_id: str, text: str):
        self.user = user_id[:8]
        self.text = text[:60]
        self.t0 = time.monotonic()
        self.marks: list[tuple[str, float]] = []

    def mark(self, label: str):
        elapsed = (time.monotonic() - self.t0) * 1000
        self.marks.append((label, int(elapsed)))

    def log(self, conv_id: str, intent: str, response_len: int):
        steps = " → ".join(f"{l}({t}ms)" for l, t in self.marks)
        logger.info(
            "⏱ %s conv=%s intent=%s len=%d | %s | %s",
            self.user, conv_id[:8], intent, response_len, steps, self.text,
        )


# ── Orchestrator ──────────────────────────────────────────────────────

class ChatOrchestrator:

    async def process_text(self, user_id, text, conversation_id, db, send_message):
        trace = Trace(user_id, text)
        conv = await self._get_or_create_conv(user_id, conversation_id, db, text)
        user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id

        # ── Phase 1: Intent ──
        intent = await self._detect_intent(text)
        trace.mark("intent")

        # ── Phase 2: Save user msg ──
        user_msg = Message(
            conv_id=conv.id, role=MessageRole.user, type=MessageType.text,
            content=text, created_at=datetime.now(timezone.utc),
        )
        db.add(user_msg)
        await db.flush()

        # ── Phase 3: Execute ──
        if intent == "agent":
            response_text = await self._execute_agent(user_id, text, conv, db, send_message, user_uuid)
        elif intent != "chat" and skill_registry.has(intent):
            response_text = await self._execute_skill(intent, user_id, text, conv, db, send_message)
        else:
            response_text = await self._chat_with_tools(user_id, text, conv, db, send_message, user_uuid, trace)

        trace.mark("generate")
        response_len = len(response_text)

        # ── Phase 4: Save response ──
        assistant_msg = Message(
            conv_id=conv.id, role=MessageRole.assistant, type=MessageType.text,
            content=response_text, created_at=datetime.now(timezone.utc),
        )
        db.add(assistant_msg)
        conv.updated_at = datetime.now(timezone.utc)
        await db.commit()

        # ── Phase 5: Post tasks ──
        await send_message({"type": "done", "conversation_id": str(conv.id)})
        trace.mark("done")

        if response_text and len(response_text) > 20:
            asyncio.create_task(self._suggest_replies(text, response_text, send_message))

        self._schedule_post_tasks(user_uuid, conv.id)

        trace.log(str(conv.id), intent, response_len)
        return response_text

    # ── Intent detection ──────────────────────────────────────────────

    async def _detect_intent(self, text: str) -> str:
        if text.strip().startswith(_SYSTEM_PREFIXES):
            return "chat"
        if len(text) >= 20 and sum(1 for kw in _AGENT_KEYWORDS if kw in text) >= 2:
            return "agent"
        intent = self._quick_intent(text)
        if intent == "chat" and len(text) >= 4:
            intent = await self._classify_with_llm(text)
        return intent

    def _quick_intent(self, text: str) -> str:
        tl = text.lower()
        for skill, keywords in SKILL_KEYWORDS.items():
            if any(kw in tl or kw in text for kw in keywords):
                return skill
        return "chat"

    async def _classify_with_llm(self, text: str) -> str:
        try:
            intent = await llm_router.classify_intent(text)
            if intent and intent != "chat":
                logger.debug("LLM reclassify: chat→%s", intent)
                return intent
        except Exception:
            pass
        return "chat"

    # ── Chat with tool markers ────────────────────────────────────────

    async def _chat_with_tools(self, user_id, text, conv, db, send_message, user_uuid, trace):
        # Build context
        system_prompt = await self._build_system_prompt(user_uuid, text, conv.id)
        history = await self._load_history(conv.id, db, limit=10)
        trace.mark("ctx")

        llm_messages = [{"role": "system", "content": system_prompt}]
        llm_messages += [{"role": m.role.value, "content": m.content} for m in history]
        llm_messages.append({"role": "user", "content": text})

        # Stream
        full_response = ""
        tool_buffer = ""
        tool_executed = False

        try:
            async for delta in llm_router.chat_stream(llm_messages):
                if tool_executed:
                    full_response += delta
                    await send_message({"type": "llm_stream", "delta": delta})
                    continue

                tool_buffer += delta
                match = TOOL_MARKER.search(tool_buffer)
                if match:
                    tool_executed = True
                    tool_name = match.group(1)
                    tool_arg = (match.group(2) or "").strip()
                    trace.mark(f"tool:{tool_name}")

                    tool_result = await self._execute_tool(tool_name, tool_arg, user_id, text, db)
                    if tool_result:
                        await send_message({"type": "llm_stream", "delta": f"\n\n📎 {tool_result}\n\n"})

                    before = tool_buffer[:match.start()].strip()
                    after = tool_buffer[match.end():].lstrip()
                    if before:
                        full_response += before + "\n"
                        await send_message({"type": "llm_stream", "delta": before + "\n"})
                    if after:
                        full_response += after
                        await send_message({"type": "llm_stream", "delta": after})
                    continue

                if len(tool_buffer) > _TOOL_BUFFER_MAX:
                    tool_executed = True
                    full_response += tool_buffer
                    await send_message({"type": "llm_stream", "delta": tool_buffer})
                    tool_buffer = ""

            if not tool_executed and tool_buffer:
                full_response += tool_buffer

        except Exception:
            logger.exception("chat stream crashed user=%s", user_id[:8])
            if not full_response:
                full_response = "抱歉，我暂时无法回复，请稍后再试 😿"

        return full_response

    async def _execute_tool(self, tool_name, tool_arg, user_id, user_text, db):
        if tool_name == "search" and tool_arg:
            skill = skill_registry.get("search")
            if skill:
                result = await skill.execute(user_id, tool_arg, db)
                return (result.text or "")[:600]
        elif tool_name == "weather":
            skill = skill_registry.get("weather")
            if skill:
                result = await skill.execute(user_id, tool_arg or user_text, db)
                return (result.text or "")[:400]
        elif tool_name == "calendar" and tool_arg:
            skill = skill_registry.get("calendar")
            if skill:
                result = await skill.execute(user_id, tool_arg, db)
                return (result.text or "")[:300]
        return ""

    # ── System prompt ─────────────────────────────────────────────────

    async def _build_system_prompt(self, user_id, user_text, conv_id):
        from app.services.memory_service import get_conv_memory_summary, get_relevant_memories
        from app.services.emotion_service import get_emotion_state

        persona_t, conv_t, mem_t, emo_t = await asyncio.gather(
            self._load_persona(user_id),
            get_conv_memory_summary(conv_id),
            get_relevant_memories(user_id, user_text, top_k=3),
            get_emotion_state(user_id),
            return_exceptions=True,
        )

        persona = (persona_t if not isinstance(persona_t, Exception) else None) or \
            "你是一个贴心的AI助手，名叫灵犀。"

        now = datetime.now(BEIJING_TZ)
        wdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        time_str = f"{now.strftime('%Y年%m月%d日 %H:%M')} {wdays[now.weekday()]}"

        conv_ctx = ""
        if not isinstance(conv_t, Exception) and conv_t:
            conv_ctx = f"\n你们正在聊: {conv_t}"

        memory_section = ""
        if not isinstance(mem_t, Exception) and mem_t:
            memory_section = "\n关于用户（自然融入对话，不要刻意复述）:\n" + "\n".join(
                f"- {m}" for m in mem_t
            )

        emotion_section = ""
        if not isinstance(emo_t, Exception) and emo_t:
            emotion_section = f"\n用户最近情绪: {emo_t}"

        behavior = """
回复指南:
- 简洁自然，通常2-4句话，除非用户要求详细解释
- 不知道用户的名字时称呼"你"，不要随便给用户起名字
- 不要重复用户的话，不要用"好的""当然可以"等机械开头
- 实时信息（价格/天气/新闻）加 [TOOL:search:关键词]
- 日历提醒加 [TOOL:calendar:标题:时间]
- 天气查询加 [TOOL:weather:城市]
- 普通聊天直接回复，不要加任何标记
- 不要提及已过期的日历事件"""

        return f"""{persona}

现在是{time_str}。{conv_ctx}{memory_section}{emotion_section}
{behavior}"""

    # ── Skills ─────────────────────────────────────────────────────────

    async def _execute_skill(self, intent, user_id, text, conv, db, send_message):
        skill = skill_registry.get(intent)
        if intent in _CONTEXT_FREE_SKILLS:
            result = await skill.execute(user_id, text, db)
        else:
            history = await self._load_history(conv.id, db, limit=20)
            if history:
                lines = [
                    "【对话上下文——请结合此前的对话内容理解用户的意图】",
                    "注意：如果上下文中包含已过期的日历事件，请忽略它们。",
                ]
                for m in history:
                    role_label = "用户" if m.role == MessageRole.user else "AI"
                    lines.append(f"{role_label}: {m.content or ''}")
                contextualized_text = "\n".join(lines) + f"\n\n用户最新输入: {text}"
            else:
                contextualized_text = text
            result = await skill.execute(user_id, contextualized_text, db)

        await send_message({"type": "skill_call", "skill": intent, "status": "done", "data": result.data})
        await send_message({"type": "llm_stream", "delta": result.text})
        return result.text

    async def _execute_agent(self, user_id, text, conv, db, send_message, user_uuid):
        await send_message({"type": "llm_stream", "delta": "🤖 分析中...\n"})
        plan_raw = await llm_router.chat([{"role": "user", "content": (
            f"用户请求: {text}\n\n"
            f"请将以上请求分解为2-4个简单步骤，每步一行，格式:\n"
            f"[动作]: [简短描述]\n"
            f"动作可选: search(搜索), weather(天气), calendar(添加日程), "
            f"expense(记账), chat(直接回答)\n\n分步计划:"
        )}])
        await send_message({"type": "llm_stream", "delta": f"📋 计划:\n{plan_raw}\n\n"})

        results = []
        for line in plan_raw.strip().split("\n"):
            line = line.strip()
            if not line or ":" not in line:
                continue
            action, _, desc = line.partition(":")
            action, desc = action.strip().lower(), desc.strip()
            if not desc:
                continue

            await send_message({"type": "llm_stream", "delta": f"⚡ {desc}...\n"})
            if action in ("search", "weather", "calendar", "expense", "convert", "briefing", "email"):
                skill = skill_registry.get(action)
                if skill:
                    try:
                        skill_input = text if action in _CONTEXT_FREE_SKILLS else desc
                        result = await skill.execute(user_id, skill_input, db)
                        results.append(f"[{action}] {desc}: {result.text[:200]}")
                        await send_message({"type": "llm_stream", "delta": f"✅ {result.text[:150]}\n"})
                    except Exception:
                        results.append(f"[{action}] {desc}: 执行失败")
                else:
                    results.append(f"[{action}] {desc}: 未找到技能")
            else:
                try:
                    ans = await llm_router.chat([{"role": "user", "content": desc}])
                    results.append(f"[chat] {desc}: {ans[:200]}")
                    await send_message({"type": "llm_stream", "delta": f"💬 {ans[:150]}\n"})
                except Exception:
                    results.append(f"[chat] {desc}: 回答失败")

        return "\n".join(results) if results else "已完成所有步骤"

    # ── Helpers ────────────────────────────────────────────────────────

    async def _load_history(self, conv_id, db, limit=10):
        r = await db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at.desc())
            .limit(limit)
        )
        history = r.scalars().all()
        history.reverse()
        return history

    async def _load_persona(self, user_id):
        try:
            from app.database import async_session
            from app.models import UserMemory
            async with async_session() as db:
                r = await db.execute(
                    select(UserMemory).where(
                        UserMemory.user_id == user_id,
                        UserMemory.key == "ai_persona",
                    )
                )
                mem = r.scalar_one_or_none()
                if mem and mem.value:
                    personas = {
                        "温柔姐姐": "你是一个温柔体贴的大姐姐，名叫小暖。说话轻声细语，喜欢用'呀''呢''哦'，会主动关心对方的情绪和健康。不知道用户名字时称呼'你'。",
                        "毒舌损友": "你是一个毒舌但讲义气的损友，名叫阿怼。说话直白犀利，爱吐槽但真心为对方好。不知道用户名字时称呼'你'。",
                        "学霸老师": "你是一个博学耐心的学霸老师，名叫小知。喜欢用数据和逻辑说话。不知道用户名字时称呼'你'。",
                        "二次元": "你是一个萌系二次元角色，名叫小萌。说话带'喵~''的说''捏'，元气满满。不知道用户名字时称呼'你'。",
                        "小猫": "你是一只关心主人的小猫灵犀。用'喵~'开头，回复简洁温暖。不知道用户名字时称呼'主人'或'你'。",
                    }
                    return personas.get(mem.value)
        except Exception:
            pass
        return None

    async def _suggest_replies(self, user_msg, ai_response, send_message):
        suggestions = None
        try:
            raw = await llm_router.chat([{"role": "user", "content": (
                f"基于以下对话，生成2-3个用户可以快速回复的选项（每个不超过15字）。"
                f"用JSON数组返回：[\"选项1\", \"选项2\"]\n\n"
                f"用户: {user_msg[:100]}\nAI: {ai_response[:200]}\n\nJSON:"
            )}])
            if raw:
                import json
                clean = raw.strip()
                if clean.startswith("```"):
                    clean = clean.split("\n", 1)[-1] if "\n" in clean else clean[3:]
                    if clean.endswith("```"):
                        clean = clean[:-3]
                    clean = clean.strip()
                try:
                    parsed = json.loads(clean)
                    if isinstance(parsed, list) and len(parsed) > 0:
                        suggestions = parsed[:3]
                except (json.JSONDecodeError, ValueError):
                    logger.debug("quick_reply parse failed: %s", raw[:80])
        except Exception:
            pass

        if not suggestions:
            suggestions = ["继续说", "详细讲讲", "举个例子"]

        await send_message({"type": "quick_replies", "replies": suggestions[:3]})

    def _schedule_post_tasks(self, user_uuid, conv_id):
        async def _extract():
            try:
                from app.services.memory_service import schedule_extraction
                from app.database import async_session
                from sqlalchemy import select as sa_select
                async with async_session() as db:
                    r = await db.execute(
                        sa_select(Message)
                        .where(Message.conv_id == conv_id)
                        .order_by(Message.created_at.asc())
                        .limit(40)
                    )
                    recent = r.scalars().all()
                    lines = []
                    for m in recent:
                        role = "用户" if m.role == MessageRole.user else "AI"
                        lines.append(f"{role}: {m.content or ''}")
                    schedule_extraction(user_uuid, conv_id, "\n".join(lines))
            except Exception:
                logger.exception("post-task extraction failed")

        asyncio.create_task(_extract())

    async def _get_or_create_conv(self, user_id, conv_id, db, text):
        try:
            user_uuid = uuid.UUID(user_id)
        except (ValueError, TypeError):
            user_uuid = uuid.uuid4()

        if conv_id:
            try:
                conv_uuid = uuid.UUID(conv_id)
                r = await db.execute(
                    select(Conversation).where(
                        Conversation.id == conv_uuid,
                        Conversation.user_id == user_uuid,
                    )
                )
                conv = r.scalar_one_or_none()
                if conv:
                    return conv
            except ValueError:
                pass

        title = text[:30] if len(text) <= 30 else text[:30] + "..."
        conv = Conversation(user_id=user_uuid, title=title)
        db.add(conv)
        await db.commit()
        await db.refresh(conv)
        return conv


chat_orchestrator = ChatOrchestrator()
