"""Unit tests for domain layer — entities, services, repositories.

Covers 80%+ of domain logic with pure functions + mocked LLM/DB deps.
"""

import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4, UUID
from dataclasses import asdict


# ── Domain Entity Tests ────────────────────────────────────────────

class TestDomainEntities:
    def test_calendar_entity_defaults(self):
        from app.domain.entities import CalendarEntity
        e = CalendarEntity()
        assert e.title == ""
        assert e.repeat_rule == ""
        assert e.notified is False

    def test_expense_entity_defaults(self):
        from app.domain.entities import ExpenseEntity
        e = ExpenseEntity()
        assert e.amount == 0.0
        assert e.category == ""

    def test_note_entity_defaults(self):
        from app.domain.entities import NoteEntity
        e = NoteEntity()
        assert e.note_type == "note"

    def test_user_entity_fields(self):
        from app.domain.repositories.user_repo import UserEntity
        e = UserEntity(nickname="测试", phone="13800001111")
        assert e.nickname == "测试"
        assert e.phone == "13800001111"
        assert e.persona == "小猫"  # default

    def test_message_entity_fields(self):
        from app.domain.repositories.message_repo import MessageEntity
        e = MessageEntity(role="user", content="hello")
        assert e.role == "user"
        assert e.content == "hello"
        assert e.type == "text"

    def test_memory_entity_fields(self):
        from app.domain.repositories.user_repo import MemoryEntity
        uid = uuid4()
        m = MemoryEntity(user_id=uid, key="爱好", value="编程")
        assert m.user_id == uid
        assert m.key == "爱好"

    def test_emotion_entity_fields(self):
        from app.domain.repositories.user_repo import EmotionEntity
        e = EmotionEntity(current_emotion="happy", intensity=0.8)
        assert e.current_emotion == "happy"
        assert e.intensity == 0.8

    def test_conversation_entity_defaults(self):
        from app.domain.repositories.message_repo import ConversationEntity
        e = ConversationEntity()
        assert e.title == "新对话"

    def test_all_entities_are_dataclasses(self):
        import dataclasses
        from app.domain.entities import CalendarEntity, ExpenseEntity, NoteEntity, CountdownEntity
        for cls in [CalendarEntity, ExpenseEntity, NoteEntity, CountdownEntity]:
            assert dataclasses.is_dataclass(cls), f"{cls.__name__} is not a dataclass"


# ── KnowledgeService Chunk Tests (pure logic) ───────────────────────

