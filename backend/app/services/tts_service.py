import httpx
from app.config import settings


class TTSService:
    def __init__(self):
        self.api_key = settings.qwen_api_key
        self.tts_url = settings.tts_api_url

    async def synthesize_flash(
        self, text: str, voice: str = "female-1"
    ) -> bytes:
        """Use Qwen3-TTS-Flash for fast synthesis."""
        headers = {"Authorization": f"Bearer {self.api_key}"}
        data = {
            "model": "qwen3-tts-flash",
            "input": {"text": text},
            "parameters": {"voice": voice},
        }
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(self.tts_url, json=data, headers=headers)
            resp.raise_for_status()
            result = resp.json()
            audio_url = result.get("output", {}).get("audio_url", "")
            if audio_url:
                async with httpx.AsyncClient() as audio_client:
                    audio_resp = await audio_client.get(audio_url)
                    return audio_resp.content
            return b""

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
