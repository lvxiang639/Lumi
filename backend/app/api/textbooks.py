"""Textbook API — pre-loaded 苏教版/译林版 curriculum."""

import json
from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_current_user
from app.database import async_session, get_db
from app.models import User
from app.models.lesson_content import LessonContent
from app.services.llm_service import llm_router

router = APIRouter(prefix="/api/textbooks", tags=["textbooks"])

TEXTBOOKS = {
    "math_3_up": {
        "id": "math_3_up", "title": "三年级上 · 数学", "publisher": "苏教版", "grade": 3, "subject": "数学",
        "units": [
            {"name": "一 两、三位数乘一位数", "lessons": ["整十整百数乘一位数", "两位数乘一位数（不进位）", "两位数乘一位数（进位）", "三位数乘一位数", "乘数中间或末尾有0的乘法", "练习一"]},
            {"name": "二 千克和克", "lessons": ["认识千克", "认识克", "千克与克的换算", "练习二"]},
            {"name": "三 长方形和正方形", "lessons": ["认识长方形和正方形", "周长的认识", "长方形和正方形的周长计算", "练习三"]},
            {"name": "四 两、三位数除以一位数", "lessons": ["整十整百数除以一位数", "两位数除以一位数", "三位数除以一位数", "除法的验算", "商中间或末尾有0的除法", "练习四"]},
            {"name": "五 解决问题的策略", "lessons": ["从条件出发思考", "画线段图解决问题", "列表法解决问题", "练习五"]},
            {"name": "六 平移、旋转和轴对称", "lessons": ["平移与旋转", "认识轴对称图形", "练习六"]},
            {"name": "七 分数的初步认识（一）", "lessons": ["认识几分之一", "认识几分之几", "同分母分数的加减法", "练习七"]},
            {"name": "八 期末复习", "lessons": ["数的运算复习", "图形与测量复习", "解决问题复习"]},
        ],
    },
    "math_3_down": {
        "id": "math_3_down", "title": "三年级下 · 数学", "publisher": "苏教版", "grade": 3, "subject": "数学",
        "units": [
            {"name": "一 两位数乘两位数", "lessons": ["两位数乘两位数的口算", "两位数乘两位数的笔算（不进位）", "两位数乘两位数的笔算（进位）", "练习一"]},
            {"name": "二 千米和吨", "lessons": ["认识千米", "认识吨", "千米和吨的换算", "练习二"]},
            {"name": "三 解决问题的策略", "lessons": ["从问题出发思考", "画线段图分析数量关系", "练习三"]},
            {"name": "四 混合运算", "lessons": ["乘法和加减法的混合运算", "除法和加减法的混合运算", "含有小括号的混合运算", "练习四"]},
            {"name": "五 年、月、日", "lessons": ["认识年月日", "平年和闰年", "24时计时法", "练习五"]},
            {"name": "六 长方形和正方形的面积", "lessons": ["面积的含义", "面积单位", "长方形和正方形的面积计算", "面积单位间的进率", "练习六"]},
            {"name": "七 分数的初步认识（二）", "lessons": ["认识一个整体的几分之一", "认识一个整体的几分之几", "求一个数的几分之几", "练习七"]},
            {"name": "八 小数的初步认识", "lessons": ["小数的含义和读写", "比较小数的大小", "简单的小数加减法", "练习八"]},
            {"name": "九 数据的收集和整理（二）", "lessons": ["简单的数据汇总", "简单的数据排序和分组", "练习九"]},
            {"name": "十 期末复习", "lessons": ["数与代数复习", "图形与几何复习", "统计与概率复习"]},
        ],
    },
    "chinese_3_up": {
        "id": "chinese_3_up", "title": "三年级上 · 语文", "publisher": "苏教版", "grade": 3, "subject": "语文",
        "units": [
            {"name": "第一单元", "lessons": ["1 大青树下的小学", "2 花的学校", "3 不懂就要问", "口语交际：我的暑假生活", "习作：猜猜他是谁", "语文园地一"]},
            {"name": "第二单元", "lessons": ["4 古诗三首（山行/赠刘景文/夜书所见）", "5 铺满金色巴掌的水泥道", "6 秋天的雨", "7 听听，秋的声音", "习作：写日记", "语文园地二"]},
            {"name": "第三单元", "lessons": ["8 去年的树", "9 那一定会很好", "10 在牛肚子里旅行", "11 一块奶酪", "习作：我来编童话", "语文园地三"]},
            {"name": "第四单元", "lessons": ["12 总也倒不了的老屋", "13 胡萝卜先生的长胡子", "14 小狗学叫", "习作：续写故事", "语文园地四"]},
            {"name": "第五单元", "lessons": ["15 搭船的鸟", "16 金色的草地", "习作：我们眼中的缤纷世界"]},
            {"name": "第六单元", "lessons": ["17 古诗三首（望天门山/饮湖上初晴后雨/望洞庭）", "18 富饶的西沙群岛", "19 海滨小城", "20 美丽的小兴安岭", "习作：这儿真美", "语文园地六"]},
            {"name": "第七单元", "lessons": ["21 大自然的声音", "22 父亲、树林和鸟", "23 带刺的朋友", "习作：我有一个想法", "语文园地七"]},
            {"name": "第八单元", "lessons": ["24 司马光", "25 掌声", "26 灰雀", "27 手术台就是阵地", "习作：那次玩得真高兴", "语文园地八"]},
        ],
    },
    "chinese_3_down": {
        "id": "chinese_3_down", "title": "三年级下 · 语文", "publisher": "苏教版", "grade": 3, "subject": "语文",
        "units": [
            {"name": "第一单元", "lessons": ["1 古诗三首（绝句/惠崇春江晚景/三衢道中）", "2 燕子", "3 荷花", "4 昆虫备忘录", "口语交际：春游去哪儿玩", "习作：我的植物朋友", "语文园地一"]},
            {"name": "第二单元", "lessons": ["5 守株待兔", "6 陶罐和铁罐", "7 鹿角和鹿腿", "8 池子与河流", "习作：看图画写一写", "语文园地二"]},
            {"name": "第三单元", "lessons": ["9 古诗三首（元日/清明/九月九日忆山东兄弟）", "10 纸的发明", "11 赵州桥", "12 一幅名扬中外的画", "综合性学习：中华传统节日", "语文园地三"]},
            {"name": "第四单元", "lessons": ["13 花钟", "14 蜜蜂", "15 小虾", "习作：我做了一项小实验", "语文园地四"]},
            {"name": "第五单元", "lessons": ["16 小真的长头发", "17 我变成了一棵树", "习作：奇妙的想象"]},
            {"name": "第六单元", "lessons": ["18 童年的水墨画", "19 剃头大师", "20 肥皂泡", "21 我不能失信", "习作：身边那些有特点的人", "语文园地六"]},
            {"name": "第七单元", "lessons": ["22 我们奇妙的世界", "23 海底世界", "24 火烧云", "口语交际：劝说", "习作：国宝大熊猫", "语文园地七"]},
            {"name": "第八单元", "lessons": ["25 慢性子裁缝和急性子顾客", "26 方帽子店", "27 漏", "28 枣核", "习作：这样想象真有趣", "语文园地八"]},
        ],
    },
    "english_3_up": {
        "id": "english_3_up", "title": "三年级上 · 英语", "publisher": "译林版", "grade": 3, "subject": "英语",
        "units": [
            {"name": "Unit 1 Hello!", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 2 I'm Liu Tao", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 3 My friends", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 4 My family", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 5 Look at me!", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 6 Colours", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 7 Would you like a pie?", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
            {"name": "Unit 8 Happy New Year!", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time", "Checkout time"]},
        ],
    },
    "english_3_down": {
        "id": "english_3_down", "title": "三年级下 · 英语", "publisher": "译林版", "grade": 3, "subject": "英语",
        "units": [
            {"name": "Unit 1 In class", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 2 In the library", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 3 Is this your pencil?", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 4 Where's the bird?", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 5 How old are you?", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 6 What time is it?", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 7 On the farm", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
            {"name": "Unit 8 We're twins!", "lessons": ["Story time", "Fun time", "Cartoon time", "Sound time", "Song time", "Checkout time"]},
        ],
    },
}

@router.get("")
async def list_textbooks():
    return {"items": list(TEXTBOOKS.values())}

@router.get("/{book_id}")
async def get_textbook(book_id: str):
    book = TEXTBOOKS.get(book_id)
    if not book: return {"error": "Not found"}
    return book


@router.get("/{book_id}/lesson/{lesson_name:path}")
async def get_lesson_detail(
    book_id: str, lesson_name: str,
    db: AsyncSession = Depends(get_db),
):
    """Get lesson detail. Loads from DB cache, generates + caches via AI if missing."""
    book = TEXTBOOKS.get(book_id)
    if not book: return {"error": "Book not found"}

    unit_name = ""
    for unit in book.get("units", []):
        for lesson in unit.get("lessons", []):
            if lesson == lesson_name:
                unit_name = unit["name"]
                break

    if not unit_name: return {"error": "Lesson not found"}

    # 1. Try DB cache
    r = await db.execute(
        select(LessonContent).where(
            LessonContent.subject == book["subject"],
            LessonContent.grade == book["grade"],
            LessonContent.lesson_name == lesson_name,
        )
    )
    cached = r.scalar_one_or_none()

    if cached and cached.content:
        return {
            "book": book["title"], "subject": book["subject"], "grade": book["grade"],
            "unit": unit_name, "lesson": lesson_name,
            "content": cached.content,
            "key_points": json.loads(cached.key_points) if cached.key_points else [],
            "cached": True,
        }

    # 2. Generate via AI + store
    prompt = f"""请介绍{book['grade']}年级{book['subject']}课本中「{lesson_name}」这一课的内容。

要求:
- 2-3段话，介绍这节课的核心概念和主要知识点
- 语言简洁清晰，家长和学生都能看懂
- 可以包含1-2个简单的例子
- 不超过200字

内容:"""

    content = await llm_router.chat([{"role": "user", "content": prompt}], max_tokens=300, temperature=0.5)
    content = (content or "").strip()

    # Also generate key points
    kp_prompt = f"列出{book['grade']}年级{book['subject']}「{lesson_name}」的3-5个关键知识点，每行一个，不要序号。"
    kp_raw = await llm_router.chat([{"role": "user", "content": kp_prompt}], max_tokens=100, temperature=0.3)
    key_points = [k.strip() for k in (kp_raw or "").split("\n") if k.strip()][:5]

    # Save to DB
    db.add(LessonContent(
        subject=book["subject"], grade=book["grade"],
        lesson_name=lesson_name,
        content=content or f"「{lesson_name}」是{book['title']}中的一课。",
        key_points=json.dumps(key_points, ensure_ascii=False),
    ))
    await db.commit()

    return {
        "book": book["title"], "subject": book["subject"], "grade": book["grade"],
        "unit": unit_name, "lesson": lesson_name,
        "content": content, "key_points": key_points, "cached": False,
    }


# ── Real lesson content for key math lessons ──

LESSON_CONTENTS: dict[str, str] = {
    "数学_整十整百数乘一位数": "整十、整百数乘一位数的口算方法：先把整十、整百数看作几个十或几个百，再与一位数相乘。例如：20×3，先把20看作2个十，2个十×3=6个十，即60。",
    "数学_两位数乘一位数（不进位）": "两位数乘一位数（不进位）的笔算方法：相同数位对齐，从个位乘起，用一位数依次乘两位数每一位上的数，与哪一位上的数相乘，积就写在那一位的下面。",
    "数学_两位数乘一位数（进位）": "两位数乘一位数（进位）的笔算方法：相同数位对齐，从个位乘起，个位满几十就向十位进几。计算十位时，要加上进上来的数。",
    "数学_三位数乘一位数": "三位数乘一位数的笔算方法：与两位数乘一位数类似，从个位起依次乘每一位，哪一位上乘得的积满几十就向前一位进几。",
    "数学_认识千克": "千克是质量单位，用符号kg表示。1千克=1000克。称比较重的物品常用千克作单位。生活中常见的1千克物品：两瓶矿泉水、一袋盐等。",
    "数学_认识克": "克是质量单位，用符号g表示。称比较轻的物品常用克作单位。一枚2分硬币约重1克。1千克=1000克。",
    "数学_认识长方形和正方形": "长方形有4条边，对边相等，4个角都是直角。正方形是特殊的长方形，4条边都相等，4个角都是直角。长方形的长边叫做'长'，短边叫做'宽'。",
    "数学_周长的认识": "封闭图形一周的长度叫做周长。长方形的周长=(长+宽)×2，正方形的周长=边长×4。",
    "数学_整十整百数除以一位数": "整十、整百数除以一位数的口算方法：把整十、整百数看作几个十或几个百，再除以一位数。例如：60÷3，60是6个十，6个十÷3=2个十，即20。",
    "数学_认识几分之一": "把一些物体或一个图形平均分成几份，每份就是它的几分之一。分数写法：先写分数线，再写分母，最后写分子。例如：1/2读作二分之一。",
    "数学_认识几分之几": "把一些物体或一个图形平均分成若干份，取其中的几份，就是它的几分之几。分母表示平均分的份数，分子表示取的份数。",
    "数学_两位数乘两位数的口算": "先用整十数的十位上的数与另一个因数相乘，再在积的末尾添上一个0。例如：20×14，先算2×14=28，再在28后面添一个0，得280。",
    "数学_认识年月日": "一年有12个月。大月(31天)：1月、3月、5月、7月、8月、10月、12月。小月(30天)：4月、6月、9月、11月。二月：平年28天，闰年29天。",
    "数学_面积的含义": "物体的表面或封闭图形的大小叫做面积。比较面积的大小可以用观察法、重叠法、数方格法。",
    "数学_长方形和正方形的面积计算": "长方形的面积=长×宽，正方形的面积=边长×边长。面积单位：平方厘米(cm²)、平方分米(dm²)、平方米(m²)。",
    "数学_小数的含义和读写": "像0.5、1.2、3.8这样的数叫做小数。小数中的圆点叫做小数点。小数点左边是整数部分，右边是小数部分。读小数时，整数部分按整数读法，小数部分顺次读出每个数字。",
    "数学_认识千米": "千米是长度单位，用符号km表示。1千米=1000米。计量比较长的路程通常用千米作单位。",
    "数学_认识吨": "吨是质量单位，用符号t表示。1吨=1000千克。计量比较重的物品或大宗物品的质量通常用吨作单位。",
    "数学_平移与旋转": "物体沿直线方向移动叫做平移。物体围绕一个点或轴转动叫做旋转。平移时物体的形状、大小不变，只是位置改变。",
    "数学_认识轴对称图形": "如果一个图形沿一条直线对折后两边完全重合，这样的图形叫做轴对称图形。这条直线叫做对称轴。",
}

KNOWLEDGE_MAP: dict[str, list[str]] = {
    "整十整百数乘一位数": ["乘法口诀", "数的组成", "几个十就是几十", "几个百就是几百"],
    "两位数乘一位数（不进位）": ["乘法口诀", "数位对齐", "从个位乘起"],
    "两位数乘一位数（进位）": ["乘法口诀", "进位规则", "满十进一"],
    "三位数乘一位数": ["数位对齐", "连续进位", "乘数中间有0"],
    "认识千克": ["质量单位", "千克kg", "1kg=1000g", "估测质量"],
    "认识克": ["质量单位", "克g", "称量轻物品", "千克与克换算"],
    "认识长方形和正方形": ["四边形特征", "对边相等", "四个直角", "正方形四条边相等"],
    "周长的认识": ["周长定义", "长方形的周长=(长+宽)×2", "正方形的周长=边长×4"],
    "认识几分之一": ["平均分", "分数意义", "分子分母分数线", "读写分数"],
    "认识几分之几": ["几分之几的意义", "分母表示份数", "分子表示取的份数"],
    "面积的含义": ["面积定义", "比较面积大小", "数方格法"],
}


@router.post("/summary")
async def get_lesson_summary(
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """Generate a brief summary of what a textbook lesson covers."""
    lesson = body.get("lesson", "")
    subject = body.get("subject", "数学")
    grade = body.get("grade", 3)

    prompt = f"""请用2-3句话介绍{grade}年级{subject}课本中「{lesson}」这一课主要讲什么内容。

要求:
- 简洁明了，家长看完就能知道这节课的重点
- 可以提到1-2个核心概念或方法
- 语气亲切，像老师在介绍
- 不超过100字

介绍:"""

    summary = await llm_router.chat([{"role": "user", "content": prompt}], max_tokens=200, temperature=0.5)
    return {"lesson": lesson, "summary": (summary or "").strip()}
