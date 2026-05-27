import dashscope
from app.config import settings

dashscope.base_http_api_url = settings.dashscope_api_url


class ASRService:
    async def transcribe(self, audio_base64: str, audio_format: str = "wav") -> str:
        response = dashscope.MultiModalConversation.call(
            model="qwen3-asr-flash",
            api_key=settings.qwen_api_key,
            messages=[{
                "role": "user",
                "content": [{"audio": f"data:audio/{audio_format};base64,{audio_base64}"}],
            }],
            result_format="message",
            asr_options={"enable_itn": False},
        )
        if response.status_code != 200:
            return ""
        choices = response.output.get("choices", [])
        if not choices:
            return ""
        content = choices[0].get("message", {}).get("content", [])
        if not content:
            return ""
        return content[0].get("text", "")


asr_service = ASRService()
