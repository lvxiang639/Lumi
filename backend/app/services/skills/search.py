import logging
import httpx
from app.config import settings
from app.services.skills.base import BaseSkill, SkillResult
from app.services.skills.utils import parse_json
from app.services.llm_service import llm_router

logger = logging.getLogger("search_skill")

QUERY_PROMPT = """从用户输入中提取纯搜索关键词，去掉口语化的前缀（如"搜索一下""帮我查""百度一下"等）。如果本身就是关键词，直接返回。

返回格式: {{"query": "关键词"}}

用户输入: {user_input}
JSON:"""

SUMMARIZE_PROMPT = """根据以下搜索结果，用1-2句话简洁回答用户的问题。引用关键信息。

用户问题: {user_input}

搜索结果:
{results_text}

简洁回答:"""


class SearchSkill(BaseSkill):
    name = "search"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            query = await self._extract_query(user_input)
            logger.info("search query: %s -> %s", user_input[:60], query)

            results = await self._search_searxng(query)
            if not results:
                results = await self._search_duckduckgo(query)

            if not results:
                return SkillResult(text="没有找到相关信息")

            results_text = "\n".join(
                f"{i+1}. {r.get('title', '')}: {r.get('content', r.get('snippet', ''))[:200]}"
                for i, r in enumerate(results)
            )
            summary = await self._summarize(user_input, results_text)
            logger.info("search summary: %s", summary[:100] if summary else "(empty)")

            text = summary if summary else "搜索到以下结果:\n" + "\n".join(
                f"- {r.get('title', '')}" for r in results
            )
            return SkillResult(text=text, data={"query": query, "results": results})
        except Exception:
            logger.exception("search skill failed")
            return SkillResult(text="暂时无法完成搜索，请稍后再试")

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
            return []

    async def _search_duckduckgo(self, query: str) -> list[dict]:
        try:
            from duckduckgo_search import DDGS

            loop = __import__("asyncio").get_running_loop()
            results = await loop.run_in_executor(
                None, lambda: list(DDGS().text(query, max_results=5))
            )
            return [
                {"title": r.get("title", ""), "snippet": r.get("body", ""),
                 "content": r.get("body", ""), "url": r.get("href", "")}
                for r in results
            ]
        except Exception:
            logger.exception("duckduckgo search failed")
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

    async def _summarize(self, user_input: str, results_text: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": SUMMARIZE_PROMPT.format(
                    user_input=user_input, results_text=results_text,
                )},
            ])
            return raw.strip()
        except Exception:
            return ""


search_skill = SearchSkill()
