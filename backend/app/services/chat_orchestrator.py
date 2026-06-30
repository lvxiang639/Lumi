import asyncio
import logging
import re
import time
import uuid
from uuid import UUID
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models import Conversation, Message, MessageRole, MessageType
from app.services.llm_service import llm_router
from app.services.skill_registry import skill_registry

logger = logging.getLogger("orchestrator")
BEIJING_TZ = timezone(timedelta(hours=8))
TOOL_MARKER = re.compile(r'\[TOOL:(\w+)(?::([^\]]+))?\]')
_TOOL_BUFFER_MAX = 250


class Trace:
    """Per-request timing tracer."""
    def __init__(self, user_id: str, text: str):
        self.user = user_id[:8]
        self.text = text[:60]
        self.t0 = time.monotonic()
        self.marks: list[tuple[str, int]] = []

    def mark(self, label: str):
        self.marks.append((label, int((time.monotonic() - self.t0) * 1000)))

    def log(self, conv_id: str, response_len: int):
        steps = " → ".join(f"{l}({t}ms)" for l, t in self.marks)
        logger.info("⏱ %s conv=%s len=%d | %s | %s", self.user, conv_id[:8], response_len, steps, self.text)


class ChatOrchestrator:
    async def process_text(self, user_id, text, conversation_id, db, send_message):
        trace = Trace(user_id, text)
        conv = await self._get_or_create_conv(user_id, conversation_id, db, text)
        user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id

        # Save user message
        user_msg = Message(conv_id=conv.id, role=MessageRole.user, type=MessageType.text,
                           content=text, created_at=datetime.now(timezone.utc))
        db.add(user_msg)
        await db.flush()
        trace.mark("save")

        # Chat (with optional search tool)
        response_text = await self._chat_with_tools(user_id, text, conv, db, send_message, user_uuid, trace)
        trace.mark("generate")

        # Save assistant message
        assistant_msg = Message(conv_id=conv.id, role=MessageRole.assistant, type=MessageType.text,
                                content=response_text, created_at=datetime.now(timezone.utc))
        db.add(assistant_msg)
        conv.updated_at = datetime.now(timezone.utc)
        await db.commit()

        await send_message({"type": "done", "conversation_id": str(conv.id)})
        trace.mark("done")

        if response_text and len(response_text) > 20:
            asyncio.create_task(self._suggest_replies(text, response_text, send_message))

        self._schedule_post_tasks(user_uuid, conv.id)
        trace.log(str(conv.id), len(response_text))

    async def _chat_with_tools(self, user_id, text, conv, db, send_message, user_uuid, trace):
        system_prompt = await self._build_system_prompt(user_uuid, text, conv.id)
        history = await self._load_history(conv.id, db, limit=10)
        trace.mark("ctx")

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
                match = TOOL_MARKER.search(tool_buffer)
                if match:
                    tool_executed = True
                    tool_name = match.group(1)
                    tool_arg = (match.group(2) or "").strip()
                    trace.mark(f"tool:{tool_name}")

                    if tool_name == "search" and tool_arg:
                        skill = skill_registry.get("search")
                        if skill:
                            r = await skill.execute(user_id, tool_arg, db)
                            await send_message({"type": "skill_call", "skill": "search", "status": "done", "data": r.data})
                            await send_message({"type": "llm_stream", "delta": f"\n\n📎 {(r.text or '')[:600]}\n\n"})

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

            if not tool_executed and tool_buffer:
                full_response += tool_buffer

        except Exception:
            logger.exception("chat stream crashed user=%s", user_id[:8])
            if not full_response:
                full_response = "抱歉，我暂时无法回复，请稍后再试 😿"

        return full_response

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
            "你是一个贴心的AI学习助手，名叫灵犀。擅长辅导孩子学习，讲解耐心细致。"

        now = datetime.now(BEIJING_TZ)
        wdays = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
        time_str = f"{now.strftime('%Y年%m月%d日 %H:%M')} {wdays[now.weekday()]}"

        conv_ctx = ""
        if not isinstance(conv_t, Exception) and conv_t:
            conv_ctx = f"\n你们正在聊: {conv_t}"

        memory_section = ""
        if not isinstance(mem_t, Exception) and mem_t:
            memory_section = "\n关于用户（自然融入对话，不要刻意复述）:\n" + "\n".join(f"- {m}" for m in mem_t)

        emotion_section = ""
        if not isinstance(emo_t, Exception) and emo_t:
            emotion_section = f"\n用户最近情绪: {emo_t}"

        return f"""{persona}

现在是{time_str}。{conv_ctx}{memory_section}{emotion_section}
回复指南:
- 简洁自然，通常2-4句话
- 不知道用户名字时称呼"你"
- 学习相关问题要给出具体、可操作的建议
- 需要搜索实时信息时加 [TOOL:search:关键词]"""

    async def _load_history(self, conv_id, db, limit=10):
        r = await db.execute(select(Message).where(Message.conv_id == conv_id)
                            .order_by(Message.created_at.desc()).limit(limit))
        history = r.scalars().all()
        history.reverse()
        return history

    async def _load_persona(self, user_id):
        try:
            from app.database import async_session
            from app.models import UserMemory
            async with async_session() as db:
                r = await db.execute(select(UserMemory).where(
                    UserMemory.user_id == user_id, UserMemory.key == "ai_persona"))
                mem = r.scalar_one_or_none()
                if mem and mem.value:
                    personas = {
                        "温柔姐姐": "你是一个温柔体贴的大姐姐，名叫小暖。擅长辅导学习。",
                        "学霸老师": "你是一个博学耐心的学霸老师，名叫小知。善于用简单比喻解释复杂概念。",
                        "小猫": "你是一只关心主人的小猫灵犀。用'喵~'开头，回复简洁温暖。",
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
                f"用JSON数组返回。\n用户: {user_msg[:100]}\nAI: {ai_response[:200]}\nJSON:"
            )}])
            if raw:
                import json
                clean = raw.strip()
                if clean.startswith("```"):
                    clean = clean.split("\n", 1)[-1] if "\n" in clean else clean[3:]
                    if clean.endswith("```"): clean = clean[:-3]
                    clean = clean.strip()
                try:
                    parsed = json.loads(clean)
                    if isinstance(parsed, list) and len(parsed) > 0:
                        suggestions = parsed[:3]
                except (json.JSONDecodeError, ValueError):
                    pass
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
                async with async_session() as db:
                    r = await db.execute(select(Message).where(Message.conv_id == conv_id)
                                        .order_by(Message.created_at.asc()).limit(40))
                    recent = r.scalars().all()
                    lines = [f"{'用户' if m.role == MessageRole.user else 'AI'}: {m.content or ''}" for m in recent]
                    schedule_extraction(user_uuid, conv_id, "\n".join(lines))
            except Exception:
                pass
        asyncio.create_task(_extract())

    async def _get_or_create_conv(self, user_id, conv_id, db, text):
        try: user_uuid = uuid.UUID(user_id)
        except (ValueError, TypeError): user_uuid = uuid.uuid4()
        if conv_id:
            try:
                r = await db.execute(select(Conversation).where(
                    Conversation.id == uuid.UUID(conv_id), Conversation.user_id == user_uuid))
                conv = r.scalar_one_or_none()
                if conv: return conv
            except ValueError: pass
        conv = Conversation(user_id=user_uuid, title=text[:30])
        db.add(conv)
        await db.commit()
        await db.refresh(conv)
        return conv


chat_orchestrator = ChatOrchestrator()
