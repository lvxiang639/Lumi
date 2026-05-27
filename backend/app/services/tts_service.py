import httpx
import dashscope
from app.config import settings

dashscope.base_http_api_url = settings.dashscope_api_url


class TTSService:
    async def synthesize_flash(
        self, text: str, voice: str = "Cherry", language: str = "Chinese"
    ) -> bytes:
        """Use Qwen3-TTS-Flash via DashScope SDK."""
        response = dashscope.MultiModalConversation.call(
            model="qwen3-tts-flash",
            api_key=settings.qwen_api_key,
            text=text,
            voice=voice,
            language_type=language,
            stream=False,
        )
        if response.status_code != 200:
            return b""

        audio_url = response.output.get("audio", {}).get("url", "")
        if not audio_url:
            return b""

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(audio_url)
            resp.raise_for_status()
            return resp.content

    async def synthesize_cosyvoice(
        self, text: str, cosyvoice_id: str
    ) -> bytes:
        """Use CosyVoice for character voices."""
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{settings.cosyvoice_endpoint}/synthesize",
                json={"text": text, "voice_id": cosyvoice_id},
            )
            resp.raise_for_status()
            return resp.content


tts_service = TTSService()
