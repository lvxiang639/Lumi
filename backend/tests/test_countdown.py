import pytest
import pytest_asyncio


@pytest_asyncio.fixture
async def auth_headers(client):
    """Login and return Authorization headers."""
    resp = await client.post("/api/auth/login", json={"phone": "13900000099"})
    token = resp.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.mark.asyncio
async def test_create_and_list_countdown(client, auth_headers):
    resp = await client.post("/api/countdown", json={
        "title": "新年",
        "target_date": "2027-01-01T00:00:00+08:00",
        "note": "倒计时",
    }, headers=auth_headers)
    assert resp.status_code == 201
    assert resp.json()["title"] == "新年"

    resp = await client.get("/api/countdown", headers=auth_headers)
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert any(i["title"] == "新年" for i in items)


@pytest.mark.asyncio
async def test_delete_countdown(client, auth_headers):
    resp = await client.post("/api/countdown", json={
        "title": "删除测试",
        "target_date": "2026-12-31T00:00:00+08:00",
    }, headers=auth_headers)
    cid = resp.json()["id"]

    resp = await client.delete(f"/api/countdown/{cid}", headers=auth_headers)
    assert resp.status_code == 200

    resp = await client.get("/api/countdown", headers=auth_headers)
    assert not any(i["id"] == cid for i in resp.json()["items"])


@pytest.mark.asyncio
async def test_weekly_insights(client, auth_headers):
    resp = await client.get("/api/expenses/insights/weekly", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "total_expense" in data
    assert "current_emotion" in data
    # Empty user should still get a summary
    assert isinstance(data["summary"], str)
