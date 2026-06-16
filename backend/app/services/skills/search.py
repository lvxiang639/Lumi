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

SYNTHESIS_PROMPT = """当前时间：{current_time}。请根据以下搜索结果回答用户的问题。如果搜索结果包含实时数据，请直接引用。如果搜索结果不足，可以结合你的知识补充，但要注明哪些来自搜索结果、哪些来自你的知识。

用户问题: {query}

搜索结果:
{search_results}

请综合以上信息给出清晰、准确的回答。如果涉及实时价格、汇率、股价等，务必引用搜索结果中的具体数字并注明来源。"""


class SearchSkill(BaseSkill):
    name = "search"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            # Step 1: Extract clean search query
            query = await self._extract_query(user_input)
            logger.info("search query: %s -> %s", user_input[:60], query)

            # Step 2: Search SearXNG (with DuckDuckGo fallback)
            searxng_results = await self._search_searxng(query)

            # Step 3: Synthesize answer from search results via LLM
            llm_answer = ""
            if searxng_results:
                llm_answer = await self._synthesize(query, searxng_results)

            if not searxng_results and not llm_answer:
                return SkillResult(text="没有找到相关信息，请尝试换个关键词搜索")

            # Build response
            parts = []

            # Synthesized answer first
            if llm_answer:
                parts.append(llm_answer.strip())

            # Raw search results as reference
            if searxng_results:
                parts.append("\n📎 搜索结果:")
                for i, r in enumerate(searxng_results):
                    title = r.get('title', '')
                    content = r.get('content', '')
                    url = r.get('url', '')
                    parts.append(f"\n{i + 1}. **{title}**")
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

    async def _synthesize(self, query: str, results: list[dict]) -> str:
        """Ask LLM to synthesize an answer from search results."""
        try:
            from datetime import datetime, timezone, timedelta
            now = datetime.now(timezone(timedelta(hours=8)))

            # Format search results for LLM consumption
            results_text = ""
            for i, r in enumerate(results[:5]):
                title = r.get('title', '')
                content = r.get('content', '')
                results_text += f"\n[{i + 1}] {title}\n{content}\n"

            prompt = SYNTHESIS_PROMPT.format(
                query=query,
                current_time=now.strftime("%Y-%m-%d %H:%M"),
                search_results=results_text,
            )
            return await llm_router.chat([{"role": "user", "content": prompt}])
        except Exception:
            logger.exception("synthesis failed")
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
                results = data.get("results", [])[:5]
                if results:
                    logger.info("searxng: %d results for '%s'", len(results), query[:60])
                return results
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
            # Strip context preamble if present (added by chat_orchestrator for skills)
            clean_input = user_input
            if "用户最新输入:" in user_input:
                clean_input = user_input.split("用户最新输入:")[-1].strip()
            elif user_input.startswith("【对话上下文"):
                # Fallback: take the last line which is usually the actual query
                lines = user_input.strip().split("\n")
                clean_input = lines[-1] if lines else user_input

            raw = await llm_router.chat([
                {"role": "user", "content": QUERY_PROMPT.format(user_input=clean_input)},
            ])
            data = parse_json(raw)
            query = data.get("query", "").strip()
            if query:
                return query
            # If LLM returned empty, use the cleaned input directly
            return clean_input if clean_input else user_input
        except Exception:
            # Last resort: strip context markers and use raw text
            if "用户最新输入:" in user_input:
                return user_input.split("用户最新输入:")[-1].strip()
            return user_input


search_skill = SearchSkill()
