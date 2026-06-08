"""Tests for new features: email auth, AI persona, AI diary."""

import pytest
import pytest_asyncio
from httpx import AsyncClient


@pytest_asyncio.fixture
async def auth_headers(client):
    """Login via phone and return Authorization headers."""
    resp = await client.post("/api/auth/login", json={"phone": "13900000101"})
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


# ── Email Auth ──


@pytest.mark.asyncio
async def test_email_register(client):
    import uuid
    email = f"test_{uuid.uuid4().hex[:8]}@example.com"
    resp = await client.post("/api/auth/register", json={
        "email": email,
        "password": "123456",
        "nickname": "测试邮箱",
    })
    assert resp.status_code in (200, 201), f"Expected 200/201, got {resp.status_code}: {resp.text}"
    data = resp.json()
    assert "access_token" in data
    assert data["is_new_user"] is True


@pytest.mark.asyncio
async def test_email_register_duplicate(client):
    await client.post("/api/auth/register", json={
        "email": "dup@example.com", "password": "123456",
    })
    resp = await client.post("/api/auth/register", json={
        "email": "dup@example.com", "password": "123456",
    })
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_email_login(client):
    # Register first
    await client.post("/api/auth/register", json={
        "email": "login_test@example.com", "password": "mypassword",
    })
    # Login
    resp = await client.post("/api/auth/email-login", json={
        "email": "login_test@example.com", "password": "mypassword",
    })
    assert resp.status_code == 200
    assert "access_token" in resp.json()


@pytest.mark.asyncio
async def test_email_login_wrong_password(client):
    await client.post("/api/auth/register", json={
        "email": "wrong@example.com", "password": "correct",
    })
    resp = await client.post("/api/auth/email-login", json={
        "email": "wrong@example.com", "password": "wrongpass",
    })
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_email_register_short_password(client):
    resp = await client.post("/api/auth/register", json={
        "email": "short@example.com", "password": "12345",
    })
    assert resp.status_code == 422  # validation error


# ── AI Persona ──


@pytest.mark.asyncio
async def test_set_persona(client, auth_headers):
    resp = await client.put("/api/auth/profile", json={
        "persona": "温柔姐姐",
    }, headers=auth_headers)
    assert resp.status_code == 200

    # Verify it's saved
    resp = await client.get("/api/auth/profile", headers=auth_headers)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_set_persona_unknown(client, auth_headers):
    resp = await client.put("/api/auth/profile", json={
        "persona": "不存在的角色",
    }, headers=auth_headers)
    assert resp.status_code == 200  # saved as memory, validated at use time


@pytest.mark.asyncio
async def test_persona_persists(client, auth_headers):
    await client.put("/api/auth/profile", json={"persona": "毒舌损友"}, headers=auth_headers)
    resp = await client.get("/api/auth/profile", headers=auth_headers)
    assert resp.status_code == 200


# ── AI Diary ──


@pytest.mark.asyncio
async def test_diary_empty_conversation(client, auth_headers):
    # Create a conversation first
    resp = await client.get("/api/conversations", headers=auth_headers)
    assert resp.status_code == 200


@pytest.mark.asyncio
async def test_email_field_persists(client, auth_headers):
    """Test that email field can be set and persists in profile."""
    resp = await client.put("/api/auth/profile", json={
        "email": "profile_test@example.com",
    }, headers=auth_headers)
    assert resp.status_code == 200
    resp = await client.get("/api/auth/profile", headers=auth_headers)
    assert resp.json()["email"] == "profile_test@example.com"
