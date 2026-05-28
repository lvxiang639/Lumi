import pytest


@pytest.mark.asyncio
async def test_list_conversations_empty(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138101"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get("/api/conversations", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.asyncio
async def test_delete_conversation_not_found(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138102"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.delete(
        "/api/conversations/00000000-0000-0000-0000-000000000000",
        headers=headers,
    )
    assert resp.status_code == 404  # not found — conversation doesn't exist


@pytest.mark.asyncio
async def test_update_title_not_found(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138103"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.put(
        "/api/conversations/00000000-0000-0000-0000-000000000000/title",
        json={"title": "新标题"},
        headers=headers,
    )
    assert resp.status_code == 404
