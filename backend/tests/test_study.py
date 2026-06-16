"""Tests for study tutor feature — children CRUD, solve, analysis."""

import json
import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4


# ── Helpers ──────────────────────────────────────────────────────────

_login_counter = 0


async def _login(client):
    global _login_counter
    _login_counter += 1
    phone = f"139{_login_counter:08d}"
    resp = await client.post("/api/auth/login", json={"phone": phone})
    data = resp.json()
    assert "access_token" in data, f"Login failed: {data}"
    return {"Authorization": f"Bearer {data['access_token']}"}


# ── Domain Service Unit Tests (pure logic, mocked LLM/OCR) ────────────

class TestStudyServiceSolve:
    @pytest.mark.asyncio
    async def test_solve_detects_subject(self):
        from app.domain.study.service import StudyService
        mock_llm = AsyncMock()
        mock_llm.chat.side_effect = [
            "数学",
            '{"subject":"数学","tags":"加法,进位","steps":["第1步: 对齐数位","第2步: 逐位相加"],"key_point":"满十进一","answer":"37"}',
        ]
        mock_db = AsyncMock()
        result = await StudyService.solve(
            text="25+12=", user_id=uuid4(), subject="",
            child_name="小明", db=mock_db, llm_router=mock_llm,
            ocr_service=AsyncMock(),
        )
        assert result["subject"] == "数学"
        assert "加法" in result["tags"]
        assert result["answer"] == "37"
        assert result["child_name"] == "小明"

    @pytest.mark.asyncio
    async def test_solve_with_child_id(self):
        from app.domain.study.service import StudyService
        child_id = uuid4()
        mock_llm = AsyncMock()
        mock_llm.chat.side_effect = [
            "语文",
            '{"subject":"语文","tags":"古诗","steps":["背诵静夜思"],"key_point":"理解意境","answer":"床前明月光"}',
        ]
        mock_db = AsyncMock()
        result = await StudyService.solve(
            text="静夜思", user_id=uuid4(), subject="语文",
            child_name="小红", child_id=child_id, db=mock_db,
            llm_router=mock_llm, ocr_service=AsyncMock(),
        )
        assert result["child_id"] == str(child_id)
        assert result["subject"] == "语文"

    @pytest.mark.asyncio
    async def test_solve_handles_malformed_llm_response(self):
        from app.domain.study.service import StudyService
        mock_llm = AsyncMock()
        mock_llm.chat.side_effect = ["英语", "NOT VALID JSON"]
        mock_db = AsyncMock()
        result = await StudyService.solve(
            text="Hello", user_id=uuid4(), db=mock_db,
            llm_router=mock_llm, ocr_service=AsyncMock(),
        )
        assert result["subject"] == "英语"
        assert result["answer"] == ""


