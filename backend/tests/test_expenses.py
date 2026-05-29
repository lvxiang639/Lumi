import pytest
from datetime import datetime, timezone


@pytest.mark.asyncio
async def test_create_and_list_expenses(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138101"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    resp = await client.post(
        "/api/expenses",
        json={"amount": 15.5, "category": "餐饮", "recorded_at": now},
        headers=headers,
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["amount"] == 15.5
    assert data["category"] == "餐饮"

    # List expenses
    resp = await client.get("/api/expenses", headers=headers)
    assert resp.status_code == 200
    items = resp.json()["items"]
    assert len(items) >= 1
    assert any(e["id"] == data["id"] for e in items)


@pytest.mark.asyncio
async def test_expense_stats(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138102"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    # Create expenses in different categories
    await client.post(
        "/api/expenses",
        json={"amount": 10.0, "category": "餐饮", "recorded_at": now},
        headers=headers,
    )
    await client.post(
        "/api/expenses",
        json={"amount": 20.0, "category": "交通", "recorded_at": now},
        headers=headers,
    )
    await client.post(
        "/api/expenses",
        json={"amount": 5.0, "category": "餐饮", "recorded_at": now},
        headers=headers,
    )

    resp = await client.get("/api/expenses/stats", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["total_expense"] == 35.0
    assert data["by_category"]["餐饮"] == 15.0
    assert data["by_category"]["交通"] == 20.0


@pytest.mark.asyncio
async def test_update_expense(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138103"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    create_resp = await client.post(
        "/api/expenses",
        json={"amount": 100.0, "category": "其他", "recorded_at": now},
        headers=headers,
    )
    expense_id = create_resp.json()["id"]

    resp = await client.put(
        f"/api/expenses/{expense_id}",
        json={"amount": 200.0, "category": "餐饮"},
        headers=headers,
    )
    assert resp.status_code == 200
    assert resp.json()["amount"] == 200.0
    assert resp.json()["category"] == "餐饮"


@pytest.mark.asyncio
async def test_delete_expense(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138104"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    now = datetime.now(timezone.utc).isoformat()
    create_resp = await client.post(
        "/api/expenses",
        json={"amount": 50.0, "recorded_at": now},
        headers=headers,
    )
    expense_id = create_resp.json()["id"]

    resp = await client.delete(f"/api/expenses/{expense_id}", headers=headers)
    assert resp.status_code == 200

    resp = await client.get(f"/api/expenses/{expense_id}", headers=headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_expense_not_found(client):
    login_resp = await client.post("/api/auth/login", json={"phone": "13800138105"})
    token = login_resp.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await client.get(
        "/api/expenses/00000000-0000-0000-0000-000000000000",
        headers=headers,
    )
    assert resp.status_code == 404
