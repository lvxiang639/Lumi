"""Study tutor API — thin controller. Business logic in domain/study/service.py."""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User
from app.models.study_record import StudyRecord, StudyChild
from app.api.deps import get_current_user
from app.services.llm_service import llm_router
from app.services.ocr_service import ocr_service
from app.domain.study.service import StudyService

router = APIRouter(prefix="/api/study", tags=["study"])


# ── Children CRUD ──

@router.get("/children")
async def list_children(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all children for current user."""
    r = await db.execute(
        select(StudyChild)
        .where(StudyChild.user_id == current_user.id)
        .order_by(StudyChild.created_at)
    )
    children = r.scalars().all()
    return {
        "items": [
            {
                "id": str(c.id),
                "name": c.name,
                "grade": c.grade,
                "created_at": c.created_at.isoformat() if c.created_at else "",
            }
            for c in children
        ]
    }


@router.post("/children")
async def create_child(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a new child."""
    name = (body.get("name") or "").strip()
    if not name:
        raise HTTPException(400, "名字不能为空")

    # Check duplicate name for same user
    r = await db.execute(
        select(StudyChild).where(
            StudyChild.user_id == current_user.id,
            StudyChild.name == name,
        )
    )
    if r.scalar_one_or_none():
        raise HTTPException(400, f"孩子 '{name}' 已存在")

    child = StudyChild(
        user_id=current_user.id,
        name=name,
        grade=body.get("grade", ""),
    )
    db.add(child)
    await db.commit()
    await db.refresh(child)
    return {
        "id": str(child.id),
        "name": child.name,
        "grade": child.grade,
    }


@router.delete("/children/{child_id}")
async def delete_child(
    child_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a child (sets child_id to NULL on associated records)."""
    r = await db.execute(
        select(StudyChild).where(
            StudyChild.id == child_id,
            StudyChild.user_id == current_user.id,
        )
    )
    child = r.scalar_one_or_none()
    if not child:
        raise HTTPException(404, "Not found")
    await db.delete(child)
    await db.commit()
    return {"status": "deleted"}


# ── Solve ──

@router.post("/solve")
async def solve_question(
    question: str = Form(""),
    subject: str = Form(""),
    child_id: str = Form(""),
    child_name: str = Form(""),  # fallback for backward compat
    image: UploadFile = File(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Solve a question — OCR if image, AI tutor, auto-save record."""
    image_bytes = await image.read() if image else None

    # Resolve child: prefer child_id, fallback to child_name → auto-create
    child_uuid: UUID | None = None
    resolved_name = ""

    if child_id:
        try:
            child_uuid = UUID(child_id)
            r = await db.execute(
                select(StudyChild).where(
                    StudyChild.id == child_uuid,
                    StudyChild.user_id == current_user.id,
                )
            )
            c = r.scalar_one_or_none()
            if c:
                resolved_name = c.name
        except ValueError:
            pass

    if not resolved_name and child_name:
        resolved_name = child_name.strip()
        # Auto-create child if not exists
        if resolved_name:
            r = await db.execute(
                select(StudyChild).where(
                    StudyChild.user_id == current_user.id,
                    StudyChild.name == resolved_name,
                )
            )
            c = r.scalar_one_or_none()
            if c:
                child_uuid = c.id
            else:
                c = StudyChild(user_id=current_user.id, name=resolved_name)
                db.add(c)
                await db.flush()
                child_uuid = c.id

    try:
        return await StudyService.solve(
            text=question, user_id=current_user.id, subject=subject,
            child_name=resolved_name, child_id=child_uuid, db=db,
            llm_router=llm_router, ocr_service=ocr_service,
            image_bytes=image_bytes,
        )
    except ValueError as e:
        raise HTTPException(400, str(e))


# ── Records ──

@router.get("/records")
async def list_records(
    subject: str = Query(""),
    child_id: str = Query(""),
    status: str = Query(""),  # 未掌握/已掌握
    page: int = Query(1), limit: int = Query(20),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    q = select(StudyRecord).where(StudyRecord.user_id == current_user.id)
    if subject:
        q = q.where(StudyRecord.subject == subject)
    if child_id:
        try:
            q = q.where(StudyRecord.child_id == UUID(child_id))
        except ValueError:
            pass
    if status:
        q = q.where(StudyRecord.status == status)
    q = q.order_by(StudyRecord.created_at.desc()).offset((page - 1) * limit).limit(limit)
    r = await db.execute(q)
    rows = r.scalars().all()
    return {
        "items": [
            {
                "id": str(rc.id),
                "child_id": str(rc.child_id) if rc.child_id else None,
                "child_name": rc.child_name,
                "subject": rc.subject,
                "tags": rc.tags,
                "question": rc.question[:200],
                "answer": rc.answer,
                "status": rc.status,
                "created_at": rc.created_at.isoformat() if rc.created_at else "",
            }
            for rc in rows
        ]
    }


@router.put("/records/{record_id}")
async def update_record(
    record_id: UUID,
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(StudyRecord).where(
            StudyRecord.id == record_id,
            StudyRecord.user_id == current_user.id,
        )
    )
    rec = r.scalar_one_or_none()
    if not rec:
        raise HTTPException(404, "Not found")
    if "status" in body:
        rec.status = body["status"]
    if "child_id" in body:
        try:
            rec.child_id = UUID(body["child_id"])
        except (ValueError, TypeError):
            pass
    await db.commit()
    return {"status": "updated"}


@router.delete("/records/{record_id}")
async def delete_record(
    record_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    r = await db.execute(
        select(StudyRecord).where(
            StudyRecord.id == record_id,
            StudyRecord.user_id == current_user.id,
        )
    )
    rec = r.scalar_one_or_none()
    if not rec:
        raise HTTPException(404, "Not found")
    await db.delete(rec)
    await db.commit()
    return {"status": "deleted"}


# ── Analysis ──

@router.get("/analysis")
async def weak_point_analysis(
    child_id: str = Query(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get analysis grouped by child. Optionally filter to one child."""
    child_uuid: UUID | None = None
    if child_id:
        try:
            child_uuid = UUID(child_id)
        except ValueError:
            pass
    return await StudyService.analyze_weak_points(current_user.id, db, child_uuid=child_uuid, llm_router=llm_router)


@router.get("/analysis/{child_id}")
async def child_analysis_detail(
    child_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Detailed analysis for a single child with weekly trend."""
    return await StudyService.analyze_child_detail(current_user.id, child_id, db, llm_router)


# ── Practice ──

@router.post("/practice")
async def generate_practice(
    child_id: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generate practice questions for weak points. Optional child filter."""
    child_uuid: UUID | None = None
    if child_id:
        try:
            child_uuid = UUID(child_id)
        except ValueError:
            pass
    return await StudyService.generate_practice(current_user.id, db, llm_router, child_uuid=child_uuid)
