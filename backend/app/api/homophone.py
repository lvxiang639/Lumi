"""Homophone exercise API — generate, submit, grade, history."""

import json, logging
from uuid import UUID
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models import User
from app.models.homophone_exercise import HomophoneExercise
from app.api.deps import get_current_user
from app.services.llm_service import llm_router

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/study/homophone", tags=["homophone"])

BEIJING_TZ = timezone(timedelta(hours=8))

HOMOPHONE_GENERATE_PROMPT = """你是一位小学语文老师。请生成一组"同音字填空"练习题。

规则：选择5组同音字（每组2-3个常见同音字），每组用一个词语来考学生，把同音字部分挖空让学生填。

例如选了拼音"tóng"的同音字组：同(同学)、童(童话)、铜(铜牌)
出题格式：把词语中的同音字挖掉，展示为 __学、__话、__牌

请严格按照以下JSON格式返回，不要包含其他内容：
{
  "questions": [
    {
      "pinyin": "tóng",
      "words": [
        {"blank": "__学", "answer": "同", "hint": "和'学'组成词语"},
        {"blank": "__话", "answer": "童", "hint": "和'话'组成词语"},
        {"blank": "__牌", "answer": "铜", "hint": "和'牌'组成词语"}
      ]
    },
    {
      "pinyin": "qīng",
      "words": [
        {"blank": "__草", "answer": "青", "hint": "和'草'组成词语"},
        {"blank": "__水", "answer": "清", "hint": "和'水'组成词语"},
        {"blank": "__天", "answer": "晴", "hint": "和'天'组成词语"}
      ]
    }
  ]
}

注意：
- 生成5组同音字（5个不同拼音）
- 每组2-3个同音字词语
- blank字段用"__"代替被挖掉的同音字
- answer是正确答案（被挖掉的那个字）
- hint给学生一点提示
- 优先中小学课本常见字：同/童/铜、青/清/晴、工/公/功、力/立/丽、马/吗/妈、中/钟/忠、元/园/圆"""

HOMOPHONE_GRADE_PROMPT = """你是一位小学语文老师，正在批改同音字填空题。

请判断学生填的每个字是否正确。判断标准：
1. 学生填的字与题目拼音是否同音（声母、韵母、声调都要相同）
2. 学生填的字和后面的字组成的词语是否合理、常见

题目（含正确答案）：
{questions_json}

学生的答案：
{answers_json}

请按以下JSON格式返回批改结果：
{{
  "grading": [
    {{
      "pinyin": "tóng",
      "results": [
        {{"blank": "__学", "filled": "同", "correct": true, "feedback": "正确！"}},
        {{"blank": "__话", "filled": "铜", "correct": false, "feedback": "铜话不是词语。"}}
      ],
      "summary": "这组2题答对1题"
    }}
  ],
  "overall": "太棒了！继续加油！",
  "total_correct": 7,
  "total_items": 10
}}

注意：
- feedback要具体说明为什么对/错（15字以内）
- overall给总体评语，温暖鼓励
- total_correct和total_items要准确统计"""


