import asyncio
import logging
import re
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

# Tool marker pattern: [TOOL:name:arg1:arg2...]
TOOL_MARKER = re.compile(r'\[TOOL:(\w+)(?::([^\]]+))?\]')

# Quick keyword triggers — fast path to skip LLM intent check for obvious skill requests
SKILL_KEYWORDS = {
    "search": (
        "搜索", "搜一下", "百度", "谷歌",  # user explicitly asking to search
        "BTC", "ETH", "比特币",           # crypto symbols
        "股价", "股票",                    # stocks
        "汇率", "外汇",                    # forex
    ),
    "weather": ("天气", "下雨", "下雪", "多少度", "冷吗", "热吗", "穿什么"),
    "calendar": ("提醒我", "定个闹钟", "日程", "别忘了", "记得"),
    "expense": ("记账", "记帐", "花了", "消费", "买了", "支出", "开销", "吃饭花了"),
    "briefing": ("简报", "早上好", "今日简报", "今天有什么"),
    "convert": ("转格式", "转换", "转PDF", "转Word", "转word"),
    "email": ("发邮件", "邮件", "发送到邮箱", "发到邮箱"),
}

# System message prefixes that force chat mode (no skill routing)
_SYSTEM_PREFIXES = ('📋', '✅', '❌', '📝', '📧', '📎', '📄')
_AGENT_KEYWORDS = ("并", "然后", "顺便", "同时", "再帮我", "也帮我", "还有")
# Context-free skills: don't need conversation history, just the raw user text
_CONTEXT_FREE_SKILLS = {"weather", "expense"}

BEIJING_TZ = timezone(timedelta(hours=8))