class TestStudyServiceAnalysis:
    @pytest.mark.asyncio
    async def test_analyze_weak_points_empty(self):
        from app.domain.study.service import StudyService
        mock_db = AsyncMock()
        mock_result = AsyncMock()
        mock_result.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[])))
        mock_db.execute = AsyncMock(return_value=mock_result)

        analysis = await StudyService.analyze_weak_points(uuid4(), mock_db, llm_router=None)
        assert analysis["overall"]["total"] == 0
        assert analysis["children"] == []

    @pytest.mark.asyncio
    async def test_analyze_groups_by_child(self):
        from app.domain.study.service import StudyService
        from datetime import datetime, timezone, timedelta
        BEIJING_TZ = timezone(timedelta(hours=8))
        from app.models.study_record import StudyChild, StudyRecord

        child_a = StudyChild(id=uuid4(), user_id=uuid4(), name="小明", grade="三年级")
        child_b = StudyChild(id=uuid4(), user_id=uuid4(), name="小红", grade="一年级")
        now = datetime.now(BEIJING_TZ)
        records = [
            StudyRecord(user_id=child_a.user_id, child_id=child_a.id, child_name="小明",
                        subject="数学", tags="加法", question="25+12",
                        answer='{"answer":"37"}', status="已掌握", created_at=now),
            StudyRecord(user_id=child_a.user_id, child_id=child_a.id, child_name="小明",
                        subject="数学", tags="加法", question="38+14",
                        answer='{"answer":"52"}', status="未掌握", created_at=now),
            StudyRecord(user_id=child_a.user_id, child_id=child_b.id, child_name="小红",
                        subject="语文", tags="拼音", question="写出声母表",
                        answer='{"answer":"bpmf"}', status="已掌握", created_at=now),
        ]

        mock_db = AsyncMock()
        mock_child = AsyncMock()
        mock_child.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[child_a, child_b])))
        mock_rec = AsyncMock()
        mock_rec.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=records)))
        call_count = [0]

        async def mock_execute(q):
            call_count[0] += 1
            return mock_child if call_count[0] == 1 else mock_rec

        mock_db.execute = mock_execute
        analysis = await StudyService.analyze_weak_points(child_a.user_id, mock_db, llm_router=None)
        assert analysis["overall"]["total"] == 3
        child_a_data = next(c for c in analysis["children"] if c["child_name"] == "小明")
        assert child_a_data["total"] == 2
        assert child_a_data["mastered"] == 1
        assert child_a_data["mastery_rate"] == 0.5

    @pytest.mark.asyncio
    async def test_weak_point_threshold(self):
        from app.domain.study.service import StudyService
        from datetime import datetime, timezone, timedelta
        BEIJING_TZ = timezone(timedelta(hours=8))
        from app.models.study_record import StudyChild, StudyRecord

        child = StudyChild(id=uuid4(), user_id=uuid4(), name="测试", grade="")
        now = datetime.now(BEIJING_TZ)
        records = [
            StudyRecord(user_id=child.user_id, child_id=child.id, child_name="测试",
                        subject="数学", tags="分数", question="1/2+1/3",
                        answer='{"answer":"5/6"}', status="未掌握", created_at=now),
            StudyRecord(user_id=child.user_id, child_id=child.id, child_name="测试",
                        subject="数学", tags="分数", question="3/4-1/2",
                        answer='{}', status="未掌握", created_at=now),
            StudyRecord(user_id=child.user_id, child_id=child.id, child_name="测试",
                        subject="数学", tags="单位", question="1米=?厘米",
                        answer='{}', status="未掌握", created_at=now),
        ]

        mock_db = AsyncMock()
        mock_child = AsyncMock()
        mock_child.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=[child])))
        mock_rec = AsyncMock()
        mock_rec.scalars = MagicMock(return_value=MagicMock(all=MagicMock(return_value=records)))
        call_count = [0]

        async def mock_execute(q):
            call_count[0] += 1
            return mock_child if call_count[0] == 1 else mock_rec

        mock_db.execute = mock_execute
        analysis = await StudyService.analyze_weak_points(child.user_id, mock_db, llm_router=None)
        child_data = analysis["children"][0]
        weak_tags = {w["tag"] for w in child_data["weak_points"]}
        assert "分数" in weak_tags  # appears 2x ≥ threshold
        assert "单位" not in weak_tags  # only 1x


# ── API Integration Tests ──────────────────────────────────────────────

@pytest.fixture
def mock_llm():
    """Mock LLM returning predictable responses."""
    mock = AsyncMock()
    # Return fresh responses each call (unlimited via lambda)
    mock.chat = AsyncMock()
    mock.chat.side_effect = lambda *a, **kw: "数学" if "判断题目" in str(a) else '{"subject":"数学","tags":"加法","steps":["第1步"],"key_point":"算术","answer":"42"}'
    return mock


class TestStudyChildrenAPI:
    @pytest.mark.asyncio
    async def test_list_children_returns_array(self, client):
        h = await _login(client)
        resp = await client.get("/api/study/children", headers=h)
        assert resp.status_code == 200
        assert isinstance(resp.json()["items"], list)

    @pytest.mark.asyncio
    async def test_create_child(self, client):
        h = await _login(client)
        unique = uuid4().hex[:6]
        resp = await client.post("/api/study/children", headers=h, json={"name": f"测试{unique}", "grade": "三年级"})
        assert resp.status_code == 200
        assert resp.json()["name"] == f"测试{unique}"
        assert resp.json()["grade"] == "三年级"

    @pytest.mark.asyncio
    async def test_create_duplicate(self, client):
        h = await _login(client)
        unique = uuid4().hex[:6]
        await client.post("/api/study/children", headers=h, json={"name": f"重复{unique}"})
        resp = await client.post("/api/study/children", headers=h, json={"name": f"重复{unique}"})
        assert resp.status_code == 400

    @pytest.mark.asyncio
    async def test_delete_child(self, client):
        h = await _login(client)
        unique = uuid4().hex[:6]
        resp = await client.post("/api/study/children", headers=h, json={"name": f"删除{unique}"})
        child_id = resp.json()["id"]
        resp = await client.delete(f"/api/study/children/{child_id}", headers=h)
        assert resp.status_code == 200