@router.post("/generate")
async def generate_exercise(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate 5 homophone questions via LLM, save to DB."""
    try:
        raw = await llm_router.chat([{"role": "user", "content": HOMOPHONE_GENERATE_PROMPT}], max_tokens=1024)
        raw = (raw or "").strip()
        # Strip markdown code blocks if present
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1]  # remove opening ```json
            if raw.endswith("```"):
                raw = raw[:-3]
            raw = raw.strip()
        logger.info("homophone generate raw: %s", raw[:200])
        data = json.loads(raw) if raw else {}
        questions = data.get("questions", [])
        if not questions:
            raise ValueError("empty questions")
    except json.JSONDecodeError as e:
        logger.warning("homophone generate JSON parse error: %s", e)
        raise HTTPException(400, "生成失败，请重试")
    except Exception as e:
        logger.warning("homophone generate error: %s", e)
        raise HTTPException(400, "生成失败，请重试")

    exercise = HomophoneExercise(
        user_id=current_user.id,
        questions=json.dumps(questions, ensure_ascii=False),
        status="pending",
    )
    db.add(exercise)
    await db.commit()
    await db.refresh(exercise)

    # Strip answers before sending to frontend
    for q in questions:
        for w in q.get("words", []):
            w.pop("answer", None)

    return {"id": str(exercise.id), "questions": questions}


@router.post("/{exercise_id}/submit")
async def submit_answers(
    exercise_id: UUID,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit student answers, LLM grades, save results."""
    r = await db.execute(
        select(HomophoneExercise).where(
            HomophoneExercise.id == exercise_id,
            HomophoneExercise.user_id == current_user.id,
        )
    )
    exercise = r.scalar_one_or_none()
    if not exercise:
        raise HTTPException(404, "练习不存在")
    if exercise.status == "completed":
        raise HTTPException(400, "该练习已提交过")

    answers = body.get("answers", [])
    if not answers:
        raise HTTPException(400, "请填写答案后再提交")

    # Save student answers
    exercise.answers = json.dumps(answers, ensure_ascii=False)

    # Parse questions for grading context
    questions = json.loads(exercise.questions) if exercise.questions else []

    # LLM grading
    try:
        grade_prompt = HOMOPHONE_GRADE_PROMPT.format(
            questions_json=json.dumps(questions, ensure_ascii=False, indent=2),
            answers_json=json.dumps(answers, ensure_ascii=False, indent=2),
        )
        raw = await llm_router.chat([{"role": "user", "content": grade_prompt}], max_tokens=2048)
        logger.info("homophone grade raw (%d chars): %s", len(raw or ""), (raw or "")[:800])
        raw = (raw or "").strip()
        if raw.startswith("```"):
            raw = raw.split("\n", 1)[-1]
            if raw.endswith("```"):
                raw = raw[:-3]
            raw = raw.strip()
        grading_data = json.loads(raw) if raw else {}
    except json.JSONDecodeError as e:
        logger.warning("homophone grade JSON error: %s\nRaw:\n%s", e, (raw if 'raw' in dir() else '')[:1000])
        raise HTTPException(400, "批改失败，请重试")
    except Exception as e:
        logger.warning("homophone grade error: %s", e)
        raise HTTPException(400, "批改失败，请重试")

    grading = grading_data.get("grading", [])
    total_correct = grading_data.get("total_correct", 0)
    total_items = grading_data.get("total_items", 0)
    summary = grading_data.get("overall", "")

    # Compute score from grading if not provided
    if not total_correct and not total_items:
        correct = 0
        total = 0
        for g in grading:
            for item in g.get("results", []):
                total += 1
                if item.get("correct"):
                    correct += 1
        score = f"{correct}/{total}" if total > 0 else ""
    else:
        score = f"{total_correct}/{total_items}"

    now = datetime.now(BEIJING_TZ)
    exercise.grading = json.dumps(grading, ensure_ascii=False)
    exercise.score = score
    exercise.status = "completed"
    exercise.completed_at = now
    await db.commit()

    return {
        "id": str(exercise.id),
        "score": score,
        "grading": grading,
        "summary": summary,
    }


@router.get("/history")
async def list_history(
    page: int = Query(1),
    limit: int = Query(20),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List user's homophone exercise history."""
    q = (
        select(HomophoneExercise)
        .where(HomophoneExercise.user_id == current_user.id)
        .order_by(HomophoneExercise.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    r = await db.execute(q)
    rows = r.scalars().all()
    total_q = await db.execute(
        select(func.count(HomophoneExercise.id)).where(
            HomophoneExercise.user_id == current_user.id
        )
    )
    total = total_q.scalar() or 0
    return {
        "items": [
            {
                "id": str(row.id),
                "score": row.score,
                "status": row.status,
                "questions": json.loads(row.questions) if row.questions else [],
                "created_at": row.created_at.isoformat() if row.created_at else "",
                "completed_at": row.completed_at.isoformat() if row.completed_at else None,
            }
            for row in rows
        ],
        "total": total,
    }


@router.get("/{exercise_id}")
async def get_exercise(
    exercise_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a single exercise with full detail."""
    r = await db.execute(
        select(HomophoneExercise).where(
            HomophoneExercise.id == exercise_id,
            HomophoneExercise.user_id == current_user.id,
        )
    )
    exercise = r.scalar_one_or_none()
    if not exercise:
        raise HTTPException(404, "练习不存在")

    return {
        "id": str(exercise.id),
        "questions": json.loads(exercise.questions) if exercise.questions else [],
        "answers": json.loads(exercise.answers) if exercise.answers else [],
        "grading": json.loads(exercise.grading) if exercise.grading else [],
        "score": exercise.score,
        "status": exercise.status,
        "created_at": exercise.created_at.isoformat() if exercise.created_at else "",
        "completed_at": exercise.completed_at.isoformat() if exercise.completed_at else None,
    }
