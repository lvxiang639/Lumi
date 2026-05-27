import httpx
from app.services.skills.base import BaseSkill, SkillResult


class SearchSkill(BaseSkill):
    name = "search"

    def __init__(self, searxng_url: str = "http://searxng:8080"):
        self.searxng_url = searxng_url

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{self.searxng_url}/search",
                    params={"q": user_input, "format": "json", "engines": "google,bing"},
                    timeout=10,
                )
                data = resp.json()
                results = data.get("results", [])[:5]
                if not results:
                    return SkillResult(text="没有找到相关信息")
                lines = [f"- {r['title']}: {r.get('content', '')[:100]}" for r in results]
                text = "搜索到以下结果:\n" + "\n".join(lines)
                return SkillResult(text=text, data={"results": results})
        except Exception:
            return SkillResult(text="暂时无法完成搜索，请稍后再试")


search_skill = SearchSkill()
