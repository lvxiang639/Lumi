import asyncio
import logging
import re
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

# ── Query type patterns ──────────────────────────────────────────────

FINANCE_KEYWORDS = (
    "股价", "股票", "价格", "行情", "涨了", "跌了",
    "BTC", "ETH", "比特币", "以太坊", "加密货币",
    "美元", "汇率", "人民币", "港币", "日元",
    "黄金", "白银", "原油", "期货",
    "纳斯达克", "标普", "道琼斯", "恒生", "上证", "A股",
    "每股收益", "市盈率", "市值",
)
WEATHER_KEYWORDS = (
    "天气", "下雨", "下雪", "多少度", "温度", "湿度",
    "刮风", "台风", "雾霾", "PM2.5", "紫外线",
    "明天", "后天", "一周天气",
)
NEWS_KEYWORDS = (
    "新闻", "最新", "热点", "头条", "快讯",
    "发生了什么", "最近有什么", "今天有什么大事",
)


def _detect_query_type(query: str) -> str:
    """Detect the type of search query for source routing."""
    q = query.upper()

    # Finance
    if any(kw.upper() in q for kw in FINANCE_KEYWORDS):
        return "finance"
    if re.search(r'\b[A-Z]{2,5}[- ]?\d+', query):  # stock ticker pattern
        return "finance"
    if re.search(r'\$\d+|\d+元|\d+美金', query):
        return "finance"

    # Weather
    if any(kw in query for kw in WEATHER_KEYWORDS):
        return "weather"

    # News
    if any(kw in query for kw in NEWS_KEYWORDS):
        return "news"

    return "general"


# ── Search Skill ───────────────────────────────────────────────────────

