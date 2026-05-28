import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database import async_session
from app.core.security import decode_access_token
from app.services.chat_orchestrator import chat_orchestrator

logger = logging.getLogger("ws")
router = APIRouter()


@router.websocket("/ws/chat")
async def websocket_chat(ws: WebSocket):
    token = ws.query_params.get("token", "")
    payload = decode_access_token(token)
    if payload is None:
        await ws.close(code=4001)
        return

    user_id = payload["sub"]
    await ws.accept()
    logger.info("WS connected: user=%s", user_id[:8])

    async def send_message(msg: dict):
        await ws.send_text(json.dumps(msg, ensure_ascii=False))

    async with async_session() as db:
        try:
            while True:
                raw = await ws.receive_text()
                data = json.loads(raw)
                msg_type = data.get("type")

                try:
                    if msg_type == "text":
                        await chat_orchestrator.process_text(
                            user_id,
                            data["content"],
                            data.get("conversation_id"),
                            db,
                            send_message,
                        )
                    elif msg_type == "voice":
                        await chat_orchestrator.process_voice(
                            user_id,
                            data["audio"],
                            data.get("conversation_id"),
                            db,
                            send_message,
                        )
                    else:
                        await send_message(
                            {
                                "type": "error",
                                "message": f"Unknown type: {msg_type}",
                            }
                        )
                except Exception as e:
                    logger.exception("Error processing message: user=%s, type=%s", user_id[:8], msg_type)
                    await send_message({"type": "error", "message": str(e)})

        except WebSocketDisconnect:
            logger.info("WS disconnected: user=%s", user_id[:8])