class TestStudySolveAPI:
    @pytest.mark.asyncio
    async def test_solve_creates_child(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            resp = await client.post("/api/study/solve", headers=h, data={"question": "1+1=?", "child_name": f"新生{unique}"})
        assert resp.status_code == 200
        assert f"新生{unique}" in resp.json()["child_name"]

    @pytest.mark.asyncio
    async def test_solve_with_child_id(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        resp = await client.post("/api/study/children", headers=h, json={"name": f"小明{unique}"})
        child_id = resp.json()["id"]

        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            resp = await client.post("/api/study/solve", headers=h, data={"question": "3+5=?", "child_id": child_id})
        assert resp.status_code == 200
        assert resp.json()["child_id"] == child_id

    @pytest.mark.asyncio
    async def test_solve_empty_text_fails(self, client, mock_llm):
        h = await _login(client)
        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            resp = await client.post("/api/study/solve", headers=h, data={"question": ""})
        assert resp.status_code == 400


class TestStudyRecordsAPI:
    @pytest.mark.asyncio
    async def test_filter_by_child(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        resp = await client.post("/api/study/children", headers=h, json={"name": f"筛选{unique}"})
        child_id = resp.json()["id"]

        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            await client.post("/api/study/solve", headers=h, data={"question": "test", "child_id": child_id})

        resp = await client.get(f"/api/study/records?child_id={child_id}", headers=h)
        items = resp.json()["items"]
        assert any(it.get("child_id") == child_id for it in items)

    @pytest.mark.asyncio
    async def test_filter_by_status(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            await client.post("/api/study/solve", headers=h, data={"question": f"状态{unique}"})

        resp = await client.get("/api/study/records?status=未掌握", headers=h)
        items = resp.json()["items"]
        assert all(it["status"] == "未掌握" for it in items if f"状态{unique}" in (it.get("question") or ""))

    @pytest.mark.asyncio
    async def test_mark_mastered(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            await client.post("/api/study/solve", headers=h, data={"question": f"掌握{unique}"})

        resp = await client.get("/api/study/records", headers=h)
        target = next((it for it in resp.json()["items"] if f"掌握{unique}" in (it.get("question") or "")), None)
        assert target is not None

        resp = await client.put(
            f"/api/study/records/{target['id']}",
            headers={**h, "Content-Type": "application/json"},
            json={"status": "已掌握"},
        )
        assert resp.status_code == 200


class TestStudyEdgeCases:
    @pytest.mark.asyncio
    async def test_delete_nonexistent_child(self, client):
        h = await _login(client)
        resp = await client.delete(f"/api/study/children/{uuid4()}", headers=h)
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_update_nonexistent_record(self, client):
        h = await _login(client)
        resp = await client.put(
            f"/api/study/records/{uuid4()}",
            headers={**h, "Content-Type": "application/json"},
            json={"status": "已掌握"},
        )
        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_create_child_empty_name(self, client):
        h = await _login(client)
        resp = await client.post("/api/study/children", headers=h, json={"name": "  "})
        assert resp.status_code == 400


class TestStudyAnalysisAPI:
    @pytest.mark.asyncio
    async def test_analysis_includes_child_records(self, client, mock_llm):
        h = await _login(client)
        unique = uuid4().hex[:6]
        resp = await client.post("/api/study/children", headers=h, json={"name": f"分析{unique}"})
        child_id = resp.json()["id"]

        with patch("app.api.study.llm_router", mock_llm), patch("app.domain.study.service._get_llm", return_value=mock_llm):
            await client.post("/api/study/solve", headers=h, data={"question": "Q1", "child_id": child_id})
            await client.post("/api/study/solve", headers=h, data={"question": "Q2", "child_id": child_id})

        resp = await client.get("/api/study/analysis", headers=h)
        data = resp.json()
        child_names = [c["child_name"] for c in data["children"]]
        assert f"分析{unique}" in child_names
