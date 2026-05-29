import asyncio
import logging
import httpx
from app.config import settings
from app.services.skills.base import BaseSkill, SkillResult
from app.services.skills.utils import parse_json
from app.services.llm_service import llm_router

logger = logging.getLogger("search_skill")

QUERY_PROMPT = """从用户输入中提取纯搜索关键词，去掉口语化的前缀（如"搜索一下""帮我查""百度一下"等）。

返回格式: {{"query": "关键词"}}

用户输入: {user_input}
JSON:"""

LLM_SEARCH_PROMPT = """请搜索并提供关于以下问题的信息，尽可能详细和准确：

{query}

请直接提供答案，不需要说"根据搜索结果"之类的开头。"""

SUMMARIZE_PROMPT = """根据以下多来源信息，用1-2句话简洁回答用户的问题。综合各来源的关键信息，优先采用API搜索结果。如果信息有冲突，以API搜索结果为准。

用户问题: {user_input}

API搜索结果:
{search_results}

大模型回答:
{llm_answer}

简洁回答:"""


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

            # Format search results for summarization
            search_text = "\n".join(
                f"{i+1}. {r.get('title', '')}: {r.get('content', '')[:200]}"
                for i, r in enumerate(searxng_results)
            ) if searxng_results else "(无搜索结果)"

            llm_text = llm_answer[:500] if llm_answer else "(无大模型结果)"

            # Summarize combined results
            summary = await self._summarize(user_input, search_text, llm_text)
            logger.info("search summary: %s", summary[:100] if summary else "(empty)")

            if summary:
                text = summary
            elif searxng_results:
                text = "搜索到以下结果:\n" + "\n".join(
                    f"- {r.get('title', '')}" for r in searxng_results
                )
            else:
                text = llm_answer

            return SkillResult(text=text, data={
                "query": query,
                "results": searxng_results,
                "llm_answer": llm_answer[:200],
            })
        except Exception:
            logger.exception("search skill failed")
            return SkillResult(text="暂时无法完成搜索，请稍后再试")

    async def _ask_llm(self, query: str) -> str:
        try:
            return await llm_router.chat([
                {"role": "user", "content": LLM_SEARCH_PROMPT.format(query=query)},
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

    async def _summarize(self, user_input: str, search_text: str, llm_answer: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": SUMMARIZE_PROMPT.format(
                    user_input=user_input, search_results=search_text, llm_answer=llm_answer,
                )},
            ])
            return raw.strip()
        except Exception:
            return ""


search_skill = SearchSkill()
