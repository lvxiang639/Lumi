import pytest


@pytest.mark.asyncio
async def test_init_character(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138101"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.post("/api/characters/init", json={"name": "小白"}, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "小白"


@pytest.mark.asyncio
async def test_get_character_config_not_init(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138102"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get("/api/characters/config", headers=headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_owned_outfits(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138103"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    await client.post("/api/characters/init", json={"name": "小黑"}, headers=headers)
    resp = await client.get("/api/characters/outfits", headers=headers)
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_equip_cycle(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138104"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    await client.post("/api/characters/init", json={"name": "测试"}, headers=headers)
    # Get owned outfits
    outfits_resp = await client.get("/api/characters/outfits", headers=headers)
    outfits = outfits_resp.json()
    assert len(outfits) >= 1
    outfit_id = outfits[0]["id"]
    # Try equip
    resp = await client.put("/api/characters/equip", json={"item_type": "outfit", "item_id": outfit_id}, headers=headers)
    assert resp.status_code == 200
