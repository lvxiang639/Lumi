"""Domain service for study tutor — solve, analyze, practice."""

import json
import logging
from datetime import datetime, timezone, timedelta
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

logger = logging.getLogger(__name__)

SOLVE_PROMPT = """你是一位耐心的辅导老师。学生的题目如下，请先分步讲解思路，最后给出答案。

题目: {question}
科目: {subject}

请按以下格式回复（JSON）:
{{"subject": "数学", "tags": "标签1,标签2", "steps": ["第1步: ...", "第2步: ..."], "key_point": "关键方法一句话", "answer": "最终答案"}}

注意: answer 字段必须填最终答案，不能为空。"""

BEIJING_TZ = timezone(timedelta(hours=8))


class StudyService:
    """Domain service for study tutor operations."""

    @staticmethod
    async def solve(
        text: str,
        user_id: UUID,
        subject: str = "",
        child_name: str = "",
        *,
        db: AsyncSession,
        llm_router,
        ocr_service,
        image_bytes: bytes | None = None,
    ) -> dict:
        """Solve a question: OCR if image, detect subject, AI tutor, save record.

        Returns the result dict with: id, subject, tags, steps, key_point, answer.
        """
        from app.models.study_record import StudyRecord

        # OCR from image if provided
        if image_bytes:
            text = await ocr_service.recognize_text(image_bytes)
            if not text.strip():
                logger.info("PaddleOCR returned empty, trying Qwen-VL fallback...")
                text = await ocr_service.understand_with_qwen(image_bytes)

        if not text.strip():
            raise ValueError("图片中未识别到文字，请手动输入题目内容")

        # Detect subject if not provided
        if not subject:
            det = await llm_router.chat([
                {"role": "user", "content": f"判断题目属于哪个学科，只返回: 语文 或 数学 或 英语\n题目: {text[:200]}"}
            ])
            subject = (det or "数学").strip()

        # AI tutor
        prompt = SOLVE_PROMPT.format(question=text, subject=subject)
        try:
            raw = await llm_router.chat([{"role": "user", "content": prompt}])
            raw = (raw or "").strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[-1]
                if raw.endswith("```"):
                    raw = raw[:-3]
                raw = raw.strip()
            result = json.loads(raw) if raw else {}
        except Exception:
            result = {"subject": subject, "tags": "", "steps": [text], "key_point": "", "answer": ""}

        # Save record
        record = StudyRecord(
            user_id=user_id, child_name=child_name,
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

    @staticmethod
    async def analyze_weak_points(user_id: UUID, db: AsyncSession) -> dict:
        """Analyze weekly weak points from study records."""
        from app.models.study_record import StudyRecord

        week_start = datetime.now(BEIJING_TZ) - timedelta(days=7)
        r = await db.execute(
            select(StudyRecord).where(
                StudyRecord.user_id == user_id,
                StudyRecord.created_at >= week_start,
            )
        )
        records = r.scalars().all()

        tag_counts: dict[str, int] = {}
        subjects: dict[str, int] = {}
        for rec in records:
            subjects[rec.subject] = subjects.get(rec.subject, 0) + 1
            for tag in rec.tags.split(","):
                tag = tag.strip()
                if tag:
                    tag_counts[tag] = tag_counts.get(tag, 0) + 1

        sorted_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)
        weak_points = [{"tag": t, "count": c} for t, c in sorted_tags if c >= 2]

        suggestion = ""
        if weak_points:
            top = weak_points[0]
            suggestion = f"本周'{top['tag']}'错了{top['count']}次，建议重点练习"

        return {
            "subjects": subjects, "weak_points": weak_points,
            "total": len(records), "suggestion": suggestion,
        }

    @staticmethod
    async def generate_practice(user_id: UUID, db: AsyncSession, llm_router) -> dict:
        """Generate practice questions for weak points."""
        from app.models.study_record import StudyRecord, PracticePush

        r = await db.execute(
            select(StudyRecord).where(
                StudyRecord.user_id == user_id,
                StudyRecord.status == "未掌握",
            ).order_by(StudyRecord.created_at.desc()).limit(10)
        )
        records = r.scalars().all()
        if not records:
            return {"questions": [], "message": "没有需要练习的薄弱点"}

        tags = set()
        for rec in records:
            for t in rec.tags.split(","):
                if t.strip():
                    tags.add(t.strip())

        tag_list = "、".join(list(tags)[:5])
        prompt = (
            f"根据以下薄弱知识点，生成3道练习题（每题带答案）。"
            f"格式: 题号. 题目 (知识点: xxx)\n答案: xxx\n\n"
            f"薄弱点: {tag_list}\n\n练习题:"
        )
        try:
            result = await llm_router.chat([{"role": "user", "content": prompt}])
            questions_raw = (result or "").strip().split("\n\n")
            saved = []
            for q in questions_raw[:3]:
                if q.strip():
                    pp = PracticePush(user_id=user_id, question=q[:500], answer="")
                    db.add(pp)
                    saved.append(q[:200])
            await db.commit()
            return {"questions": saved}
        except Exception:
            return {"questions": [], "message": "生成失败"}
