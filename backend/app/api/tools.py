import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.api.deps import get_current_user
from app.database import get_db
from app.models import User, ConvertedFile
from app.services.conversion_service import convert
from app.services.minio_service import upload_file, get_download_url, get_file
from app.services.llm_service import llm_router
from app.services.ocr_service import ocr_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/tools", tags=["tools"])

ALLOWED_EXTENSIONS = {"docx", "pdf"}


@router.post("/convert")
async def convert_file(
    file: UploadFile = File(...),
    target: str = Query(..., pattern="^(docx|pdf)$"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a .docx or .pdf, convert, save to MinIO, return record."""

    if not file.filename:
        raise HTTPException(400, "Missing filename")
    ext = file.filename.rsplit(".", 1)[-1].lower()
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(400, f"Unsupported file type: .{ext}")
    if ext == target:
        raise HTTPException(400, f"Source and target are both .{ext}")

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(400, "Empty file")

    try:
        result = await convert(file_bytes, source=ext, target=target)
    except ValueError as e:
        raise HTTPException(400, str(e))
    except Exception:
        logger.exception("Conversion failed: %s → %s", ext, target)
        raise HTTPException(500, "文件转换失败，请确认文件格式正确")

    out_name = file.filename.rsplit(".", 1)[0] + "." + target
    media_type = (
        "application/pdf" if target == "pdf"
        else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )

    # Upload to MinIO
    object_name = await upload_file(bytes(result), out_name, media_type)
    if not object_name:
        raise HTTPException(500, "文件存储失败")

    # Save record
    record = ConvertedFile(
        user_id=current_user.id,
        original_name=file.filename,
        target_name=out_name,
        object_name=object_name,
        content_type=media_type,
        file_size=len(result),
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    download_url = await get_download_url(object_name)

    return {
        "id": str(record.id),
        "original_name": record.original_name,
        "target_name": record.target_name,
        "file_size": record.file_size,
        "created_at": record.created_at.isoformat(),
        "download_url": download_url,
    }


@router.get("/files")
async def list_files(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List all converted files for the current user."""
    result = await db.execute(
        select(ConvertedFile)
        .where(ConvertedFile.user_id == current_user.id)
        .order_by(desc(ConvertedFile.created_at))
    )
    records = result.scalars().all()

    items = []
    for r in records:
        url = await get_download_url(r.object_name) if r.object_name else None
        items.append({
            "id": str(r.id),
            "original_name": r.original_name,
            "target_name": r.target_name,
            "file_size": r.file_size,
            "content_type": r.content_type,
            "created_at": r.created_at.isoformat(),
            "download_url": url,
        })
    return {"items": items}


@router.get("/files/{file_id}/download")
async def download_file(
    file_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Download a converted file."""
    result = await db.execute(
        select(ConvertedFile).where(
            ConvertedFile.id == file_id,
            ConvertedFile.user_id == current_user.id,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(404, "File not found")

    content = await get_file(record.object_name)
    if not content:
        raise HTTPException(500, "文件下载失败")

    from urllib.parse import quote
    encoded_name = quote(record.target_name, safe='')
    return Response(
        content=content,
        media_type=record.content_type,
        headers={
            "Content-Disposition": (
                f"attachment; filename*=UTF-8''{encoded_name}"
            ),
        },
    )


@router.get("/files/{file_id}/preview")
async def preview_file(
    file_id: UUID,
    token: str = Query(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Preview a file inline (Word → HTML, PDF → raw)."""
    result = await db.execute(
        select(ConvertedFile).where(
            ConvertedFile.id == file_id,
            ConvertedFile.user_id == current_user.id,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(404, "File not found")

    content = await get_file(record.object_name)
    if not content:
        raise HTTPException(500, "文件读取失败")

    # For .docx → convert to HTML
    if record.target_name and record.target_name.lower().endswith(".docx"):
        try:
            import mammoth
            html = mammoth.convert_to_html(content)
            return Response(content=html.value, media_type="text/html; charset=utf-8")
        except ImportError:
            # Fallback: return as text
            return Response(
                content=content,
                media_type=record.content_type,
                headers={"Content-Disposition": "inline"},
            )

    # For .pdf → return inline
    return Response(
        content=content,
        media_type=record.content_type,
        headers={"Content-Disposition": "inline"},
    )


@router.post("/ocr")
async def ocr_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Extract text from an image — PaddleOCR (free, offline, best Chinese recognition)."""
    import base64
    file_bytes = await file.read()
    b64 = base64.b64encode(file_bytes).decode()
    img_b64 = f"data:{file.content_type or 'image/jpeg'};base64,{b64}"

    text = await ocr_service.recognize_text(file_bytes)

    if not text.strip():
        raise HTTPException(500, "图片中未识别到文字，请确认图片清晰且包含中文")

    # Save record
    from app.models.ocr_record import OcrRecord
    record = OcrRecord(user_id=current_user.id, image_base64=img_b64, text=text)
    db.add(record)
    await db.commit()
    await db.refresh(record)

    return {"id": str(record.id), "text": text, "created_at": record.created_at.isoformat()}


@router.get("/ocr/records")
async def list_ocr_records(
    page: int = Query(1),
    limit: int = Query(20),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List OCR records for current user."""
    from app.models.ocr_record import OcrRecord
    q = (
        select(OcrRecord)
        .where(OcrRecord.user_id == current_user.id)
        .order_by(OcrRecord.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    r = await db.execute(q)
    rows = r.scalars().all()
    return {
        "items": [{
            "id": str(row.id),
            "text": row.text[:100],
            "created_at": row.created_at.isoformat() if row.created_at else "",
        } for row in rows],
    }


@router.get("/ocr/records/{record_id}")
async def get_ocr_record(
    record_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get a single OCR record with full text and image."""
    from app.models.ocr_record import OcrRecord
    r = await db.execute(
        select(OcrRecord).where(
            OcrRecord.id == record_id,
            OcrRecord.user_id == current_user.id,
        )
    )
    record = r.scalar_one_or_none()
    if not record:
        raise HTTPException(404, "记录不存在")
    return {
        "id": str(record.id),
        "image_base64": record.image_base64,
        "text": record.text,
        "created_at": record.created_at.isoformat() if record.created_at else "",
    }


@router.post("/ocr/structure")
async def ocr_structure(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """Analyze document structure — PP-StructureV3 layout + chart + formula recognition.

    Returns Markdown and structured elements (text, tables, formulas, figures).
    """
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(400, "文件为空")

    result = await ocr_service.analyze_structure(file_bytes)

    if result.get("error"):
        raise HTTPException(500, result["error"])

    return result
