import uuid
import base64
from datetime import datetime, timezone

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models import Conversation, Message, MessageRole, MessageType
from app.services.llm_service import llm_router
from app.services.tts_service import tts_service
from app.services.skill_registry import skill_registry


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

        # 2. Classify intent
        intent = await llm_router.classify_intent(text)

        # 3. Execute skill or chat
        if intent != "chat" and intent in skill_registry._skills:
            skill = skill_registry.get(intent)
            result = await skill.execute(user_id, text, db)
            response_text = result.text

            # Save user message after skill execution
            user_msg = Message(
                conv_id=conv.id,
                role=MessageRole.user,
                type=MessageType.text,
                content=text,
            )
            db.add(user_msg)

            await send_message(
                {"type": "skill_call", "skill": intent, "status": "done"}
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
            )
            db.add(user_msg)

            # Build LLM messages with current text appended
            llm_messages = [
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
        )
        db.add(assistant_msg)
        conv.updated_at = datetime.now(timezone.utc)
        await db.commit()

        # 5. Synthesize TTS
        try:
            audio_bytes = await tts_service.synthesize_flash(response_text)
            if audio_bytes:
                await send_message(
                    {
                        "type": "tts_audio",
                        "audio": base64.b64encode(audio_bytes).decode(),
                        "text": response_text,
                    }
                )
        except Exception:
            pass  # TTS failure is non-fatal

        # 6. Done
        await send_message(
            {"type": "done", "conversation_id": str(conv.id)}
        )

    async def process_voice(
        self,
        user_id: str,
        audio_base64: str,
        conversation_id: str | None,
        db: AsyncSession,
        send_message,
    ):
        from app.services.asr_service import asr_service

        # 1. ASR
        text = await asr_service.transcribe(audio_base64)
        await send_message({"type": "asr_result", "text": text})

        if not text.strip():
            await send_message({"type": "done"})
            return

        # 2. Continue with text processing
        await self.process_text(
            user_id, text, conversation_id, db, send_message
        )

    async def _get_or_create_conv(
        self,
        user_id: str,
        conv_id: str | None,
        db: AsyncSession,
        text: str,
    ) -> Conversation:
        user_uuid = uuid.UUID(user_id)
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
