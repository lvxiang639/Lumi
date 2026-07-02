"""Textbook API — pre-loaded 苏教版/译林版 curriculum."""

from fastapi import APIRouter

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
