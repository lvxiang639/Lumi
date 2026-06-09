import asyncio
import logging
import uuid
from uuid import UUID
# import base64  # VOICE FEATURE DISABLED
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models import Conversation, Message, MessageRole, MessageType, Character
from app.services.llm_service import llm_router
# ============================================================
# VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
# ============================================================
# from app.services.tts_service import tts_service
# ============================================================
from app.services.skill_registry import skill_registry

logger = logging.getLogger("orchestrator")


class ChatOrchestrator:
    async def process_text(
        self,
        user_id: str,
        text: str,
        conversation_id: str | None,
        db: AsyncSession,
        send_message,
    ):
        # 1. Get or create conversation
        conv = await self._get_or_create_conv(user_id, conversation_id, db, text)
        user_uuid = uuid.UUID(user_id) if isinstance(user_id, str) else user_id

        # 2. Detect multi-step agent requests
        _AGENT_KEYWORDS = ("并", "然后", "顺便", "同时", "再帮我", "也帮我", "还有")
        is_agent = any(kw in text for kw in _AGENT_KEYWORDS)

        # 3. Classify intent (skip for system messages)
        _SYSTEM_PREFIXES = ('📋', '✅', '❌', '📝', '📧', '📎', '📄')
        if text.strip().startswith(_SYSTEM_PREFIXES):
            intent = "chat"
        elif is_agent:
            intent = "agent"
        else:
            intent = await llm_router.classify_intent(text)
        logger.info("user=%s conv=%s intent=%s text=%s", user_id[:8], str(conv.id)[:8], intent, text[:60])

        # 4. Execute: agent (multi-step) → skill → chat
        if intent == "agent":
            response_text = await self._execute_agent(
                user_id, text, conv, db, send_message, user_uuid
            )
        elif intent != "chat" and skill_registry.has(intent):
            skill = skill_registry.get(intent)

            # Load conversation history for context-aware skill responses
            msgs_result = await db.execute(
                select(Message)
                .where(Message.conv_id == conv.id)
                .order_by(Message.created_at.desc())
                .limit(20)
            )
            history = msgs_result.scalars().all()
            history.reverse()

            # Build context string from recent conversation
            if history:
                context_lines = ["【对话上下文——请结合此前的对话内容理解用户的意图】"]
                for m in history:
                    role_label = "用户" if m.role == MessageRole.user else "AI"
                    context_lines.append(f"{role_label}: {m.content or ''}")
                context_str = "\n".join(context_lines)
                contextualized_text = f"{context_str}\n\n用户最新输入: {text}"
            else:
                contextualized_text = text

            result = await skill.execute(user_id, contextualized_text, db)
            response_text = result.text

            # Save user message after skill execution
            user_msg = Message(
                conv_id=conv.id,
                role=MessageRole.user,
                type=MessageType.text,
                content=text,
                created_at=datetime.now(timezone.utc),
            )
            db.add(user_msg)
            await db.flush()

            await send_message(
                {
                    "type": "skill_call",
                    "skill": intent,
                    "status": "done",
                    "data": result.data,
                }
            )
            # Stream the skill result text back to client
            await send_message(
                {"type": "llm_stream", "delta": response_text}
            )
        else:
            # Build conversation history (last 20 messages, before saving current)
            msgs_result = await db.execute(
                select(Message)
                .where(Message.conv_id == conv.id)
                .order_by(Message.created_at.desc())
                .limit(20)
            )
            history = msgs_result.scalars().all()
            history.reverse()

            # Save user message
            user_msg = Message(
                conv_id=conv.id,
                role=MessageRole.user,
                type=MessageType.text,
                content=text,
                created_at=datetime.now(timezone.utc),
            )
            db.add(user_msg)
            await db.flush()

            # Inject long-term memory + conversation memory as system prompt
            from app.services.memory_service import (
                get_memory_summary,
                get_conv_memory_summary,
            )
            memory_summary = await get_memory_summary(user_uuid)
            conv_memory = await get_conv_memory_summary(conv.id)

            # Build LLM messages with memory + history
            llm_messages = []
            # AI Persona
            persona = (
                await self._load_persona(user_uuid)
                or "你是一个贴心的AI助手，名叫灵犀。"
            )
            # Inject current time so LLM always knows the correct time
            from datetime import timedelta
            beijing_now = datetime.now(timezone(timedelta(hours=8)))
            time_str = beijing_now.strftime("%Y年%m月%d日 %H:%M (星期%w，北京时间)")
            time_str = time_str.replace("星期0", "星期日").replace("星期1", "星期一").replace("星期2", "星期二").replace("星期3", "星期三").replace("星期4", "星期四").replace("星期5", "星期五").replace("星期6", "星期六")

            system_prefix = f"当前准确时间: {time_str}。{persona}"
            if memory_summary:
                system_prefix += (
                    "\n\n以下是关于你正在对话的用户的信息，"
                    "请在对话中自然地运用这些信息（不要刻意提及你知道这些）：\n"
                    + memory_summary
                )
            if conv_memory:
                system_prefix += (
                    "\n\n本次对话背景摘要（以下是之前对话中已经聊过的内容，避免重复）：\n"
                    + conv_memory
                )
            # Inject emotion tone
            from app.services.emotion_service import (
                analyze as analyze_emotion,
                get_emotion_prompt,
            )
            emotion_tone = await get_emotion_prompt(user_uuid)
            if emotion_tone:
                system_prefix += f"\n\n{emotion_tone}"
            llm_messages.append({"role": "system", "content": system_prefix})
            llm_messages += [
                {"role": m.role.value, "content": m.content} for m in history
            ]
            llm_messages.append({"role": "user", "content": text})

            # Stream LLM response
            full_response = ""
            async for delta in llm_router.chat_stream(llm_messages):
                full_response += delta
                await send_message({"type": "llm_stream", "delta": delta})

            response_text = full_response

        # 4. Save assistant message
        assistant_msg = Message(
            conv_id=conv.id,
            role=MessageRole.assistant,
            type=MessageType.text,
            content=response_text,
            created_at=datetime.now(timezone.utc),
        )
        db.add(assistant_msg)
        conv.updated_at = datetime.now(timezone.utc)
        await db.commit()

        # 5. Quick reply suggestions (fire-and-forget)
        if intent == "chat" and response_text and len(response_text) > 20:
            asyncio.create_task(self._suggest_replies(text, response_text, send_message))

        # 6. Done — send immediately
        await send_message(
            {"type": "done", "conversation_id": str(conv.id)}
        )

        # Analyze emotion and push state to frontend
        try:
            from app.services.emotion_service import (
                analyze as analyze_emotion,
                apply as apply_emotion,
            )
            emo_data = await analyze_emotion(text)
            emo_state = await apply_emotion(user_uuid, emo_data)
            await send_message({
                "type": "emotion_update",
                "emotion": emo_state["emotion"],
                "intensity": emo_state["intensity"],
            })
        except Exception:
            logger.exception("emotion update failed")

        # 6. Async memory extraction (fire-and-forget, does not block response)
        from app.services.memory_service import schedule_extraction
        # Build full recent dialogue for better context in memory extraction
        _recent_msgs = await db.execute(
            select(Message)
            .where(Message.conv_id == conv.id)
            .order_by(Message.created_at.asc())
            .limit(40)
        )
        _recent = _recent_msgs.scalars().all()
        _dialogue_lines = []
        for _m in _recent:
            _role = "用户" if _m.role == MessageRole.user else "AI"
            _dialogue_lines.append(f"{_role}: {_m.content or ''}")
        schedule_extraction(user_uuid, conv.id, "\n".join(_dialogue_lines))

        # ============================================================
        # VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
        # ============================================================
        # # 7. Synthesize TTS (streaming, after done)
        # try:
        #     voice = await self._get_character_voice(user_id, db)
        #     if voice and voice.get("cosyvoice_endpoint"):
        #         audio_bytes = await tts_service.synthesize_cosyvoice(
        #             response_text, voice["cosyvoice_id"]
        #         )
        #         if audio_bytes:
        #             await send_message({
        #                 "type": "tts_audio",
        #                 "audio": base64.b64encode(audio_bytes).decode(),
        #             })
        #     else:
        #         # Streaming TTS — send chunks as they arrive
        #         voice_name = voice["voice"] if voice else "Cherry"
        #         async for chunk in tts_service.synthesize_flash_stream(
        #             response_text, voice=voice_name
        #         ):
        #             await send_message({
        #                 "type": "tts_audio_chunk",
        #                 "chunk": base64.b64encode(chunk).decode(),
        #             })
        #         await send_message({"type": "tts_audio_end"})
        # except Exception:
        #     logger.exception("TTS synthesis failed")
        # ============================================================

    # ============================================================
    # VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
    # ============================================================
    # async def process_voice(
    #     self,
    #     user_id: str,
    #     audio_base64: str,
    #     conversation_id: str | None,
    #     db: AsyncSession,
    #     send_message,
    # ):
    #     from app.services.asr_service import asr_service

    #     # 1. ASR
    #     logger.info("process_voice start, user=%s audio_len=%d", user_id[:8], len(audio_base64))
    #     text = await asr_service.transcribe(audio_base64)
    #     await send_message({"type": "asr_result", "text": text})
    #     logger.info("ASR completed: text=%s", text[:80] if text else "(empty)")

    #     if not text.strip():
    #         logger.warning("Empty ASR result for user=%s", user_id[:8])
    #         await send_message({"type": "done"})
    #         return

    #     # 2. Continue with text processing
    #     await self.process_text(
    #         user_id, text, conversation_id, db, send_message
    #     )
    # ============================================================

    async def _get_character_voice(
        self, user_id: str, db: AsyncSession
    ) -> dict | None:
        """Look up the character's voice pack and return voice config."""
        from app.config import settings

        try:
            user_uuid = uuid.UUID(user_id)
            result = await db.execute(
                select(Character)
                .where(Character.user_id == user_uuid)
                .options(selectinload(Character.voice_pack))
            )
            char = result.scalar_one_or_none()
            if char and char.voice_pack:
                vp = char.voice_pack
                logger.info(
                    "character voice: user=%s voice=%s cosyvoice_id=%s",
                    user_id[:8], vp.name, vp.cosyvoice_id,
                )
                return {
                    "voice": vp.cosyvoice_id,
                    "cosyvoice_id": vp.cosyvoice_id,
                    "cosyvoice_endpoint": settings.cosyvoice_endpoint or "",
                }
        except Exception:
            logger.exception("failed to get character voice")
        return None

    async def _load_persona(self, user_id: UUID) -> str | None:
        """Load user's selected AI persona from memory."""
        try:
            from app.database import async_session
            from app.models import UserMemory
            from sqlalchemy import select
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
                        "小猫": "你是一只关心主人的小猫灵犀。用'喵~'开头，语气可爱温暖，会蹭蹭主人。喜欢用猫的视角看世界。",
                    }
                    return personas.get(mem.value)
        except Exception:
            pass
        return None

    async def _execute_agent(
        self, user_id, text, conv, db, send_message, user_uuid
    ) -> str:
        """Execute multi-step agent: plan → run skills → consolidate."""
        # Step 1: Plan
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

        # Step 2: Execute each step
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
                        result = await skill.execute(user_id, desc, db)
                        results.append(f"[{action}] {desc}: {result.text[:200]}")
                        await send_message({"type": "llm_stream", "delta": f"✅ {result.text[:150]}\n"})
                    except Exception:
                        results.append(f"[{action}] {desc}: 执行失败")
                else:
                    results.append(f"[{action}] {desc}: 未找到技能")
            else:
                # chat step — ask LLM
                try:
                    ans = await llm_router.chat([{"role": "user", "content": desc}])
                    results.append(f"[chat] {desc}: {ans[:200]}")
                    await send_message({"type": "llm_stream", "delta": f"💬 {ans[:150]}\n"})
                except Exception:
                    results.append(f"[chat] {desc}: 回答失败")

        # Step 3: Consolidate
        consolidated = "\n".join(results) if results else "已完成所有步骤"
        return consolidated

    async def _suggest_replies(self, user_msg: str, ai_response: str, send_message) -> None:
        """Generate 2-3 quick reply suggestions based on conversation context."""
        try:
            prompt = (
                f"基于以下对话，生成2-3个用户可以快速回复的选项（每个不超过15字）。"
                f"用JSON数组返回：[\"选项1\", \"选项2\"]\n\n"
                f"用户: {user_msg[:100]}\nAI: {ai_response[:200]}\n\nJSON:"
            )
            raw = await llm_router.chat([{"role": "user", "content": prompt}])
            if raw:
                import json
                try:
                    suggestions = json.loads(raw.strip())
                    if isinstance(suggestions, list) and len(suggestions) > 0:
                        await send_message({
                            "type": "quick_replies",
                            "replies": suggestions[:3],
                        })
                except (json.JSONDecodeError, ValueError):
                    pass
        except Exception:
            pass  # suggestions are optional, never fail the main flow

    async def _get_or_create_conv(
        self,
        user_id: str,
        conv_id: str | None,
        db: AsyncSession,
        text: str,
    ) -> Conversation:
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
