import httpx
from app.config import settings


class ASRService:
    def __init__(self):
        self.api_key = settings.qwen_api_key
        self.api_url = settings.asr_api_url

    async def transcribe(self, audio_base64: str, audio_format: str = "wav") -> str:
        headers = {"Authorization": f"Bearer {self.api_key}"}
        data = {
            "model": "qwen3-asr-flash",
            "input": {"audio": audio_base64, "format": audio_format},
        }
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(self.api_url, json=data, headers=headers)
            resp.raise_for_status()
            result = resp.json()
            return result.get("output", {}).get("text", "")


asr_service = ASRService()
