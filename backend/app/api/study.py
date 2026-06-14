"""Study tutor API — solve, record, analyze, practice."""

import json, logging, asyncio, io
from uuid import UUID
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models import User
from app.models.study_record import StudyRecord, PracticePush
from app.api.deps import get_current_user
from app.services.llm_service import llm_router
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/study", tags=["study"])

# Pre-warm PaddleOCR at module load (prevents first-request hang)
_OCR_READY = False

def _warm_ocr():
    global _OCR_READY
    try:
        from paddleocr import PaddleOCR
        import numpy as np
        ocr = PaddleOCR(lang='ch', use_textline_orientation=True)
        # Run a tiny warm-up inference
        dummy = np.zeros((50, 200, 3), dtype=np.uint8)
        ocr.predict(dummy)
        _ocr_sync._ocr = ocr
        _OCR_READY = True
        logger.info("PaddleOCR warmed up and ready")
    except Exception as e:
        logger.warning(f"PaddleOCR warm-up failed: {e}")

# Start warm-up in background thread
import threading
threading.Thread(target=_warm_ocr, daemon=True).start()

SOLVE_PROMPT = """你是一位耐心的辅导老师。学生的题目如下，请先分步讲解思路，最后给出答案。

题目: {question}
科目: {subject}

请按以下格式回复（JSON）:
{{"subject": "数学", "tags": "标签1,标签2", "steps": ["第1步: ...", "第2步: ..."], "key_point": "关键方法一句话", "answer": "最终答案"}}

注意: answer 字段必须填最终答案，不能为空。"""


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
    text = question

    # OCR from image — PaddleOCR first, Qwen fallback
    if image and not text:
        content = await image.read()
        try:
            loop = asyncio.get_running_loop()
            text = await loop.run_in_executor(None, _ocr_sync, content)
        except Exception:
            text = ""
        # Fallback to Qwen multimodal OCR
        if not text.strip():
            try:
                text = await _qwen_ocr(content)
            except Exception:
                pass

    if not text.strip():
        raise HTTPException(400, "请提供题目内容或确认图片中有文字")

    # Detect subject if not provided
    if not subject:
        det = await llm_router.chat([{"role": "user", "content": f"判断题目属于哪个学科，只返回: 语文 或 数学 或 英语\n题目: {text[:200]}"}])
        subject = (det or "数学").strip()

    # AI tutor
    prompt = SOLVE_PROMPT.format(question=text, subject=subject)
    try:
        raw = await llm_router.chat([{"role": "user", "content": prompt}])
        result = json.loads(raw.strip()) if raw else {}
    except Exception:
        result = {"subject": subject, "tags": "", "steps": [text], "key_point": "", "answer": ""}

    # Save record
    record = StudyRecord(
        user_id=current_user.id, child_name=child_name,
        subject=result.get("subject", subject),
        tags=result.get("tags", ""),
        question=text,
        answer=json.dumps(result, ensure_ascii=False),
        image_url="",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    return {
        "id": str(record.id), "subject": record.subject, "tags": record.tags,
        "steps": result.get("steps", []), "key_point": result.get("key_point", ""),
        "answer": result.get("answer", ""),
    }


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
    beijing_tz = timezone(timedelta(hours=8))
    week_start = datetime.now(beijing_tz) - timedelta(days=7)
    r = await db.execute(select(StudyRecord).where(StudyRecord.user_id == current_user.id, StudyRecord.created_at >= week_start))
    records = r.scalars().all()

    # Count by tag
    tag_counts = {}
    subjects = {}
    for rec in records:
        subjects[rec.subject] = subjects.get(rec.subject, 0) + 1
        for tag in rec.tags.split(","):
            tag = tag.strip()
            if tag: tag_counts[tag] = tag_counts.get(tag, 0) + 1

    sorted_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)
    weak_points = [{"tag": t, "count": c} for t, c in sorted_tags if c >= 2]

    # Generate suggestion
    suggestion = ""
    if weak_points:
        top = weak_points[0]
        suggestion = f"本周'{top['tag']}'错了{top['count']}次，建议重点练习"

    return {"subjects": subjects, "weak_points": weak_points, "total": len(records), "suggestion": suggestion}


@router.post("/practice")
async def generate_practice(current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Generate practice questions for weak points."""
    r = await db.execute(select(StudyRecord).where(StudyRecord.user_id == current_user.id, StudyRecord.status == "未掌握").order_by(StudyRecord.created_at.desc()).limit(10))
    records = r.scalars().all()
    if not records: return {"questions": [], "message": "没有需要练习的薄弱点"}

    tags = set()
    for rec in records:
        for t in rec.tags.split(","):
            if t.strip(): tags.add(t.strip())

    tag_list = "、".join(list(tags)[:5])
    prompt = f"根据以下薄弱知识点，生成3道练习题（每题带答案）。格式: 题号. 题目 (知识点: xxx)\n答案: xxx\n\n薄弱点: {tag_list}\n\n练习题:"
    try:
        result = await llm_router.chat([{"role": "user", "content": prompt}])
        # Save as practice pushes
        questions = (result or "").strip().split("\n\n")
        saved = []
        for q in questions[:3]:
            if q.strip():
                pp = PracticePush(user_id=current_user.id, question=q[:500], answer="")
                db.add(pp)
                saved.append(q[:200])
        await db.commit()
        return {"questions": saved}
    except Exception:
        return {"questions": [], "message": "生成失败"}


# ── PaddleOCR helper (free, offline, best Chinese recognition) ──

def _ocr_sync(image_bytes: bytes) -> str:
    """Run PaddleOCR on an image — model pre-warmed at startup."""
    try:
        from PIL import Image
        import numpy as np

        if not hasattr(_ocr_sync, '_ocr'):
            from paddleocr import PaddleOCR
            _ocr_sync._ocr = PaddleOCR(lang='ch', use_textline_orientation=True)

        img = Image.open(io.BytesIO(image_bytes))
        img_np = np.array(img)
        result = _ocr_sync._ocr.predict(img_np)

        lines = []
        for r in result:
            data = r.json if hasattr(r, 'json') else {}
            res = data.get('res', data)
            texts = res.get('rec_texts', [])
            for text in texts:
                if text and text.strip():
                    lines.append(text.strip())
        return '\n'.join(lines) if lines else ''
    except ImportError:
        return ''
    except Exception:
        return ''


async def _qwen_ocr(image_bytes: bytes) -> str:
    """Fallback OCR using Qwen multimodal API."""
    import base64
    from openai import AsyncOpenAI
    from app.config import settings

    b64 = base64.b64encode(image_bytes).decode()
    client = AsyncOpenAI(api_key=settings.qwen_api_key, base_url=settings.qwen_base_url)
    resp = await client.chat.completions.create(
        model=settings.qwen_model_name,
        messages=[{"role": "user", "content": [
            {"type": "text", "text": "请识别图片中的所有文字，只返回文字内容，不要解释。"},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}},
        ]}],
        max_tokens=512,
    )
    return (resp.choices[0].message.content or "").strip()
