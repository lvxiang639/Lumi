"""Tests for core services: emotion, memory, proactive, email."""

import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime, timezone, timedelta
from uuid import uuid4


class TestEmotionService:
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    async def test_analyze_returns_calm_on_empty(self):
        from app.services.emotion_service import analyze
        with patch('app.services.emotion_service.llm_router.chat', new_callable=AsyncMock) as mock:
            mock.return_value = '{"emotion": "calm", "intensity": 0.0, "reason": ""}'
            result = await analyze("hello")
            assert result["emotion"] == "calm"

    @pytest.mark.asyncio
    async def test_analyze_detects_joy(self):
        from app.services.emotion_service import analyze
        with patch('app.services.emotion_service.llm_router.chat', new_callable=AsyncMock) as mock:
            mock.return_value = '{"emotion": "joy", "intensity": 0.9, "reason": "happy"}'
            result = await analyze("I'm so happy today!")
            assert result["emotion"] == "joy"
            assert result["intensity"] == 0.9

    @pytest.mark.asyncio
    async def test_analyze_handles_llm_error(self):
        from app.services.emotion_service import analyze
        with patch('app.services.emotion_service.llm_router.chat', new_callable=AsyncMock) as mock:
            mock.side_effect = Exception("API error")
            result = await analyze("hello")
            assert result["emotion"] == "calm"
            assert result["intensity"] == 0.0

    @pytest.mark.asyncio
    async def test_analyze_handles_invalid_json(self):
        from app.services.emotion_service import analyze
        with patch('app.services.emotion_service.llm_router.chat', new_callable=AsyncMock) as mock:
            mock.return_value = 'not json at all'
            result = await analyze("hello")
            assert result["emotion"] == "calm"

    def test_decay_rates_exist_for_all_emotions(self):
        from app.services.emotion_service import DECAY_RATES, VALID_EMOTIONS
        for emo in VALID_EMOTIONS:
            assert emo in DECAY_RATES, f"Missing decay rate for {emo}"

    def test_tone_map_has_all_emotions(self):
        from app.services.emotion_service import TONE_MAP, VALID_EMOTIONS
        for emo in VALID_EMOTIONS:
            assert emo in TONE_MAP, f"Missing tone for {emo}"


class TestMemoryService:
    @pytest.mark.asyncio
    async def test_extract_memories_empty_dialogue(self):
        from app.services.memory_service import extract_memories
        # Should not crash on empty dialogue
        uid = uuid4(); cid = uuid4()
        with patch('app.services.memory_service.llm_router.chat', new_callable=AsyncMock):
            await extract_memories(uid, cid, "")
            await extract_memories(uid, cid, "   ")

    @pytest.mark.asyncio
    async def test_schedule_extraction(self):
        from app.services.memory_service import schedule_extraction
        # Should not raise, creates asyncio task
        schedule_extraction(uuid4(), uuid4(), "test dialogue")


class TestLocationService:
    @pytest.mark.asyncio
    @pytest.mark.asyncio
    async def test_get_city_fallback(self):
        from app.services.location_service import get_city
        with patch('app.services.location_service._geo_lookup', new_callable=AsyncMock) as mock_geo, \
             patch('app.services.location_service._from_user_memory', new_callable=AsyncMock) as mock_mem:
            mock_geo.return_value = None
            mock_mem.return_value = None
            city = await get_city()
            assert city == "Beijing"


class TestConnectionManager:
    def test_register_and_online(self):
        from app.services.connection_manager import register, online_users, unregister

        async def dummy_send(msg): pass
        register("user1", dummy_send)
        assert "user1" in online_users()
        unregister("user1", dummy_send)
        assert "user1" not in online_users()

    def test_send_to_offline_user(self):
        from app.services.connection_manager import send_to_user
        import asyncio
        result = asyncio.run(send_to_user("nonexistent", {"type": "test"}))
        assert result is False


class TestRateLimiter:
    def test_allows_requests_within_limit(self):
        from app.api.auth import _check_rate_limit
        # Reset state for this IP
        from app.api.auth import _rate_limits
        _rate_limits.clear()
        for _ in range(10):
            assert _check_rate_limit("192.168.1.1", max_req=10)

    def test_blocks_over_limit(self):
        from app.api.auth import _check_rate_limit
        from app.api.auth import _rate_limits
        _rate_limits.clear()
        for _ in range(10):
            _check_rate_limit("192.168.1.2", max_req=10)
        assert not _check_rate_limit("192.168.1.2", max_req=10)

    def test_window_reset(self):
        from app.api.auth import _check_rate_limit, _rate_limits
        _rate_limits.clear()
        _check_rate_limit("192.168.1.3", max_req=10)
        # Simulate expired window
        _rate_limits["192.168.1.3"] = (10, 0)  # very old timestamp
        assert _check_rate_limit("192.168.1.3", max_req=10)
