"""Study tutor API — thin controller. Business logic in domain/study/service.py."""

import json
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


# ── Grade Answer ──

@router.post("/grade")
async def grade_answer(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Grade a student's answer using LLM, save record."""
    question = body.get("question", "")
    user_answer = body.get("answer", "")
    correct_answer = body.get("correct_answer", "")
    subject = body.get("subject", "数学")
    child_id = body.get("child_id", "")
    child_name = body.get("child_name", "")

    prompt = f"""批改以下学生的答题，返回JSON:

题目: {question}
学生答案: {user_answer}
正确答案: {correct_answer}

判断学生答案是否正确。如果是数学题，允许答案形式不同但结果相同。如果是语文题，只要意思对就算对。

返回JSON: {{"is_correct": true/false, "feedback": "一句话点评（10字以内）", "explanation": "详细解析（30字以内）"}}"""

    raw = await llm_router.chat([{"role": "user", "content": prompt}])
    try:
        clean = raw.strip()
        if clean.startswith("```"): clean = clean.split("\n", 1)[-1].split("```")[0] if "```" in clean[3:] else clean[3:]
        result = json.loads(clean)
    except Exception:
        result = {"is_correct": user_answer.strip() == correct_answer.strip(), "feedback": "已批改", "explanation": ""}

    # Save record
    child_uuid = None
    if child_id:
        try: child_uuid = UUID(child_id)
        except ValueError: pass

    record = StudyRecord(
        user_id=current_user.id,
        child_id=child_uuid,
        child_name=child_name,
        subject=subject,
        tags="练习",
        question=question,
        answer=json.dumps({"student_answer": user_answer, "correct_answer": correct_answer, **result}, ensure_ascii=False),
        status="已掌握" if result.get("is_correct") else "未掌握",
    )
    db.add(record)
    await db.commit()

    return {**result, "record_id": str(record.id)}


# ── Practice Records ──

@router.get("/practice-records")
async def list_practice_records(
    child_id: str = Query(""),
    status: str = Query(""),
    page: int = Query(1), limit: int = Query(20),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List practice records with grading results."""
    q = select(StudyRecord).where(
        StudyRecord.user_id == current_user.id,
        StudyRecord.tags == "练习",
    )
    if child_id:
        try: q = q.where(StudyRecord.child_id == UUID(child_id))
        except ValueError: pass
    if status: q = q.where(StudyRecord.status == status)
    q = q.order_by(StudyRecord.created_at.desc()).offset((page-1)*limit).limit(limit)
    r = await db.execute(q)
    rows = r.scalars().all()

    def parse_answer(raw: str):
        try: return json.loads(raw)
        except: return {}

    return {"items": [
        {
            "id": str(rc.id), "child_name": rc.child_name, "subject": rc.subject,
            "question": rc.question, "status": rc.status,
            **parse_answer(rc.answer),
            "created_at": rc.created_at.isoformat() if rc.created_at else "",
        } for rc in rows
    ]}


# ── Generate Questions ──

@router.post("/generate-questions")
async def generate_questions(
    body: dict,
    current_user: User = Depends(get_current_user),
):
    """Generate practice questions via LLM. Accepts subject, topic, grade, count."""
    subject = body.get("subject", "数学")
    topic = body.get("topic", "")
    grade = body.get("grade", 3)
    count = body.get("count", 5)

    topic_hint = f"知识点: {topic}" if topic else ""
    grade_hint = f"{grade}年级" if grade else "小学"

    prompt = f"""请生成{count}道{grade_hint}{subject}练习题。{topic_hint}
每道题格式:
题号. 题目内容
答案: 正确答案

要求:
- 题目难度适合{grade_hint}学生
- 如果指定了知识点，聚焦该知识点
- 题目表述清晰，像课本上的题
- 答案准确

练习题:"""

    raw = await llm_router.chat([{"role": "user", "content": prompt}], max_tokens=1024, temperature=0.8)

    # Retry with simpler prompt if first attempt returned empty
    if not raw or not raw.strip():
        prompt2 = f"生成{count}道{grade_hint}{subject}题。{topic_hint}\n每题格式: 题号. 题目\n答案: 答案"
        raw = await llm_router.chat([{"role": "user", "content": prompt2}], max_tokens=1024, temperature=0.7)

    questions = [q.strip() for q in (raw or "").strip().split("\n\n") if q.strip() and "答案" in q]

    return {"questions": questions[:count], "subject": subject, "topic": topic, "grade": grade}


# ── Knowledge Points ──

@router.get("/knowledge-points")
async def list_knowledge_points(
    subject: str = Query(""),
    grade: int = Query(0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List knowledge points tree. Optional subject/grade filter."""
    from app.models.knowledge_point import KnowledgePoint
    q = select(KnowledgePoint).order_by(KnowledgePoint.sort_order, KnowledgePoint.grade)
    if subject:
        q = q.where(KnowledgePoint.subject == subject)
    if grade > 0:
        q = q.where(KnowledgePoint.grade.in_([0, grade]))
    r = await db.execute(q)
    rows = r.scalars().all()
    return {
        "items": [
            {
                "id": str(rw.id), "parent_id": str(rw.parent_id) if rw.parent_id else None,
                "name": rw.name, "grade": rw.grade, "subject": rw.subject,
                "level": rw.level, "keywords": rw.keywords,
            }
            for rw in rows
        ]
    }
