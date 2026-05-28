import json
import logging
import httpx
from app.services.skills.base import BaseSkill, SkillResult
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

    def __init__(self, searxng_url: str = "http://searxng:8080"):
        self.searxng_url = searxng_url

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            # Step 1: Extract pure search query via LLM
            query = await self._extract_query(user_input)
            logger.info("search query extracted: %s -> %s", user_input[:60], query)

            # Step 2: Search via SearXNG
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{self.searxng_url}/search",
                    params={"q": query, "format": "json", "engines": "google,bing,baidu"},
                    timeout=15,
                )
                resp.raise_for_status()
                data = resp.json()
                results = data.get("results", [])[:5]

            if not results:
                return SkillResult(text="没有找到相关信息")

            # Step 3: Summarize results via LLM
            results_text = "\n".join(
                f"{i+1}. {r['title']}: {r.get('content', r.get('snippet', ''))[:200]}"
                for i, r in enumerate(results)
            )
            summary = await self._summarize(user_input, results_text)
            logger.info("search summary: %s", summary[:100] if summary else "(empty)")

            if summary:
                text = summary
            else:
                lines = [f"- {r['title']}" for r in results]
                text = "搜索到以下结果:\n" + "\n".join(lines)

            return SkillResult(
                text=text,
                data={"query": query, "results": results},
            )
        except Exception:
            logger.exception("search skill failed")
            return SkillResult(text="暂时无法完成搜索，请稍后再试")

    async def _extract_query(self, user_input: str) -> str:
        try:
            raw = await llm_router.chat([
                {"role": "user", "content": QUERY_PROMPT.format(user_input=user_input)},
            ])
            data = self._parse_json(raw)
            query = (data or {}).get("query", "").strip()
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

    def _parse_json(self, raw: str) -> dict | None:
        raw = raw.strip()
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            pass
        import re
        match = re.search(r'\{[^{}]*\}', raw)
        if match:
            try:
                return json.loads(match.group())
            except json.JSONDecodeError:
                pass
        return None


search_skill = SearchSkill()
