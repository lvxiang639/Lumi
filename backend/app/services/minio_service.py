import io
import logging
import uuid

from minio import Minio
from minio.error import S3Error

from app.config import settings

logger = logging.getLogger("minio")

_client: Minio | None = None


def _get_client() -> Minio:
    global _client
    if _client is None:
        _client = Minio(
            settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            secure=False,
        )
        _ensure_bucket(_client)
    return _client


def _ensure_bucket(client: Minio) -> None:
    bucket = settings.minio_bucket
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        logger.info("Created MinIO bucket: %s", bucket)


async def upload_file(file_bytes: bytes, filename: str, content_type: str = "application/octet-stream") -> str | None:
    """Upload to MinIO, return the object name (UUID-based)."""
    try:
        client = _get_client()
        ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
        object_name = f"conversions/{uuid.uuid4().hex}.{ext}"
        client.put_object(
            settings.minio_bucket,
            object_name,
            io.BytesIO(file_bytes),
            length=len(file_bytes),
            content_type=content_type,
        )
        logger.info("Uploaded to MinIO: %s (%d bytes)", object_name, len(file_bytes))
        return object_name
    except S3Error:
        logger.exception("MinIO upload failed")
        return None


async def get_download_url(object_name: str, expiry_seconds: int = 3600) -> str | None:
    """Generate a presigned download URL (default 1 hour expiry)."""
    try:
        client = _get_client()
        return client.presigned_get_object(
            settings.minio_bucket, object_name, expires=expiry_seconds
        )
    except S3Error:
        logger.exception("MinIO presigned URL failed")
        return None


async def get_file(object_name: str) -> bytes | None:
    """Download file bytes from MinIO."""
    try:
        client = _get_client()
        response = client.get_object(settings.minio_bucket, object_name)
        try:
            return response.read()
        finally:
            response.close()
            response.release_conn()
    except S3Error:
        logger.exception("MinIO download failed")
        return None
