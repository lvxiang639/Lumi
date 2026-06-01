import asyncio
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from smtplib import SMTP_SSL, SMTPException

from app.config import settings

logger = logging.getLogger("email")


async def send_email(to: str, subject: str, body: str) -> bool:
    """Send a plain-text email via SMTP. Runs the blocking SMTP call in a
    thread so the event loop is never blocked."""

    if not settings.smtp_host:
        logger.warning("SMTP not configured, cannot send email to %s", to)
        return False

    msg = MIMEMultipart()
    msg["From"] = settings.smtp_from_email
    msg["To"] = to
    msg["Subject"] = subject
    msg.attach(MIMEText(body, "plain", "utf-8"))

    try:
        await asyncio.to_thread(_send_sync, msg, to)
        logger.info("Email sent to %s", to)
        return True
    except SMTPException:
        logger.exception("SMTP error sending to %s", to)
    except Exception:
        logger.exception("Unexpected email error")
    return False


def _send_sync(msg: MIMEMultipart, to: str) -> None:
    with SMTP_SSL(settings.smtp_host, settings.smtp_port) as smtp:
        if settings.smtp_username:
            smtp.login(settings.smtp_username, settings.smtp_password)
        smtp.send_message(msg)
