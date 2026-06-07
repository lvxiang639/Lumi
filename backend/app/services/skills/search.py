import asyncio
import logging
import httpx
from app.config import settings
from app.services.skills.base import BaseSkill, SkillResult
from app.services.skills.utils import parse_json
from app.services.llm_service import llm_router

logger = logging.getLogger("search_skill")

QUERY_PROMPT = """从用户输入中提取纯搜索关键词。如果输入包含对话上下文（以"【对话上下文"开头），请结合上下文理解用户意图后再提取关键词。去掉口语化的前缀（如"搜索一下""帮我查""百度一下"等）。

返回格式: {{"query": "关键词"}}

用户输入: {user_input}
JSON:"""

LLM_SEARCH_PROMPT = """当前时间：{current_time}。请根据你的知识回答以下问题，尽可能详细和准确：

{query}

请直接提供答案，不需要说"根据搜索结果"之类的开头。注意当前时间，不要使用过时的信息。"""

class SearchSkill(BaseSkill):
    name = "search"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            query = await self._extract_query(user_input)
            logger.info("search query: %s -> %s", user_input[:60], query)

            # Parallel: SearXNG + LLM
            search_task = asyncio.create_task(self._search_searxng(query))
            llm_task = asyncio.create_task(self._ask_llm(query))
            searxng_results, llm_answer = await asyncio.gather(search_task, llm_task)

            if not searxng_results and not llm_answer:
                return SkillResult(text="没有找到相关信息")

            # Build full response — no summarization, show all results
            parts = []

            # Full LLM answer first (most relevant)
            if llm_answer:
                parts.append(llm_answer.strip())

            # Search results with full content
            if searxng_results:
                parts.append("\n📎 搜索结果:")
                for i, r in enumerate(searxng_results):
                    title = r.get('title', '')
                    content = r.get('content', '')
                    url = r.get('url', '')
                    parts.append(f"\n{i+1}. **{title}**")
                    if content:
                        parts.append(f"   {content}")
                    if url:
                        parts.append(f"   🔗 {url}")

            text = "\n".join(parts)

            return SkillResult(text=text, data={
                "query": query,
                "results": searxng_results,
                "llm_answer": llm_answer,
            })
        except Exception:
            logger.exception("search skill failed")
            return SkillResult(text="暂时无法完成搜索，请稍后再试")

    async def _ask_llm(self, query: str) -> str:
        try:
            from datetime import datetime, timezone, timedelta
            now = datetime.now(timezone(timedelta(hours=8)))
            return await llm_router.chat([
                {"role": "user", "content": LLM_SEARCH_PROMPT.format(
                    query=query, current_time=now.strftime("%Y-%m-%d %H:%M")),
                },
            ])
        except Exception:
            logger.exception("llm search failed")
            return ""

    async def _search_searxng(self, query: str) -> list[dict]:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{settings.searxng_url}/search",
                    params={
                        "q": query, "format": "json",
                        "engines": settings.searxng_engines,
                    },
                    timeout=15,
                )
                resp.raise_for_status()
                data = resp.json()
                return data.get("results", [])[:5]
        except Exception:
            logger.exception("searxng search failed")
            try:
                from duckduckgo_search import DDGS
                loop = asyncio.get_running_loop()
                results = await loop.run_in_executor(
                    None, lambda: list(DDGS().text(query, max_results=5))
                )
                return [
                    {"title": r.get("title", ""), "content": r.get("body", ""), "url": r.get("href", "")}
                    for r in results
                ]
            except Exception:
                logger.exception("duckduckgo fallback failed")
                return []

    async def _extract_query(self, user_input: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": QUERY_PROMPT.format(user_input=user_input)},
            ])
            data = parse_json(raw)
            query = data.get("query", "").strip()
            return query if query else user_input
        except Exception:
            return user_input

search_skill = SearchSkill()
