"""Track active WebSocket connections and enable server-push messaging."""

import asyncio
import json
import logging
from collections import defaultdict

logger = logging.getLogger("connection")

# user_id → list of send_message callables
_connections: dict[str, list] = defaultdict(list)


def register(user_id: str, send_message) -> None:
    """Called when a WebSocket connects. Only keep latest connection per user."""
    user_id = str(user_id)
    # Close old connections to prevent duplicate pushes
    old = _connections.get(user_id, [])
    for old_send in old:
        _connections[user_id].remove(old_send)
    _connections[user_id].append(send_message)
    logger.debug("user=%s connected (connections=%d, replaced=%d)", user_id[:8], len(_connections[user_id]), len(old))


def unregister(user_id: str, send_message) -> None:
    """Called when a WebSocket disconnects."""
    user_id = str(user_id)
    try:
        _connections[user_id].remove(send_message)
        if not _connections[user_id]:
            del _connections[user_id]
    except (ValueError, KeyError):
        pass
    logger.debug("user=%s disconnected", user_id[:8])


async def send_to_user(user_id: str, message: dict) -> bool:
    """Push a message to user's active connection. Returns True if sent."""
    user_id = str(user_id)
    senders = _connections.get(user_id, [])
    if not senders:
        return False
    # Only send to the latest connection to prevent duplicates
    sender = senders[-1]
    try:
        await sender(message)
        return True
    except Exception:
        logger.warning("send failed for user=%s", user_id[:8])
        return False


def online_users() -> set[str]:
    """Return set of currently connected user IDs."""
    return set(_connections.keys())
