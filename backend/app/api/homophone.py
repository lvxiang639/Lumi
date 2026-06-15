"""Homophone exercise API — thin controller. Business logic in domain/homophone/service.py."""

import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User
from app.models.homophone_exercise import HomophoneExercise
from app.api.deps import get_current_user
from app.services.llm_service import llm_router
from app.domain.homophone.service import HomophoneService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/study/homophone", tags=["homophone"])


@router.post("/generate")
async def generate_exercise(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate 5 homophone questions via LLM — delegated to HomophoneService."""
    try:
        return await HomophoneService.generate_exercise(current_user.id, db, llm_router)
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.post("/{exercise_id}/submit")
async def submit_answers(
    exercise_id: UUID,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Submit student answers, LLM grades — delegated to HomophoneService."""
    answers = body.get("answers", [])
    if not answers:
        raise HTTPException(400, "请填写答案后再提交")
    try:
        return await HomophoneService.submit_answers(exercise_id, current_user.id, answers, db, llm_router)
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.get("/history")
async def get_history(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List user's homophone exercise history."""
    r = await db.execute(
        select(HomophoneExercise)
        .where(HomophoneExercise.user_id == current_user.id)
        .order_by(HomophoneExercise.created_at.desc())
        .limit(20)
    )
    rows = r.scalars().all()
    return {
        "items": [
            {
                "id": str(row.id),
                "score": row.score,
                "status": row.status,
                "created_at": row.created_at.isoformat() if row.created_at else "",
            }
            for row in rows
        ]
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
        "questions": exercise.questions,
        "answers": exercise.answers,
        "grading": exercise.grading,
        "score": exercise.score,
        "status": exercise.status,
        "created_at": exercise.created_at.isoformat() if exercise.created_at else "",
    }