class SearchSkill(BaseSkill):
    name = "search"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        try:
            # Step 1: Extract clean search query
            query = await self._extract_query(user_input)
            logger.info("search query: %s -> %s", user_input[:60], query)

            # Step 2: Determine query type + route to sources
            qtype = _detect_query_type(query)
            logger.info("search type: %s for '%s'", qtype, query[:60])

            # Step 3: Multi-source search
            all_results = []
            tasks = []

            if qtype == "finance":
                tasks.append(("finance", self._search_finance(query)))
            elif qtype == "weather":
                tasks.append(("weather", self._search_weather(query)))
            elif qtype == "news":
                tasks.append(("news", self._search_news(query)))

            # Always include general search as fallback
            tasks.append(("general", self._search_searxng(query)))

            # Run all searches concurrently
            results_map = {}
            for label, task in tasks:
                try:
                    results_map[label] = await task
                except Exception:
                    logger.exception("search source %s failed", label)
                    results_map[label] = []

            # Merge results: specialized first, then general
            for label, results in results_map.items():
                for r in results:
                    r["_source"] = label
                all_results.extend(results)

            # Deduplicate by URL
            seen_urls = set()
            deduped = []
            for r in all_results:
                url = r.get("url", "")
                if url and url in seen_urls:
                    continue
                seen_urls.add(url)
                deduped.append(r)
            all_results = deduped[:8]

            # Step 4: Re-rank + synthesize
            llm_answer = ""
            if all_results:
                llm_answer = await self._synthesize(query, all_results)

            if not all_results and not llm_answer:
                return SkillResult(text="没有找到相关信息，请尝试换个关键词搜索")

            # Build response
            parts = []
            if llm_answer:
                parts.append(llm_answer.strip())

            if all_results:
                parts.append("\n📎 参考来源:")
                for i, r in enumerate(all_results[:5]):
                    title = r.get('title', '')
                    content = r.get('content', '')
                    url = r.get('url', '')
                    source = r.get('_source', '')
                    source_label = {"finance": "财经", "weather": "天气", "news": "新闻", "general": "搜索"}.get(source, "")
                    parts.append(f"\n{i + 1}. **{title}** {f'[{source_label}]' if source_label else ''}")
                    if content:
                        parts.append(f"   {content}")
                    if url:
                        parts.append(f"   🔗 {url}")

            text = "\n".join(parts)
            return SkillResult(text=text, data={
                "query": query,
                "results": all_results,
                "llm_answer": llm_answer,
            })

        except Exception:
            logger.exception("search skill failed")
            return SkillResult(text="暂时无法完成搜索，请稍后再试")

    # ── Source: Finance (Sina + CoinGecko, all free) ────────────────────

    # sina symbol mapping: ticker → sina list code
    _SINA_REFERER = "https://finance.sina.com.cn"

    async def _search_finance(self, query: str) -> list[dict]:
        """Search financial data via free APIs.
        - Sina Finance: A-shares, US stocks, HK stocks, forex — free, no key, stable 10+ years
        - CoinGecko: cryptocurrency — free, no key, 10-30 calls/min
        """
        results = []

        # 1. Try Sina Finance for stocks/forex
        sina_code = self._resolve_sina_code(query)
        if not sina_code:
            # Chinese stock name without ticker (e.g. "长电科技") — search for code first
            sina_code = await self._find_stock_code(query)

        if sina_code:
            try:
                async with httpx.AsyncClient() as client:
                    resp = await client.get(
                        f"https://hq.sinajs.cn/list={sina_code}",
                        headers={"Referer": self._SINA_REFERER},
                        timeout=8,
                    )
                    if resp.status_code == 200:
                        text = resp.text
                        results = self._parse_sina_response(text, sina_code)
            except Exception:
                logger.exception("sina finance failed")

        # 2. CoinGecko for crypto
        if not results:
            try:
                crypto_match = re.search(
                    r'(BTC|ETH|SOL|DOGE|XRP|BNB|ADA|MATIC|[A-Z]{2,6})', query.upper()
                )
                if crypto_match:
                    symbol = crypto_match.group(1).lower()
                    async with httpx.AsyncClient() as client:
                        resp = await client.get(
                            "https://api.coingecko.com/api/v3/search",
                            params={"query": symbol},
                            timeout=10,
                        )
                        if resp.status_code == 200:
                            data = resp.json()
                            coins = data.get("coins", [])
                            if coins:
                                coin_id = coins[0]["id"]
                                coin_name = coins[0]["name"]
                                price_resp = await client.get(
                                    "https://api.coingecko.com/api/v3/simple/price",
                                    params={
                                        "ids": coin_id,
                                        "vs_currencies": "usd,cny",
                                        "include_24hr_change": "true",
                                    },
                                    timeout=10,
                                )
                                if price_resp.status_code == 200:
                                    price_data = price_resp.json()
                                    if coin_id in price_data:
                                        d = price_data[coin_id]
                                        results.append({
                                            "title": f"{coin_name} ({symbol.upper()}) 实时价格",
                                            "content": (
                                                f"USD: ${d.get('usd', '?')} | "
                                                f"CNY: ¥{d.get('cny', '?')} | "
                                                f"24h涨跌: {d.get('usd_24h_change', 0):+.2f}%"
                                            ),
                                            "url": f"https://www.coingecko.com/en/coins/{coin_id}",
                                        })
            except Exception:
                logger.exception("coingecko search failed")

        # 3. Fallback: SearXNG web search
        if not results:
            try:
                results = await self._search_searxng(f"{query} 股价 行情")
                for r in results:
                    r["_source"] = "finance"
            except Exception:
                pass

        return results

    def _resolve_sina_code(self, query: str) -> str | None:
        """Resolve a stock/forex query to Sina Finance list code."""
        # Stock ticker patterns
        # A-share: 6-digit number → sh/sh+code or sz+code
        a_share = re.search(r'\b(\d{6})\b', query)
        if a_share:
            code = a_share.group(1)
            # 60xxxx → sh, 00xxxx/30xxxx → sz, 68xxxx → sh (科创板)
            if code.startswith(('60', '68')):
                return f"sh{code}"
            return f"sz{code}"

        # Named A-share: 贵州茅台, 宁德时代, etc — try search-like query
        # US stock: AAPL, TSLA, GOOGL, MSFT, etc
        us_stock = re.search(r'\b([A-Z]{1,5})\b', query)
        if us_stock:
            ticker = us_stock.group(1).lower()
            # Skip common words and crypto
            if ticker not in ("BTC", "ETH", "A", "I", "AT", "TO", "BE", "IN", "IF"):
                return f"gb_{ticker}"

        # HK stock: 00700, 09988, etc
        hk_stock = re.search(r'\b(\d{5})\b', query)
        if hk_stock:
            return f"hk{hk_stock.group(1)}"

        # Forex: 美元人民币, USDCNY, etc
        forex_map = {
            "美元人民币": "fx_susdcny", "usdcny": "fx_susdcny",
            "美元日元": "fx_susdjpy", "usdjpy": "fx_susdjpy",
            "欧元美元": "fx_seurusd", "eurusd": "fx_seurusd",
            "英镑美元": "fx_sgbpusd", "gbpusd": "fx_sgbpusd",
        }
        ql = query.lower().replace(" ", "").replace("/", "").replace("兑", "")
        for key, code in forex_map.items():
            if key in ql:
                return code

        return None

    async def _find_stock_code(self, query: str) -> str | None:
        """Search for a stock code by company name via SearXNG + extract from results."""
        try:
            # Quick local check for common Chinese stock names
            common_stocks = {
                "茅台": "sh600519", "平安": "sh601318", "招商银行": "sh600036",
                "万科": "sz000002", "比亚迪": "sz002594", "宁德时代": "sz300750",
                "中芯国际": "sh688981", "腾讯": "hk00700", "阿里巴巴": "hk09988",
                "美团": "hk03690", "京东": "hk09618", "百度": "hk09888",
                "小米": "hk01810", "苹果": "gb_aapl", "特斯拉": "gb_tsla",
                "谷歌": "gb_goog", "微软": "gb_msft", "英伟达": "gb_nvda",
                "茅台": "sh600519",
            }
            for name, code in common_stocks.items():
                if name in query:
                    return code

            # Search for stock code via SearXNG
            search_results = await self._search_searxng(f"{query} 股票代码")
            for r in search_results:
                content = (r.get("content", "") + r.get("title", "")).upper()
                # Extract 6-digit A-share code
                code_match = re.search(r'\b(\d{6})\b', content)
                if code_match:
                    code = code_match.group(1)
                    if code.startswith(('60', '68')):
                        return f"sh{code}"
                    return f"sz{code}"
                # Extract US ticker
                us_match = re.search(r'\b([A-Z]{2,5})\b(?:\s*[\(（])', content)
                if us_match:
                    return f"gb_{us_match.group(1).lower()}"
        except Exception:
            pass
        return None

    def _parse_sina_response(self, text: str, code: str) -> list[dict]:
        """Parse Sina Finance response into structured data."""
        if not text or "FAILED" in text:
            return []

        try:
            # Format: var hq_str_xx="name,open,close,current,high,low,..."
            parts = text.split('"')[1].split(",") if '"' in text else text.split(",")

            if len(parts) < 4:
                return []

            name = parts[0]
            open_price = parts[1]
            prev_close = float(parts[2]) if parts[2] else 0
            current = float(parts[3]) if parts[3] else 0
            high = parts[4] if len(parts) > 4 else ""
            low = parts[5] if len(parts) > 5 else ""

            change_pct = ((current - prev_close) / prev_close * 100) if prev_close else 0
            direction = "📈" if change_pct >= 0 else "📉"

            return [{
                "title": f"{name} 实时行情 {direction}",
                "content": (
                    f"最新: {current} | "
                    f"开盘: {open_price} | "
                    f"昨收: {prev_close} | "
                    f"涨跌: {change_pct:+.2f}% | "
                    f"最高: {high} | "
                    f"最低: {low}"
                ),
                "url": f"https://finance.sina.com.cn/realstock/company/{code}/nc.shtml",
            }]
        except Exception:
            logger.exception("parse sina response failed")
            return []

    # ── Source: Weather ────────────────────────────────────────────────

    async def _search_weather(self, query: str) -> list[dict]:
        """Search weather via wttr.in."""
        try:
            # Extract city name
            city = query
            for kw in WEATHER_KEYWORDS:
                city = city.replace(kw, "")
            city = city.strip().rstrip("的").strip() or "Beijing"

            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"https://wttr.in/{city}?format=j1",
                    timeout=10,
                )
                if resp.status_code == 200:
                    data = resp.json()
                    current = (data.get("current_condition") or [{}])[0]
                    weather_info = data.get("weather", [{}])[0]

                    temp = current.get("temp_C", "?")
                    desc = (current.get("weatherDesc") or [{"value": ""}])[0].get("value", "")
                    humidity = current.get("humidity", "?")
                    wind = current.get("windspeedKmph", "?")
                    max_temp = weather_info.get("maxtempC", "?")
                    min_temp = weather_info.get("mintempC", "?")

                    return [{
                        "title": f"{city} 天气",
                        "content": f"{desc} | 当前 {temp}°C | 湿度 {humidity}% | 风力 {wind}km/h | 最高 {max_temp}°C 最低 {min_temp}°C",
                        "url": f"https://wttr.in/{city}",
                    }]
        except Exception:
            logger.exception("weather search failed")
        return []

    # ── Source: News ────────────────────────────────────────────────────

    async def _search_news(self, query: str) -> list[dict]:
        """Search news via SearXNG news category."""
        try:
            async with httpx.AsyncClient() as client:
                resp = await client.get(
                    f"{settings.searxng_url}/search",
                    params={
                        "q": query, "format": "json",
                        "categories": "news",
                        "engines": settings.searxng_engines,
                    },
                    timeout=15,
                )
                resp.raise_for_status()
                data = resp.json()
                results = data.get("results", [])[:5]
                for r in results:
                    r["_source"] = "news"
                return results
        except Exception:
            logger.exception("news search failed")
        return []

    # ── Source: General (SearXNG + DuckDuckGo) ──────────────────────────

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

    # ── LLM Synthesis ──────────────────────────────────────────────────

    async def _synthesize(self, query: str, results: list[dict]) -> str:
        """Ask LLM to synthesize an answer from search results."""
        try:
            from datetime import datetime, timezone, timedelta
            now = datetime.now(timezone(timedelta(hours=8)))

            results_text = ""
            for i, r in enumerate(results[:6]):
                title = r.get('title', '')
                content = r.get('content', '')
                source = r.get('_source', '')
                results_text += f"\n[{i + 1}] [{source}] {title}\n{content}\n"

            prompt = SYNTHESIS_PROMPT.format(
                query=query,
                current_time=now.strftime("%Y-%m-%d %H:%M"),
                search_results=results_text,
            )
            return await llm_router.chat([{"role": "user", "content": prompt}])
        except Exception:
            logger.exception("synthesis failed")
            return ""

    # ── Query Extraction ──────────────────────────────────────────────

    async def _extract_query(self, user_input: str) -> str:
        try:
            clean_input = user_input
            if "用户最新输入:" in user_input:
                clean_input = user_input.split("用户最新输入:")[-1].strip()
            elif user_input.startswith("【对话上下文"):
                lines = user_input.strip().split("\n")
                clean_input = lines[-1] if lines else user_input

            raw = await llm_router.chat([
                {"role": "user", "content": QUERY_PROMPT.format(user_input=clean_input)},
            ])
            data = parse_json(raw)
            query = data.get("query", "").strip()
            if query:
                return query
            return clean_input if clean_input else user_input
        except Exception:
            if "用户最新输入:" in user_input:
                return user_input.split("用户最新输入:")[-1].strip()
            return user_input


search_skill = SearchSkill()
