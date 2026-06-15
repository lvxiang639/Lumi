"""Domain service for homophone exercise — generate, grade."""

import json
import logging
from uuid import UUID
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

GENERATE_PROMPT = """你是一位小学语文老师。请生成一组"同音字填空"练习题。

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
    }
  ]
}

注意：
- 生成5组同音字（5个不同拼音）
- 每组2-3个同音字词语
- blank字段用"__"代替被挖掉的同音字
- answer是正确答案（被挖掉的那个字）
- hint给学生一点提示
- 优先中小学课本常见字"""

GRADE_PROMPT = """你是一位小学语文老师，正在批改同音字填空题。

请判断学生填的每个字是否正确。判断标准：
1. 学生填的字与题目拼音是否同音（声母、韵母、声调都要相同）
2. 学生填的字和后面的字组成的词语是否合理、常见

题目（含正确答案）：{questions_json}
学生的答案：{answers_json}

请按以下JSON格式返回批改结果：
{{"grading": [{{"pinyin": "...", "results": [{{"blank": "...", "filled": "...", "correct": true/false, "feedback": "..."}}], "summary": "..."}}], "overall": "...", "total_correct": N, "total_items": N}}

注意：feedback要具体说明为什么对/错（15字以内），overall给总体评语温暖鼓励。"""


class HomophoneService:
    """Domain service for homophone exercise generation and grading."""

    @staticmethod
    async def generate_exercise(user_id: UUID, db: AsyncSession, llm_router) -> dict:
        """Generate 5 homophone questions via LLM, save to DB, return questions."""
        from app.models.homophone_exercise import HomophoneExercise

        try:
            raw = await llm_router.chat([{"role": "user", "content": GENERATE_PROMPT}], max_tokens=1024)
            raw = (raw or "").strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[-1]
                if raw.endswith("```"):
                    raw = raw[:-3]
                raw = raw.strip()
            data = json.loads(raw) if raw else {}
            questions = data.get("questions", [])
            if not questions:
                raise ValueError("empty questions")
        except json.JSONDecodeError:
            raise ValueError("生成失败，请重试")
        except Exception:
            raise ValueError("生成失败，请重试")

        exercise = HomophoneExercise(user_id=user_id, questions=json.dumps(questions, ensure_ascii=False))
        db.add(exercise)
        await db.commit()
        await db.refresh(exercise)

        # Strip answers before returning
        safe_questions = json.loads(json.dumps(questions))
        for g in safe_questions:
            for w in g.get("words", []):
                w.pop("answer", None)
        return {"id": str(exercise.id), "questions": safe_questions}

    @staticmethod
    async def submit_answers(exercise_id: UUID, user_id: UUID, answers: list, db: AsyncSession, llm_router) -> dict:
        """Submit student answers, LLM grade, save results."""
        from app.models.homophone_exercise import HomophoneExercise
        from sqlalchemy import select

        r = await db.execute(select(HomophoneExercise).where(HomophoneExercise.id == exercise_id, HomophoneExercise.user_id == user_id))
        exercise = r.scalar_one_or_none()
        if not exercise:
            raise ValueError("练习不存在")

        questions = json.loads(exercise.questions)
        questions_json = json.dumps(questions, ensure_ascii=False, indent=2)
        answers_json = json.dumps(answers, ensure_ascii=False, indent=2)
        prompt = GRADE_PROMPT.format(questions_json=questions_json, answers_json=answers_json)

        try:
            raw = await llm_router.chat([{"role": "user", "content": prompt}], max_tokens=1024)
            raw = (raw or "").strip()
            if raw.startswith("```"):
                raw = raw.split("\n", 1)[-1]
                if raw.endswith("```"):
                    raw = raw[:-3]
                raw = raw.strip()
            data = json.loads(raw) if raw else {}
        except Exception:
            raise ValueError("批改失败，请重试")

        grading = data.get("grading", [])
        overall = data.get("overall", "")
        total_items = data.get("total_items", 0)
        total_correct = data.get("total_correct", 0)
        score = f"{total_correct}/{total_items}"

        exercise.answers = json.dumps(answers, ensure_ascii=False)
        exercise.grading = json.dumps(grading, ensure_ascii=False)
        exercise.score = score
        exercise.status = "completed"
        await db.commit()

        return {"grading": grading, "score": score, "summary": overall}
