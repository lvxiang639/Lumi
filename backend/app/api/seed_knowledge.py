"""Seed knowledge points for primary/middle school education."""

import uuid
from app.database import async_session
from app.models.knowledge_point import KnowledgePoint

# ── Primary School Math (1-6) ─────────────────────────────────────────

MATH_POINTS = [
    # Grade 1
    (None, "数的认识", 1, "数学", 1, "数数,认识数字,数字"),
    (None, "10以内加减法", 1, "数学", 1, "加法,减法,口算,10以内"),
    (None, "认识图形", 1, "数学", 1, "图形,圆形,方形,三角形"),
    # Grade 2
    (None, "100以内加减法", 2, "数学", 1, "加法,减法,口算,竖式,100以内"),
    (None, "乘法口诀", 2, "数学", 1, "乘法,九九乘法表,口诀"),
    (None, "长度单位", 2, "数学", 1, "厘米,米,长度,单位换算"),
    # Grade 3
    (None, "万以内加减法", 3, "数学", 1, "加法,减法,万以内,口算"),
    (None, "多位数乘法", 3, "数学", 1, "乘法,多位数,竖式"),
    (None, "除法初步", 3, "数学", 1, "除法,整除,余数"),
    (None, "分数初步", 3, "数学", 1, "分数,几分之几,分子,分母"),
    (None, "周长与面积", 3, "数学", 1, "周长,面积,长方形,正方形"),
    # Grade 4
    (None, "大数认识", 4, "数学", 1, "亿,大数,读写,数位"),
    (None, "三位数乘两位数", 4, "数学", 1, "乘法,三位数,两位数,竖式"),
    (None, "除法是两位数的除法", 4, "数学", 1, "除法,两位数除数,试商"),
    (None, "小数", 4, "数学", 1, "小数,小数点,加减,比较"),
    (None, "平行四边形和梯形", 4, "数学", 1, "平行四边形,梯形,面积"),
    # Grade 5
    (None, "小数乘除法", 5, "数学", 1, "小数,乘法,除法,小数点"),
    (None, "简易方程", 5, "数学", 1, "方程,未知数,解方程,等式"),
    (None, "多边形面积", 5, "数学", 1, "三角形面积,梯形面积,组合图形"),
    (None, "分数加减法", 5, "数学", 1, "分数,通分,约分,加减"),
    # Grade 6
    (None, "分数乘除法", 6, "数学", 1, "分数,乘法,除法,倒数"),
    (None, "比和比例", 6, "数学", 1, "比,比例,比值,正比例,反比例"),
    (None, "圆", 6, "数学", 1, "圆,周长,面积,圆周率"),
    (None, "百分数", 6, "数学", 1, "百分数,百分比,折扣,税率"),
    (None, "圆柱与圆锥", 6, "数学", 1, "圆柱,圆锥,体积,表面积"),
]

# ── Primary/Middle School Chinese (1-9) ────────────────────────────────

CHINESE_POINTS = [
    (None, "拼音", 1, "语文", 1, "拼音,声母,韵母,声调"),
    (None, "识字写字", 1, "语文", 1, "汉字,笔画,笔顺,偏旁"),
    (None, "词语积累", 2, "语文", 1, "词语,近义词,反义词,成语"),
    (None, "阅读理解", 3, "语文", 1, "阅读,理解,问答,中心思想"),
    (None, "作文起步", 3, "语文", 1, "看图写话,日记,作文"),
    (None, "修辞手法", 4, "语文", 1, "比喻,拟人,排比,夸张"),
    (None, "古诗词背诵", 4, "语文", 1, "古诗,诗词,七言,五言,背诵"),
    (None, "文言文入门", 5, "语文", 1, "文言文,古文,翻译,虚词"),
    (None, "阅读理解进阶", 5, "语文", 1, "阅读理解,归纳,概括,赏析"),
    (None, "记叙文写作", 6, "语文", 1, "记叙文,写作,时间地点人物"),
    (None, "说明文", 7, "语文", 1, "说明文,说明方法,科普"),
    (None, "议论文", 8, "语文", 1, "议论文,论点,论据,论证"),
    (None, "文言文进阶", 8, "语文", 1, "文言文,实词,虚词,翻译,断句"),
    (None, "古诗词鉴赏", 9, "语文", 1, "古诗词,意象,意境,赏析"),
]

# ── Common topics (cross-grade) ────────────────────────────────────────

COMMON_POINTS = [
    (None, "应用题", 0, "数学", 1, "应用题,解决问题,行程,工程,盈亏"),
    (None, "奥数", 0, "数学", 1, "奥数,竞赛,思维,逻辑,推理"),
]

ALL_POINTS = MATH_POINTS + CHINESE_POINTS + COMMON_POINTS


async def seed_knowledge_points():
    """Insert default knowledge points. Safe to call multiple times."""
    async with async_session() as db:
        from sqlalchemy import select, func
        r = await db.execute(select(func.count(KnowledgePoint.id)))
        if (r.scalar() or 0) > 0:
            return  # already seeded

        for parent_id, name, grade, subject, level, keywords in ALL_POINTS:
            db.add(KnowledgePoint(
                parent_id=parent_id, name=name, grade=grade,
                subject=subject, level=level, keywords=keywords,
            ))
        await db.commit()
        from app.services.llm_service import llm_router
        import logging
        logger = logging.getLogger(__name__)
        logger.info("Seeded %d knowledge points", len(ALL_POINTS))
