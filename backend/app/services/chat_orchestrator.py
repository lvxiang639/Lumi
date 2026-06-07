import logging
import uuid
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

        # 2. Classify intent (skip for system-generated display messages)
        _SYSTEM_PREFIXES = ('📋', '✅', '❌', '📝', '📧', '📎', '📄')
        if text.strip().startswith(_SYSTEM_PREFIXES):
            intent = "chat"  # system display msg — no skill, just save + echo
        else:
            intent = await llm_router.classify_intent(text)
        logger.info("user=%s conv=%s intent=%s text=%s", user_id[:8], str(conv.id)[:8], intent, text[:60])

        # 3. Execute skill or chat
        if intent != "chat" and skill_registry.has(intent):
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
            system_prefix = "你是一个贴心的AI助手，名叫灵犀。"
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

        # 5. Done — send immediately, don't wait for TTS
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
