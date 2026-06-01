import logging
from openai import AsyncOpenAI
from app.config import settings

logger = logging.getLogger("llm")

DEEPSEEK_MODEL = settings.deepseek_model_name
QWEN_MODEL = settings.qwen_model_name
CHAT_MODEL = settings.chat_model_name


class LLMRouter:
    def __init__(self):
        self.deepseek = AsyncOpenAI(
            api_key=settings.deepseek_api_key, base_url=settings.deepseek_base_url
        )
        self.qwen = AsyncOpenAI(
            api_key=settings.qwen_api_key, base_url=settings.qwen_base_url
        )

    async def chat(
        self, messages: list[dict], force_model: str | None = None
    ) -> str:
        if force_model == "qwen":
            client = self.qwen
            model = QWEN_MODEL
        else:
            client = self.deepseek
            model = force_model or CHAT_MODEL
        try:
            response = await client.chat.completions.create(
                model=model,
                messages=messages,
                stream=False,
                temperature=0.6,
                top_p=0.9,
                max_tokens=512,
                frequency_penalty=0.3,
            )
            choices = response.choices
            if not choices:
                logger.warning("LLM returned empty choices, model=%s", model)
                return ""
            content = choices[0].message.content
            return content or ""
        except Exception:
            logger.exception("LLM chat failed, model=%s", model)
            raise

    async def chat_stream(
        self, messages: list[dict], force_model: str | None = None
    ):
        if force_model == "qwen":
            client = self.qwen
            model = QWEN_MODEL
        else:
            client = self.deepseek
            model = force_model or CHAT_MODEL
        try:
            stream = await client.chat.completions.create(
                model=model,
                messages=messages,
                stream=True,
                temperature=0.7,
                top_p=0.92,
                max_tokens=1024,
                frequency_penalty=0.3,
                presence_penalty=0.2,
            )
            async for chunk in stream:
                choices = chunk.choices
                if not choices:
                    continue
                delta = choices[0].delta
                if delta and delta.content:
                    yield delta.content
        except Exception:
            logger.exception("LLM stream failed, model=%s", model)
            raise

    async def classify_intent(self, text: str) -> str:
        """Returns: chat, search, weather, calendar, expense, convert"""
        prompt = f"""分析用户意图，只返回一个标签:
- chat: 普通闲聊
- search: 需要搜索信息
- weather: 查询天气
- calendar: 日历提醒相关
- expense: 记账相关
- convert: 文件格式转换（如Word转PDF、PDF转Word）
- briefing: 查看今日简报、早晨问候（如"早上好""今日简报""今天有什么"）
- email: 发送邮件、对话摘要发送到邮箱

用户输入: {text}
标签:"""
        try:
            response = await self.deepseek.chat.completions.create(
                model=DEEPSEEK_MODEL,
                messages=[{"role": "user", "content": prompt}],
                stream=False,
                max_tokens=10,
                temperature=0,
                top_p=0.8,
            )
            choices = response.choices
            if not choices:
                logger.warning("classify_intent: empty choices")
                return "chat"
            content = choices[0].message.content
            if not content:
                logger.warning("classify_intent: null content")
                return "chat"
            return content.strip().lower()
        except Exception:
            logger.exception("classify_intent failed")
            return "chat"


llm_router = LLMRouter()
