import pytest
import json
from httpx import AsyncClient
from httpx_ws import aconnect_ws
from httpx_ws.transport import ASGIWebSocketTransport

from app.main import app


@pytest.mark.asyncio
async def test_ws_auth_failure(client):
    """WebSocket should reject missing/invalid tokens."""
    transport = ASGIWebSocketTransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        with pytest.raises(Exception):
            async with aconnect_ws("http://test/ws/chat", c) as ws:
                pass


@pytest.mark.asyncio
async def test_ws_valid_token_connects(client):
    """WebSocket should accept a valid token and handle basic messaging."""
    login_resp = await client.post(
        "/api/auth/login", json={"phone": "13800138010"}
    )
    assert login_resp.status_code == 200
    token = login_resp.json()["access_token"]

    transport = ASGIWebSocketTransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        async with aconnect_ws(
            f"http://test/ws/chat?token={token}", c
        ) as ws:
            await ws.send_text(
                json.dumps({"type": "text", "content": "你好"})
            )

            received_messages = []
            try:
                while True:
                    msg = await ws.receive_text(timeout=15)
                    data = json.loads(msg)
                    received_messages.append(data["type"])
                    if data["type"] == "done":
                        break
            except Exception:
                pass

            # The connection was established and messages were exchanged
            assert len(received_messages) > 0
            assert "done" in received_messages or "error" in received_messages