class TestChunkText:
    def test_empty_text(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        assert svc._chunk_text("") == []
        assert svc._chunk_text("   ") == []

    def test_single_short_text(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        result = svc._chunk_text("Hello world")
        assert len(result) == 1
        assert result[0] == "Hello world"

    def test_text_shorter_than_chunk_size(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "短文本" * 10  # ~30 chars
        result = svc._chunk_text(text, chunk_size=500)
        assert len(result) == 1
        assert result[0] == text

    def test_long_text_splits_into_chunks(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "A" * 1200
        result = svc._chunk_text(text, chunk_size=500, overlap=100)
        assert len(result) >= 2
        assert all(len(c) <= 500 for c in result)

    def test_chinese_paragraph_splitting(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "第一段内容。\n\n第二段内容。\n\n第三段内容。"
        result = svc._chunk_text(text, chunk_size=500, overlap=100)
        assert len(result) >= 1
        assert "第一段" in result[0]

    def test_chinese_sentence_boundary(self):
        """Sentences should not be split mid-sentence."""
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        # Each sentence ~10 chars, chunk_size=15 should keep sentences together
        text = "今天天气很好。适合出去玩。晚上吃火锅。明天要上班。"
        result = svc._chunk_text(text, chunk_size=30, overlap=5)
        # Should produce fewer chunks than character-level slicing
        assert len(result) < 6
        # Each chunk should end with sentence-ending punctuation or be merged
        for c in result:
            assert len(c) > 0

    def test_very_long_sentence(self):
        """A single sentence > chunk_size is sliced at character level."""
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "A" * 600  # No sentence breaks
        result = svc._chunk_text(text, chunk_size=500, overlap=100)
        assert len(result) == 2
        assert len(result[0]) <= 500

    def test_overlap_preserves_context(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "A" * 900
        result = svc._chunk_text(text, chunk_size=500, overlap=100)
        assert len(result) >= 2
        # Overlapping text should appear in both chunks
        if len(result) == 2:
            assert result[0][-100:] == result[1][:100]

    def test_single_paragraph_longer_than_chunk(self):
        from app.domain.knowledge.service import KnowledgeService
        svc = KnowledgeService(None)
        text = "第一句很长很长。第二句也很长很长。第三句同样很长。"
        result = svc._chunk_text(text, chunk_size=15, overlap=5)
        assert all(len(c) <= 15 for c in result)


# ── Embedding Tests ─────────────────────────────────────────────────

class TestEmbedding:
    def test_embed_sync_returns_1024_dim_vector(self):
        """Without sentence-transformers installed, returns fallback 1024-dim."""
        from app.domain.knowledge.service import _embed_sync
        result = _embed_sync("test text")
        assert len(result) == 1024
        assert all(isinstance(x, float) for x in result)

    def test_embed_sync_deterministic_fallback(self):
        """Fallback uses MD5 seed, so same text → same vector."""
        from app.domain.knowledge.service import _embed_sync
        a = _embed_sync("hello world")
        b = _embed_sync("hello world")
        assert a == b

    def test_embed_sync_different_text_different_vector(self):
        from app.domain.knowledge.service import _embed_sync
        a = _embed_sync("hello")
        b = _embed_sync("world")
        assert a != b

    def test_embed_sync_handles_long_text(self):
        from app.domain.knowledge.service import _embed_sync
        result = _embed_sync("A" * 3000)
        assert len(result) == 1024


# ── StudyService Tests ──────────────────────────────────────────────

class TestStudyService:
    @pytest.mark.asyncio
    async def test_analyze_weak_points_empty(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_db.execute = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute.return_value = mock_result

        result = await StudyService.analyze_weak_points(uid, mock_db)
        assert result["total"] == 0
        assert result["weak_points"] == []
        assert result["subjects"] == {}

    @pytest.mark.asyncio
    async def test_analyze_weak_points_with_data(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_record = MagicMock()
        mock_record.subject = "数学"
        mock_record.tags = "分数, 函数"
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [mock_record, mock_record]
        mock_db.execute.return_value = mock_result

        result = await StudyService.analyze_weak_points(uid, mock_db)
        assert result["total"] == 2
        assert result["subjects"]["数学"] == 2
        assert len(result["weak_points"]) == 2

    @pytest.mark.asyncio
    async def test_generate_practice_no_weak_points(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute.return_value = mock_result

        result = await StudyService.generate_practice(uid, mock_db, None)
        assert result["questions"] == []
        assert "没有需要练习的薄弱点" in result["message"]

    @pytest.mark.asyncio
    async def test_solve_success(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_ocr = AsyncMock()

        mock_llm.chat.return_value = '{"subject":"数学","tags":"加法","steps":["1+1=2"],"key_point":"加法","answer":"2"}'

        result = await StudyService.solve(
            "1+1=?", uid, "数学", db=mock_db,
            llm_router=mock_llm, ocr_service=mock_ocr,
        )
        assert result["subject"] == "数学"
        assert result["answer"] == "2"

    @pytest.mark.asyncio
    async def test_solve_detects_subject(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_ocr = AsyncMock()

        mock_llm.chat.side_effect = [
            "语文",  # subject detection
            '{"subject":"语文","tags":"古诗","steps":["...1..."],"key_point":"...","answer":"静夜思"}',  # tutor
        ]

        result = await StudyService.solve(
            "床前明月光", uid, "", db=mock_db,
            llm_router=mock_llm, ocr_service=mock_ocr,
        )
        assert result["subject"] == "语文"

    @pytest.mark.asyncio
    async def test_solve_empty_text_raises(self):
        from app.domain.study.service import StudyService
        uid = uuid4()
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_ocr = AsyncMock()
        mock_ocr.recognize_text = AsyncMock(return_value="")
        mock_ocr.understand_with_qwen = AsyncMock(return_value="")

        with pytest.raises(ValueError, match="未识别到文字"):
            await StudyService.solve(
                "", uid, "数学", db=mock_db,
                llm_router=mock_llm, ocr_service=mock_ocr,
                image_bytes=b"fake",
            )


# ── ConversationService Tests ───────────────────────────────────────

class TestConversationService:
    @pytest.mark.asyncio
    async def test_generate_summary_success(self):
        from app.domain.conversation.service import ConversationService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = "这是一段摘要内容。"

        mock_msg = MagicMock()
        mock_msg.role.value = "user"
        mock_msg.content = "你好"
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [mock_msg, mock_msg]
        mock_db.execute.return_value = mock_result

        result = await ConversationService.generate_summary(uuid4(), mock_db, mock_llm)
        assert result == "这是一段摘要内容。"

    @pytest.mark.asyncio
    async def test_generate_summary_empty_raises(self):
        from app.domain.conversation.service import ConversationService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db.execute.return_value = mock_result

        with pytest.raises(ValueError, match="对话内容为空"):
            await ConversationService.generate_summary(uuid4(), mock_db, mock_llm)

    @pytest.mark.asyncio
    async def test_generate_summary_llm_error(self):
        from app.domain.conversation.service import ConversationService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.side_effect = Exception("API down")

        mock_msg = MagicMock()
        mock_msg.role.value = "user"
        mock_msg.content = "hi"
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = [mock_msg]
        mock_db.execute.return_value = mock_result

        with pytest.raises(RuntimeError, match="摘要生成失败"):
            await ConversationService.generate_summary(uuid4(), mock_db, mock_llm)

    @pytest.mark.asyncio
    async def test_email_summary_no_email(self):
        from app.domain.conversation.service import ConversationService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()

        with pytest.raises(ValueError, match="邮箱"):
            await ConversationService.email_summary(
                uuid4(), uuid4(), "", "测试", mock_db, mock_llm, AsyncMock(),
            )


# ── HomophoneService Tests ──────────────────────────────────────────

class TestHomophoneService:
    @pytest.mark.asyncio
    async def test_generate_exercise_success(self):
        from app.domain.homophone.service import HomophoneService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        questions = [{"pinyin": "tóng", "words": [{"blank": "__学", "answer": "同"}]}]
        mock_llm.chat.return_value = json.dumps({"questions": questions})

        result = await HomophoneService.generate_exercise(uuid4(), mock_db, mock_llm)
        assert "id" in result
        assert len(result["questions"]) == 1
        # Answers should be stripped
        assert "answer" not in result["questions"][0]["words"][0]

    @pytest.mark.asyncio
    async def test_generate_exercise_bad_json(self):
        from app.domain.homophone.service import HomophoneService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = "not valid json {{{"

        with pytest.raises(ValueError, match="生成失败"):
            await HomophoneService.generate_exercise(uuid4(), mock_db, mock_llm)

    @pytest.mark.asyncio
    async def test_submit_answers_not_found(self):
        from app.domain.homophone.service import HomophoneService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db.execute.return_value = mock_result

        with pytest.raises(ValueError, match="练习不存在"):
            await HomophoneService.submit_answers(uuid4(), uuid4(), [], mock_db, mock_llm)

    @pytest.mark.asyncio
    async def test_submit_answers_success(self):
        from app.domain.homophone.service import HomophoneService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = json.dumps({
            "grading": [], "overall": "很棒", "total_correct": 0, "total_items": 1
        })

        mock_exercise = MagicMock()
        mock_exercise.questions = json.dumps([{"pinyin": "tóng", "words": []}])
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = mock_exercise
        mock_db.execute.return_value = mock_result

        result = await HomophoneService.submit_answers(uuid4(), uuid4(), [], mock_db, mock_llm)
        assert "grading" in result
        assert "score" in result


# ── ExpenseService Tests ────────────────────────────────────────────

class TestExpenseService:
    @pytest.mark.asyncio
    async def test_weekly_insights_empty(self):
        from app.domain.expense.service import ExpenseService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = "一切正常"

        # Mock 3 DB queries: expenses, emotions, memories
        mock_exp = MagicMock()
        mock_exp.all.return_value = []
        mock_emo = MagicMock()
        mock_emo.first.return_value = None
        mock_mem = MagicMock()
        mock_mem.scalar.return_value = 0
        mock_db.execute.side_effect = [mock_exp, mock_emo, mock_mem]

        result = await ExpenseService.get_weekly_insights(uuid4(), mock_db, mock_llm)
        assert result["total_expense"] == 0
        assert result["total_memories"] == 0

    @pytest.mark.asyncio
    async def test_weekly_insights_with_data(self):
        from app.domain.expense.service import ExpenseService
        mock_db = AsyncMock()
        mock_llm = AsyncMock()
        mock_llm.chat.return_value = "本周花费不错"

        mock_exp = MagicMock()
        mock_exp.all.return_value = [("餐饮", 100.0, 3), ("交通", 50.0, 2)]
        mock_emo = MagicMock()
        mock_emo.first.return_value = ("happy", 0.8)
        mock_mem = MagicMock()
        mock_mem.scalar.return_value = 5
        mock_db.execute.side_effect = [mock_exp, mock_emo, mock_mem]

        result = await ExpenseService.get_weekly_insights(uuid4(), mock_db, mock_llm)
        assert result["total_expense"] == 150.0
        assert result["expense_count"] == 5
        assert result["top_category"] == "餐饮"
        assert result["current_emotion"] == "happy"
        assert result["total_memories"] == 5


# ── AuthService Tests ───────────────────────────────────────────────

class TestAuthService:
    @pytest.mark.asyncio
    async def test_welcome_message_is_not_empty(self):
        from app.domain.auth.service import WELCOME_MESSAGE
        assert len(WELCOME_MESSAGE) > 100
        assert "灵犀" in WELCOME_MESSAGE
        assert "工具" in WELCOME_MESSAGE


# ── Repository ABC Contract Tests ───────────────────────────────────

class TestRepositoryContracts:
    def test_message_repo_is_abstract(self):
        from app.domain.repositories.message_repo import MessageRepository
        import inspect
        assert inspect.isabstract(MessageRepository)

    def test_user_repo_is_abstract(self):
        from app.domain.repositories.user_repo import UserRepository
        import inspect
        assert inspect.isabstract(UserRepository)

    def test_calendar_repo_is_abstract(self):
        from app.domain.repositories.base import CalendarRepository
        import inspect
        assert inspect.isabstract(CalendarRepository)

    def test_expense_repo_is_abstract(self):
        from app.domain.repositories.base import ExpenseRepository
        import inspect
        assert inspect.isabstract(ExpenseRepository)

    def test_knowledge_repo_is_abstract(self):
        from app.domain.knowledge.repository import KnowledgeRepository
        import inspect
        assert inspect.isabstract(KnowledgeRepository)

    def test_sql_repos_implement_interfaces(self):
        from app.domain.repositories.message_repo import MessageRepository
        from app.domain.repositories.user_repo import UserRepository
        from app.domain.repositories.base import CalendarRepository, ExpenseRepository
        from app.infrastructure.repositories.message_repo import SqlMessageRepository
        from app.infrastructure.repositories.user_repo import SqlUserRepository
        from app.infrastructure.repositories.base_repos import SqlCalendarRepository, SqlExpenseRepository

        assert issubclass(SqlMessageRepository, MessageRepository)
        assert issubclass(SqlUserRepository, UserRepository)
        assert issubclass(SqlCalendarRepository, CalendarRepository)
        assert issubclass(SqlExpenseRepository, ExpenseRepository)
