import logging
import base64
import asyncio
import httpx
import dashscope
from app.config import settings

dashscope.base_http_api_url = settings.dashscope_api_url
logger = logging.getLogger("tts")


class TTSService:
    async def synthesize_flash(
        self, text: str, voice: str | None = None
    ) -> bytes:
        voice = voice or settings.tts_default_voice
        logger.info("TTS start, text_len=%d, voice=%s", len(text), voice)
        try:
            response = await asyncio.to_thread(
                dashscope.MultiModalConversation.call,
                model=settings.tts_model_name,
                api_key=settings.qwen_api_key,
                text=text,
                voice=voice,
                language_type="Chinese",
                stream=False,
            )
            if response.status_code != 200:
                logger.error(
                    "TTS API error: status=%s, code=%s, msg=%s",
                    response.status_code, response.code, response.message,
                )
                return b""

            audio_url = response.output.get("audio", {}).get("url", "")
            if not audio_url:
                logger.warning("TTS response missing audio URL")
                return b""

            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.get(audio_url)
                resp.raise_for_status()
                logger.info("TTS audio downloaded: size=%d bytes", len(resp.content))
                return resp.content
        except Exception:
            logger.exception("TTS synthesize failed")
            return b""

    async def synthesize_flash_stream(self, text: str, voice: str | None = None):
        """Stream TTS audio chunks as they are generated."""
        voice = voice or settings.tts_default_voice
        logger.info("TTS stream start, text_len=%d, voice=%s", len(text), voice)
        try:
            responses = await asyncio.to_thread(
                dashscope.MultiModalConversation.call,
                model=settings.tts_model_name,
                api_key=settings.qwen_api_key,
                text=text,
                voice=voice,
                language_type="Chinese",
                stream=True,
                incremental_output=True,
            )
            total = 0
            for resp in responses:
                if resp.status_code != 200:
                    logger.error(
                        "TTS stream error: status=%s, code=%s, msg=%s",
                        resp.status_code, resp.code, resp.message,
                    )
                    return
                audio = resp.output.get("audio", {})
                data = audio.get("data", "")
                if data:
                    chunk = base64.b64decode(data)
                    total += len(chunk)
                    yield chunk
            logger.info("TTS stream done: total=%d bytes", total)
        except Exception:
            logger.exception("TTS stream failed")

    async def synthesize_cosyvoice(
        self, text: str, cosyvoice_id: str
    ) -> bytes:
        logger.info("TTS cosyvoice start, voice_id=%s", cosyvoice_id)
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(
                    f"{settings.cosyvoice_endpoint}/synthesize",
                    json={"text": text, "voice_id": cosyvoice_id},
                )
                resp.raise_for_status()
                return resp.content
        except Exception:
            logger.exception("TTS cosyvoice failed")
            return b""


tts_service = TTSService()
