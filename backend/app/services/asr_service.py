import logging
import asyncio
import dashscope
from app.config import settings

dashscope.base_http_api_url = settings.dashscope_api_url
logger = logging.getLogger("asr")


class ASRService:
    async def transcribe(self, audio_base64: str, audio_format: str = "wav") -> str:
        logger.info("ASR start, audio_len=%d, format=%s", len(audio_base64), audio_format)
        try:
            response = await asyncio.to_thread(
                dashscope.MultiModalConversation.call,
                model=settings.asr_model_name,
                api_key=settings.qwen_api_key,
                messages=[{
                    "role": "user",
                    "content": [{"audio": f"data:audio/{audio_format};base64,{audio_base64}"}],
                }],
                result_format="message",
                asr_options={"enable_itn": False},
            )
            if response.status_code != 200:
                logger.error(
                    "ASR API error: status=%s, code=%s, msg=%s",
                    response.status_code, response.code, response.message,
                )
                return ""
            choices = response.output.get("choices", [])
            if not choices:
                logger.warning("ASR returned no choices")
                return ""
            content = choices[0].get("message", {}).get("content", [])
            if not content:
                logger.warning("ASR returned empty content")
                return ""
            text = content[0].get("text", "")
            logger.info("ASR result: text=%s", text[:80] if text else "(empty)")
            return text
        except Exception:
            logger.exception("ASR call failed")
            return ""


asr_service = ASRService()
