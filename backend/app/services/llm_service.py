from openai import AsyncOpenAI
from app.config import settings


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
        client = self.qwen if force_model == "qwen" else self.deepseek
        model = "qwen-plus" if force_model == "qwen" else "deepseek-v4-flash"
        response = await client.chat.completions.create(
            model=model,
            messages=messages,
            stream=False,
        )
        return response.choices[0].message.content or ""

    async def chat_stream(
        self, messages: list[dict], force_model: str | None = None
    ):
        client = self.qwen if force_model == "qwen" else self.deepseek
        model = "qwen-plus" if force_model == "qwen" else "deepseek-v4-flash"
        stream = await client.chat.completions.create(
            model=model,
            messages=messages,
            stream=True,
        )
        async for chunk in stream:
            delta = chunk.choices[0].delta
            if delta.content:
                yield delta.content

    async def classify_intent(self, text: str) -> str:
        """Returns: chat, search, weather, calendar, expense"""
        prompt = f"""分析用户意图，只返回一个标签:
- chat: 普通闲聊
- search: 需要搜索信息
- weather: 查询天气
- calendar: 日历提醒相关
- expense: 记账相关

用户输入: {text}
标签:"""
        response = await self.deepseek.chat.completions.create(
            model="deepseek-v4-flash",
            messages=[{"role": "user", "content": prompt}],
            stream=False,
            max_tokens=10,
        )
        return response.choices[0].message.content.strip().lower()


llm_router = LLMRouter()
