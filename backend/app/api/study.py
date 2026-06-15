"""Study tutor API — thin controller. Business logic in domain/study/service.py."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User
from app.models.study_record import StudyRecord
from app.api.deps import get_current_user
from app.services.llm_service import llm_router
from app.services.ocr_service import ocr_service
from app.domain.study.service import StudyService

router = APIRouter(prefix="/api/study", tags=["study"])


@router.post("/solve")
async def solve_question(
    question: str = Form(""),
    subject: str = Form(""),
    child_name: str = Form(""),
    image: UploadFile = File(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Solve a question — OCR if image, AI tutor, auto-save record."""
    image_bytes = await image.read() if image else None
    try:
        return await StudyService.solve(
            text=question, user_id=current_user.id, subject=subject,
            child_name=child_name, db=db, llm_router=llm_router,
            ocr_service=ocr_service, image_bytes=image_bytes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))


@router.get("/records")
async def list_records(
    subject: str = Query(""),
    child_name: str = Query(""),
    page: int = Query(1), limit: int = Query(20),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = select(StudyRecord).where(StudyRecord.user_id == current_user.id)
    if subject: q = q.where(StudyRecord.subject == subject)
    if child_name: q = q.where(StudyRecord.child_name == child_name)
    q = q.order_by(StudyRecord.created_at.desc()).offset((page-1)*limit).limit(limit)
    r = await db.execute(q)
    rows = r.scalars().all()
    return {"items": [{"id": str(rc.id), "child_name": rc.child_name, "subject": rc.subject, "tags": rc.tags, "question": rc.question[:200], "answer": rc.answer, "status": rc.status, "created_at": rc.created_at.isoformat() if rc.created_at else ""} for rc in rows]}


@router.put("/records/{record_id}")
async def update_record(record_id: UUID, body: dict, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(StudyRecord).where(StudyRecord.id == record_id, StudyRecord.user_id == current_user.id))
    rec = r.scalar_one_or_none()
    if not rec: raise HTTPException(404, "Not found")
    if "status" in body: rec.status = body["status"]
    await db.commit()
    return {"status": "updated"}


@router.get("/analysis")
async def weak_point_analysis(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    return await StudyService.analyze_weak_points(current_user.id, db)


@router.post("/practice")
async def generate_practice(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Generate practice questions for weak points."""
    return await StudyService.generate_practice(current_user.id, db, llm_router)


