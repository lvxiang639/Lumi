import pytest

@pytest.mark.asyncio
async def test_login_new_user(client):
    resp = await client.post("/api/auth/login", json={"phone": "13800138001"})
    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert data["is_new_user"] is True

@pytest.mark.asyncio
async def test_login_existing_user(client):
    await client.post("/api/auth/login", json={"phone": "13800138002"})
    resp = await client.post("/api/auth/login", json={"phone": "13800138002"})
    assert resp.status_code == 200
    assert resp.json()["is_new_user"] is False

@pytest.mark.asyncio
async def test_get_profile(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138003"})
    token = login_resp.json()["access_token"]
    resp = await client.get("/api/auth/profile", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["phone"] == "13800138003"

@pytest.mark.asyncio
async def test_update_profile(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138004"})
    token = login_resp.json()["access_token"]
    resp = await client.put("/api/auth/profile", json={"nickname": "测试用户"}, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["nickname"] == "测试用户"
