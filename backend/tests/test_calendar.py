import pytest
from datetime import datetime, timezone


@pytest.mark.asyncio
async def test_create_and_list_events(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138101"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # Create an event
    now = datetime.now(timezone.utc).isoformat()
    resp = await client.post(
        "/api/calendar",
        json={"title": "测试事件", "time": now, "repeat_rule": "none"},
        headers=headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["title"] == "测试事件"
    event_id = data["id"]

    # List events
    resp = await client.get("/api/calendar", headers=headers)
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) >= 1
    assert any(e["id"] == event_id for e in items)


@pytest.mark.asyncio
async def test_update_event(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138102"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    create_resp = await client.post(
        "/api/calendar",
        json={"title": "旧标题", "time": now},
        headers=headers,
    )
    event_id = create_resp.json()["id"]

    resp = await client.put(
        f"/api/calendar/{event_id}",
        json={"title": "新标题"},
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "新标题"


@pytest.mark.asyncio
async def test_delete_event(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138103"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    create_resp = await client.post(
        "/api/calendar",
        json={"title": "待删除", "time": now},
        headers=headers,
    )
    event_id = create_resp.json()["id"]

    resp = await client.delete(f"/api/calendar/{event_id}", headers=headers)
    assert resp.status_code == 200

    # Verify it's gone
    resp = await client.get(f"/api/calendar/{event_id}", headers=headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_event_not_found(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138104"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get(
        "/api/calendar/00000000-0000-0000-0000-000000000000",
        headers=headers,
    )
    assert resp.status_code == 404
