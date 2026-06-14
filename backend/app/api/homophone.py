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

HOMOPHONE_GENERATE_PROMPT = """你是一位小学语文老师。请生成5道"同音字组词"练习题。

要求：
1. 每道题选择一个常见汉字作为目标字（1-6年级课本常用字）
2. 难度适合小学生，不要选太生僻的字
3. 每个目标字给出拼音以便学生确认读音

请严格按照以下JSON格式返回，不要包含其他内容：
{
  "questions": [
    {
      "target_char": "同",
      "pinyin": "tóng",
      "hint": "请写出与'同'(tóng)同音的字，并组词",
      "expected_count": 3
    }
  ]
}

注意：
- 题目数量为5道
- expected_count表示期望学生写出几个同音字组词（2-3个）
- 不要重复使用同一个目标字
- 优先选择有多种同音字的常用汉字，如：同、青、工、力、马、中、元、方、几、十"""

HOMOPHONE_GRADE_PROMPT = """你是一位小学语文老师，正在批改同音字组词练习。

请判断学生的每个答案是否正确。判断标准：
1. 学生写的字是否与目标字同音（声母、韵母、声调都要相同，包括轻声和变调）
2. 学生写的词语是否包含该字（该字必须是词语的组成部分）
3. 学生写的字不能与目标字是同一个字（必须是不同的同音字）
4. 学生的多个答案之间不能有重复的同音字

题目列表：
{questions_json}

学生的答案：
{answers_json}

请按以下JSON格式返回批改结果：
{
  "grading": [
    {
      "target_char": "同",
      "results": [
        {"char": "童", "word": "童话", "correct": true, "feedback": "正确！童和同同音。"},
        {"char": "铜", "word": "铜牌", "correct": true, "feedback": "正确！"},
        {"char": "同", "word": "相同", "correct": false, "feedback": "同字和目标字相同，不是同音字。"}
      ],
      "missing": [
        {"char": "桐", "word": "梧桐", "hint": "桐(tóng)，组词：梧桐"}
      ]
    }
  ],
  "summary": "表现不错！5道题共批改X个答案。正确N个，还需努力，加油！",
  "total_correct": 0,
  "total_items": 0
}

注意：
- results中的每项对应学生的一个答案，judge是否正确
- feedback要具体说明对错原因（10字以内）
- missing列出该目标字存在的其他有效同音字（学生没写到的），帮助学习
- summary要温暖鼓励
- total_correct和total_items要准确统计"""


@router.post("/generate")
async def generate_exercise(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate 5 homophone questions via LLM, save to DB."""
    try:
        raw = await llm_router.chat([{"role": "user", "content": HOMOPHONE_GENERATE_PROMPT}])
        data = json.loads(raw.strip()) if raw else {}
        questions = data.get("questions", [])
        if not questions:
            raise ValueError("empty questions")
    except Exception:
        raise HTTPException(400, "生成失败，请重试")

    exercise = HomophoneExercise(
        user_id=current_user.id,
        questions=json.dumps(questions, ensure_ascii=False),
        status="pending",
    )
    db.add(exercise)
    await db.commit()
    await db.refresh(exercise)

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
        raw = await llm_router.chat([{"role": "user", "content": grade_prompt}])
        grading_data = json.loads(raw.strip()) if raw else {}
    except Exception:
        raise HTTPException(400, "批改失败，请重试")

    grading = grading_data.get("grading", [])
    total_correct = grading_data.get("total_correct", 0)
    total_items = grading_data.get("total_items", 0)
    summary = grading_data.get("summary", "")

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
