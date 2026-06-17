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

ANALYSIS_SUGGESTION_PROMPT = """根据以下学生的学习情况，给出1-2句针对性建议（不超过50字）：

孩子: {child_name}
本周做题: {total}题，掌握: {mastered}题
薄弱知识点: {weak_tags}

建议:"""

BEIJING_TZ = timezone(timedelta(hours=8))


class StudyService:
    """Domain service for study tutor operations."""

    @staticmethod
    async def solve(
        text: str,
        user_id: UUID,
        subject: str = "",
        child_name: str = "",
        child_id: UUID | None = None,
        *,
        db: AsyncSession,
        llm_router,
        ocr_service,
        image_bytes: bytes | None = None,
    ) -> dict:
        """Solve a question: OCR if image, detect subject, AI tutor, save record."""
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
            user_id=user_id,
            child_id=child_id,
            child_name=child_name,
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
            "id": str(record.id),
            "child_id": str(record.child_id) if record.child_id else None,
            "child_name": record.child_name,
            "subject": record.subject,
            "tags": record.tags,
            "steps": result.get("steps", []),
            "key_point": result.get("key_point", ""),
            "answer": result.get("answer", ""),
        }

    @staticmethod
    async def analyze_weak_points(
        user_id: UUID,
        db: AsyncSession,
        child_uuid: UUID | None = None,
        llm_router=None,
    ) -> dict:
        """Analyze weak points grouped by child. Weekly stats + per-child breakdown."""
        from app.models.study_record import StudyRecord, StudyChild

        week_start = datetime.now(BEIJING_TZ) - timedelta(days=7)
        month_start = datetime.now(BEIJING_TZ) - timedelta(days=30)

        # Get all children for this user
        children_q = select(StudyChild).where(StudyChild.user_id == user_id)
        if child_uuid:
            children_q = children_q.where(StudyChild.id == child_uuid)
        children_r = await db.execute(children_q.order_by(StudyChild.created_at))
        children = children_r.scalars().all()

        # Get records with child filter
        records_q = (
            select(StudyRecord)
            .where(
                StudyRecord.user_id == user_id,
                StudyRecord.created_at >= week_start,
            )
        )
        if child_uuid:
            records_q = records_q.where(StudyRecord.child_id == child_uuid)
        records_r = await db.execute(records_q.order_by(StudyRecord.created_at.desc()))
        all_records = records_r.scalars().all()

        # Also get records without child_id for "未分类"
        # Group records by child
        child_data: dict[str, list] = {}  # child_id_or_none → records
        for rec in all_records:
            key = str(rec.child_id) if rec.child_id else "__none__"
            if key not in child_data:
                child_data[key] = []
            child_data[key].append(rec)

        children_result = []
        for child in children:
            cid = str(child.id)
            records = child_data.pop(cid, [])

            # Stats
            total = len(records)
            mastered = sum(1 for r in records if r.status == "已掌握")
            mastery_rate = round(mastered / total, 2) if total > 0 else 0.0
            by_subject: dict[str, int] = {}
            tag_counts: dict[str, int] = {}
            for rec in records:
                by_subject[rec.subject] = by_subject.get(rec.subject, 0) + 1
                for tag in rec.tags.split(","):
                    tag = tag.strip()
                    if tag:
                        tag_counts[tag] = tag_counts.get(tag, 0) + 1

            sorted_tags = sorted(tag_counts.items(), key=lambda x: x[1], reverse=True)
            weak_points = [
                {"tag": t, "count": c}
                for t, c in sorted_tags
                if c >= 2
            ][:5]

            # Weekly trend (last 4 weeks)
            weekly_trend = []
            for w in range(4):
                ws = week_start - timedelta(weeks=w)
                we = ws + timedelta(days=7)
                week_records = [r for r in records if ws <= r.created_at.replace(tzinfo=BEIJING_TZ) < we]
                week_total = len(week_records)
                week_mastered = sum(1 for r in week_records if r.status == "已掌握")
                weekly_trend.append({
                    "week": f"W{w+1}",
                    "label": ws.strftime("%m/%d"),
                    "total": week_total,
                    "mastered": week_mastered,
                })
            weekly_trend.reverse()  # oldest first

            # AI suggestion
            suggestion = ""
            if weak_points:
                top_tags = "、".join(w["tag"] for w in weak_points[:3])
                try:
                    prompt = ANALYSIS_SUGGESTION_PROMPT.format(
                        child_name=child.name or "学生",
                        total=total,
                        mastered=mastered,
                        weak_tags=top_tags,
                    )
                    suggestion = await llm.chat([{"role": "user", "content": prompt}])
                    suggestion = (suggestion or "").strip()
                except Exception:
                    suggestion = f"建议重点练习：{top_tags}"

            children_result.append({
                "child_id": cid,
                "child_name": child.name,
                "grade": child.grade,
                "total": total,
                "mastered": mastered,
                "mastery_rate": mastery_rate,
                "by_subject": by_subject,
                "weak_points": weak_points,
                "weekly_trend": weekly_trend,
                "ai_suggestion": suggestion,
            })

        # Unclassified records (no child_id)
        uncategorized = child_data.pop("__none__", [])
        if uncategorized:
            total = len(uncategorized)
            mastered = sum(1 for r in uncategorized if r.status == "已掌握")
            mastery_rate = round(mastered / total, 2) if total > 0 else 0.0
            by_subject: dict[str, int] = {}
            for rec in uncategorized:
                by_subject[rec.subject] = by_subject.get(rec.subject, 0) + 1
            children_result.append({
                "child_id": None,
                "child_name": "未分类",
                "grade": "",
                "total": total,
                "mastered": mastered,
                "mastery_rate": mastery_rate,
                "by_subject": by_subject,
                "weak_points": [],
                "weekly_trend": [],
                "ai_suggestion": "为这些题目关联一个孩子，以便获得个性化分析",
            })

        # Overall stats
        overall_total = sum(c["total"] for c in children_result)
        overall_mastered = sum(c["mastered"] for c in children_result)
        overall_rate = round(overall_mastered / overall_total, 2) if overall_total > 0 else 0.0

        return {
            "children": children_result,
            "overall": {
                "total": overall_total,
                "mastered": overall_mastered,
                "mastery_rate": overall_rate,
            },
        }

    @staticmethod
    async def analyze_child_detail(
        user_id: UUID,
        child_id: UUID,
        db: AsyncSession,
        llm_router,
    ) -> dict:
        """Detailed analysis for a single child — includes recent wrong answers."""
        from app.models.study_record import StudyRecord, StudyChild

        # Verify child belongs to user
        r = await db.execute(
            select(StudyChild).where(
                StudyChild.id == child_id,
                StudyChild.user_id == user_id,
            )
        )
        child = r.scalar_one_or_none()
        if not child:
            return {"error": "Not found"}

        # Full analysis
        analysis = await StudyService.analyze_weak_points(user_id, db, child_uuid=child_id, llm_router=llm_router)
        child_data = analysis["children"][0] if analysis["children"] else {}

        # Recent wrong answers
        r = await db.execute(
            select(StudyRecord)
            .where(
                StudyRecord.user_id == user_id,
                StudyRecord.child_id == child_id,
                StudyRecord.status == "未掌握",
            )
            .order_by(StudyRecord.created_at.desc())
            .limit(10)
        )
        wrong_records = r.scalars().all()
        recent_wrong = [
            {
                "id": str(rc.id),
                "question": rc.question[:150],
                "tags": rc.tags,
                "subject": rc.subject,
                "created_at": rc.created_at.isoformat() if rc.created_at else "",
            }
            for rc in wrong_records
        ]

        return {**child_data, "recent_wrong": recent_wrong}

    @staticmethod
    async def generate_practice(
        user_id: UUID,
        db: AsyncSession,
        llm_router,
        child_uuid: UUID | None = None,
    ) -> dict:
        """Generate practice questions for weak points. Optional child filter."""
        from app.models.study_record import StudyRecord, PracticePush

        q = (
            select(StudyRecord)
            .where(
                StudyRecord.user_id == user_id,
                StudyRecord.status == "未掌握",
            )
        )
        if child_uuid:
            q = q.where(StudyRecord.child_id == child_uuid)
        q = q.order_by(StudyRecord.created_at.desc()).limit(10)
        r = await db.execute(q)
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
            for q_text in questions_raw[:3]:
                if q_text.strip():
                    pp = PracticePush(
                        user_id=user_id,
                        question=q_text[:500],
                        answer="",
                    )
                    db.add(pp)
                    saved.append(q_text[:200])
            await db.commit()
            return {"questions": saved}
        except Exception:
            return {"questions": [], "message": "生成失败"}
