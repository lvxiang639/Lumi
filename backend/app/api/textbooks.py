"""Textbook API — pre-loaded 苏教版 curriculum structure."""

from fastapi import APIRouter

router = APIRouter(prefix="/api/textbooks", tags=["textbooks"])

# Pre-loaded 苏教版 三年级上册 curriculum
TEXTBOOKS = {
    "math_3": {
        "id": "math_3",
        "title": "三年级上 · 数学",
        "publisher": "苏教版",
        "grade": 3,
        "subject": "数学",
        "units": [
            {"name": "第一单元 两、三位数乘一位数", "lessons": ["整十整百数乘一位数", "两位数乘一位数（不进位）", "两位数乘一位数（进位）", "三位数乘一位数", "乘数中间或末尾有0的乘法"]},
            {"name": "第二单元 千克和克", "lessons": ["认识千克", "认识克", "千克与克的换算"]},
            {"name": "第三单元 长方形和正方形", "lessons": ["认识长方形和正方形", "周长的认识", "长方形和正方形的周长计算"]},
            {"name": "第四单元 两、三位数除以一位数", "lessons": ["整十整百数除以一位数", "两位数除以一位数", "三位数除以一位数", "除法的验算"]},
            {"name": "第五单元 解决问题的策略", "lessons": ["从条件出发思考", "画线段图解决问题", "列表法解决问题"]},
            {"name": "第六单元 平移、旋转和轴对称", "lessons": ["平移与旋转", "认识轴对称图形"]},
            {"name": "第七单元 分数的初步认识", "lessons": ["认识几分之一", "认识几分之几", "同分母分数的加减法"]},
        ],
    },
    "chinese_3": {
        "id": "chinese_3",
        "title": "三年级上 · 语文",
        "publisher": "苏教版",
        "grade": 3,
        "subject": "语文",
        "units": [
            {"name": "第一单元", "lessons": ["1 大青树下的小学", "2 花的学校", "3 不懂就要问", "口语交际：我的暑假生活", "习作：猜猜他是谁"]},
            {"name": "第二单元", "lessons": ["4 古诗三首（山行/赠刘景文/夜书所见）", "5 铺满金色巴掌的水泥道", "6 秋天的雨", "7 听听，秋的声音", "习作：写日记"]},
            {"name": "第三单元", "lessons": ["8 去年的树", "9 那一定会很好", "10 在牛肚子里旅行", "11 一块奶酪", "习作：我来编童话"]},
            {"name": "第四单元", "lessons": ["12 总也倒不了的老屋", "13 胡萝卜先生的长胡子", "14 小狗学叫", "习作：续写故事"]},
        ],
    },
    "english_3": {
        "id": "english_3",
        "title": "三年级上 · 英语",
        "publisher": "译林版",
        "grade": 3,
        "subject": "英语",
        "units": [
            {"name": "Unit 1 Hello!", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time"]},
            {"name": "Unit 2 I'm Liu Tao", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time"]},
            {"name": "Unit 3 My friends", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time"]},
            {"name": "Unit 4 My family", "lessons": ["Story time", "Fun time", "Cartoon time", "Letter time", "Song time"]},
        ],
    },
}


@router.get("")
async def list_textbooks():
    return {"items": list(TEXTBOOKS.values())}


@router.get("/{book_id}")
async def get_textbook(book_id: str):
    book = TEXTBOOKS.get(book_id)
    if not book:
        return {"error": "Not found"}
    return book
