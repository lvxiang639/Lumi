import asyncio
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database import async_session
from app.core.security import decode_access_token
from app.services.chat_orchestrator import chat_orchestrator
from app.services.connection_manager import register, unregister

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

    connected = True

    async def send_message(msg: dict):
        nonlocal connected
        if not connected:
            return
        try:
            await ws.send_text(json.dumps(msg, ensure_ascii=False))
        except Exception:
            connected = False
            unregister(user_id, send_message)

    register(user_id, send_message)

    # Send memory-driven greeting on connect
    async def _send_greeting():
        try:
            from app.services.proactive_service import send_memory_greeting
            msg = await send_memory_greeting(user_id)
            if msg:
                await send_message({"type": "llm_stream", "delta": msg})
                await send_message({"type": "done"})
        except Exception:
            pass

    asyncio.create_task(_send_greeting())

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
                    # ============================================================
                    # VOICE FEATURE DISABLED — 语音功能已注释，后续可恢复
                    # ============================================================
                    # elif msg_type == "voice":
                    #     await chat_orchestrator.process_voice(
                    #         user_id,
                    #         data["audio"],
                    #         data.get("conversation_id"),
                    #         db,
                    #         send_message,
                    #     )
                    else:
                        await send_message(
                            {
                                "type": "error",
                                "message": f"Unknown type: {msg_type}",
                            }
                        )
                except Exception:
                    logger.exception("Error processing message: user=%s, type=%s", user_id[:8], msg_type)
                    await send_message({"type": "error", "message": "处理消息时出错，请重试"})

        except WebSocketDisconnect:
            unregister(user_id, send_message)
            logger.info("WS disconnected: user=%s", user_id[:8])