class ChatOrchestrator:
    async def process_text(
        self,
        user_id: str,
        text: str,
        conversation_id: str | None,
        db: AsyncSession,
        send_message,
    ):
        conv = await self._get_or_create_conv(user_id, conversation_id, db, text)
        user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id

        # Detect intent: fast keyword pre-filter → LLM fallback for ambiguous cases
        if text.strip().startswith(_SYSTEM_PREFIXES):
            intent = "chat"
        elif len(text) >= 20 and sum(1 for kw in _AGENT_KEYWORDS if kw in text) >= 2:
            intent = "agent"
        else:
            intent = self._quick_intent(text)
            # Keyword returned "chat" → use LLM to verify (catches 记帐→expense, etc.)
            if intent == "chat" and len(text) >= 4:
                intent = await self._classify_with_llm(text)

        logger.info("user=%s conv=%s intent=%s text=%s", user_id[:8], str(conv.id)[:8], intent, text[:60])

        # Save user message
        user_msg = Message(
            conv_id=conv.id, role=MessageRole.user, type=MessageType.text,
            content=text, created_at=datetime.now(timezone.utc),
        )
        db.add(user_msg)
        await db.flush()

        if intent == "agent":
            response_text = await self._execute_agent(user_id, text, conv, db, send_message, user_uuid)
        elif intent != "chat" and skill_registry.has(intent):
            response_text = await self._execute_skill(intent, user_id, text, conv, db, send_message)
        else:
            response_text = await self._chat_with_tools(user_id, text, conv, db, send_message, user_uuid)

        # Save assistant message
        assistant_msg = Message(
            conv_id=conv.id, role=MessageRole.assistant, type=MessageType.text,
            content=response_text, created_at=datetime.now(timezone.utc),
        )
        db.add(assistant_msg)
        conv.updated_at = datetime.now(timezone.utc)
        await db.commit()

        # Quick reply suggestions (fire-and-forget)
        if response_text and len(response_text) > 20:
            asyncio.create_task(self._suggest_replies(text, response_text, send_message))

        await send_message({"type": "done", "conversation_id": str(conv.id)})

        # Fire-and-forget: emotion + memory
        self._schedule_post_tasks(user_uuid, text, conv.id, db)

    # ── Quick intent detection (regex-based, no LLM call) ──────────────

    def _quick_intent(self, text: str) -> str:
        """Fast keyword-based intent detection. Returns 'chat' if no skill matches."""
        tl = text.lower()
        for skill, keywords in SKILL_KEYWORDS.items():
            if any(kw in tl or kw in text for kw in keywords):
                return skill
        return "chat"

    async def _classify_with_llm(self, text: str) -> str:
        """LLM-based intent classification for ambiguous cases.
        Only called when keyword pre-filter returns 'chat'."""
        try:
            intent = await llm_router.classify_intent(text)
            # Only trust LLM for non-chat intents; keep "chat" as-is
            if intent and intent != "chat":
                logger.info("LLM reclassified intent: chat → %s", intent)
                return intent
        except Exception:
            pass
        return "chat"

    # ── Chat with inline tool markers ──────────────────────────────────

    # Max chars to buffer looking for tool markers before giving up
    _TOOL_BUFFER_MAX = 250

    async def _chat_with_tools(self, user_id, text, conv, db, send_message, user_uuid):
        """Main chat flow: build layered system prompt, stream, detect tool markers."""
        history = await self._load_history(conv.id, db, limit=10)
        system_prompt = await self._build_system_prompt(user_uuid, text, conv.id)

        llm_messages = [{"role": "system", "content": system_prompt}]
        llm_messages += [{"role": m.role.value, "content": m.content} for m in history]
        llm_messages.append({"role": "user", "content": text})

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

                # Search for tool marker ANYWHERE in buffer
                match = TOOL_MARKER.search(tool_buffer)
                if match:
                    tool_executed = True
                    tool_name = match.group(1)
                    tool_arg = (match.group(2) or "").strip()
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

                if len(tool_buffer) > self._TOOL_BUFFER_MAX:
                    tool_executed = True
                    full_response += tool_buffer
                    await send_message({"type": "llm_stream", "delta": tool_buffer})
                    tool_buffer = ""

            if not tool_executed and tool_buffer:
                full_response += tool_buffer

        except Exception:
            logger.exception("chat stream failed")
            if not full_response:
                full_response = "抱歉，我暂时无法回复，请稍后再试 😿"

        return full_response

    async def _execute_tool(self, tool_name: str, tool_arg: str, user_id: str, user_text: str, db) -> str:
        """Execute a tool requested via marker protocol. Returns result text."""
        if tool_name == "search" and tool_arg:
            skill = skill_registry.get("search")
            if skill:
                # Pass clean search query, not full context
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

    # ── Layered System Prompt ──────────────────────────────────────────

    async def _build_system_prompt(self, user_id: UUID, user_text: str, conv_id: UUID) -> str:
        """Build a structured, layered system prompt. IO operations run in parallel."""

        # Run all IO-bound lookups concurrently
        from app.services.memory_service import get_conv_memory_summary, get_relevant_memories
        from app.services.emotion_service import get_emotion_state

        persona_t, conv_t, mem_t, emo_t = await asyncio.gather(
            self._load_persona(user_id),
            get_conv_memory_summary(conv_id),
            get_relevant_memories(user_id, user_text, top_k=3),
            get_emotion_state(user_id),
            return_exceptions=True,
        )

        # ── Layer 1: Role ──
        persona = (persona_t if not isinstance(persona_t, Exception) else None) or "你是一个贴心的AI助手，名叫灵犀。"

        # ── Layer 2: Time ──
        now = datetime.now(BEIJING_TZ)
        wdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        time_str = f"{now.strftime('%Y年%m月%d日 %H:%M')} {wdays[now.weekday()]}"

        # ── Layer 3: Conversation context ──
        conv_ctx = ""
        if not isinstance(conv_t, Exception) and conv_t:
            conv_ctx = f"\n你们正在聊: {conv_t}"

        # ── Layer 4: Relevant memories ──
        memory_section = ""
        if not isinstance(mem_t, Exception) and mem_t:
            memory_section = "\n关于用户（自然融入对话，不要刻意复述）:\n" + "\n".join(
                f"- {m}" for m in mem_t
            )

        # ── Layer 5: Emotion ──
        emotion_section = ""
        if not isinstance(emo_t, Exception) and emo_t:
            emotion_section = f"\n用户最近情绪: {emo_t}"

        # ── Layer 6: Behavior guide ──
        behavior = """
回复指南:
- 简洁自然，通常2-4句话，除非用户要求详细解释
- 用温暖可爱的语气，像朋友聊天
- 不要重复用户的话，不要废话开头（如"好的""当然可以"等机械应答）
- 如果用户问的是实时信息（价格、天气、新闻等），在回复开头加 [TOOL:search:关键词]
- 如果用户要添加日历提醒，在回复开头加 [TOOL:calendar:标题:时间]
- 如果用户要查询天气，在回复开头加 [TOOL:weather:城市]
- 不需要搜索/工具的普通聊天，直接回复，不要加任何标记
- 不要提及已过期的日历事件"""

        return f"""{persona}

现在是{time_str}。{conv_ctx}{memory_section}{emotion_section}
{behavior}"""

    # ── Helpers ────────────────────────────────────────────────────────

    async def _load_history(self, conv_id: UUID, db: AsyncSession, limit: int = 10) -> list:
        msgs_result = await db.execute(
            select(Message)
            .where(Message.conv_id == conv_id)
            .order_by(Message.created_at.desc())
            .limit(limit)
        )
        history = msgs_result.scalars().all()
        history.reverse()
        return history

    async def _execute_skill(self, intent, user_id, text, conv, db, send_message) -> str:
        skill = skill_registry.get(intent)

        # Context-free skills: pass clean text, no history pollution
        if intent in _CONTEXT_FREE_SKILLS:
            result = await skill.execute(user_id, text, db)
            await send_message({"type": "skill_call", "skill": intent, "status": "done", "data": result.data})
            await send_message({"type": "llm_stream", "delta": result.text})
            return result.text

        # Contextual skills: pass full conversation history for better understanding
        history = await self._load_history(conv.id, db, limit=20)
        if history:
            context_lines = [
                "【对话上下文——请结合此前的对话内容理解用户的意图】",
                "注意：如果上下文中包含已过期的日历事件，请忽略它们。",
            ]
            for m in history:
                role_label = "用户" if m.role == MessageRole.user else "AI"
                context_lines.append(f"{role_label}: {m.content or ''}")
            context_str = "\n".join(context_lines)
            contextualized_text = f"{context_str}\n\n用户最新输入: {text}"
        else:
            contextualized_text = text

        result = await skill.execute(user_id, contextualized_text, db)
        await send_message({"type": "skill_call", "skill": intent, "status": "done", "data": result.data})
        await send_message({"type": "llm_stream", "delta": result.text})
        return result.text

    async def _load_persona(self, user_id: UUID) -> str | None:
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
                        "温柔姐姐": "你是一个温柔体贴的大姐姐，名叫小暖。说话轻声细语，喜欢用'呀''呢''哦'，会主动关心对方的情绪和健康。",
                        "毒舌损友": "你是一个毒舌但讲义气的损友，名叫阿怼。说话直白犀利，爱吐槽但真心为对方好。偶尔用'啧''行吧'，但从不说教。",
                        "学霸老师": "你是一个博学耐心的学霸老师，名叫小知。喜欢用数据和逻辑说话，但也会用简单比喻解释复杂概念。偶尔冒出一句冷知识。",
                        "二次元": "你是一个萌系二次元角色，名叫小萌。说话带'喵~''的说''捏'，元气满满，偶尔中二。热爱动漫游戏。",
                        "小猫": "你是一只关心主人的小猫灵犀。用'喵~'开头，回复简洁温暖。喜欢用猫的视角看世界，不啰嗦。",
                    }
                    return personas.get(mem.value)
        except Exception:
            pass
        return None

    async def _execute_agent(self, user_id, text, conv, db, send_message, user_uuid) -> str:
        await send_message({"type": "llm_stream", "delta": "🤖 分析中...\n"})
        plan_prompt = (
            f"用户请求: {text}\n\n"
            f"请将以上请求分解为2-4个简单步骤，每步一行，格式:\n"
            f"[动作]: [简短描述]\n"
            f"动作可选: search(搜索), weather(天气), calendar(添加日程), "
            f"expense(记账), chat(直接回答)\n\n"
            f"分步计划:"
        )
        plan_raw = await llm_router.chat([{"role": "user", "content": plan_prompt}])
        await send_message({"type": "llm_stream", "delta": f"📋 计划:\n{plan_raw}\n\n"})

        results = []
        for line in plan_raw.strip().split("\n"):
            line = line.strip()
            if not line or ":" not in line:
                continue
            action, _, desc = line.partition(":")
            action = action.strip().lower()
            desc = desc.strip()
            if not desc:
                continue

            await send_message({"type": "llm_stream", "delta": f"⚡ {desc}...\n"})

            if action in ("search", "weather", "calendar", "expense", "convert", "briefing", "email"):
                skill = skill_registry.get(action)
                if skill:
                    try:
                        # For context-free skills, use original user text as fallback
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

        consolidated = "\n".join(results) if results else "已完成所有步骤"
        return consolidated

    async def _suggest_replies(self, user_msg: str, ai_response: str, send_message) -> None:
        suggestions = None
        try:
            prompt = (
                f"基于以下对话，生成2-3个用户可以快速回复的选项（每个不超过15字）。"
                f"用JSON数组返回：[\"选项1\", \"选项2\"]\n\n"
                f"用户: {user_msg[:100]}\nAI: {ai_response[:200]}\n\nJSON:"
            )
            raw = await llm_router.chat([{"role": "user", "content": prompt}])
            if raw:
                import json
                clean = raw.strip()
                # Strip ```json ... ``` wrapper if present
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
                    logger.warning("quick_reply json parse failed: %s", raw[:100])
        except Exception as e:
            logger.warning("quick_reply LLM failed: %s", e)

        if not suggestions:
            suggestions = ["继续说", "详细讲讲", "举个例子"]

        await send_message({"type": "quick_replies", "replies": suggestions[:3]})

    def _schedule_post_tasks(self, user_uuid, text, conv_id, _db):
        """Fire-and-forget post-response tasks. Uses its own DB session."""
        async def _extract():
            try:
                from app.services.memory_service import schedule_extraction
                from app.database import async_session
                from sqlalchemy import select as sa_select
                async with async_session() as db:
                    _recent_msgs = await db.execute(
                        sa_select(Message)
                        .where(Message.conv_id == conv_id)
                        .order_by(Message.created_at.asc())
                        .limit(40)
                    )
                    _recent = _recent_msgs.scalars().all()
                    _dialogue_lines = []
                    for _m in _recent:
                        _role = "用户" if _m.role == MessageRole.user else "AI"
                        _dialogue_lines.append(f"{_role}: {_m.content or ''}")
                    schedule_extraction(user_uuid, conv_id, "\n".join(_dialogue_lines))
            except Exception:
                logger.exception("post-task memory extraction failed")

        asyncio.create_task(_extract())

    async def _get_or_create_conv(self, user_id, conv_id, db, text) -> Conversation:
        try:
            user_uuid = uuid.UUID(user_id)
        except (ValueError, TypeError):
            logger.warning("invalid user_id for conv creation: %s", user_id)
            user_uuid = uuid.uuid4()
        if conv_id:
            try:
                conv_uuid = uuid.UUID(conv_id)
            except ValueError:
                pass
            else:
                result = await db.execute(
                    select(Conversation).where(
                        Conversation.id == conv_uuid,
                        Conversation.user_id == user_uuid,
                    )
                )
                conv = result.scalar_one_or_none()
                if conv:
                    return conv
        title = text[:30] if len(text) <= 30 else text[:30] + "..."
        conv = Conversation(user_id=user_uuid, title=title)
        db.add(conv)
        await db.commit()
        await db.refresh(conv)
        return conv


chat_orchestrator = ChatOrchestrator()
