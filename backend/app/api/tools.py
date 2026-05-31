import logging
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import Response

from app.api.deps import get_current_user
from app.models import User
from app.services.conversion_service import convert

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/tools", tags=["tools"])

ALLOWED_EXTENSIONS = {"docx", "pdf"}


@router.post("/convert")
async def convert_file(
    file: UploadFile = File(...),
    target: str = Query(..., pattern="^(docx|pdf)$"),
    current_user: User = Depends(get_current_user),
):
    """Upload a .docx or .pdf file and convert to the other format."""

    # Determine source format from filename extension
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

    # Build output filename
    out_name = file.filename.rsplit(".", 1)[0] + "." + target
    media_type = (
        "application/pdf" if target == "pdf"
        else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    )

    encoded_name = quote(out_name, safe="")
    return Response(
        content=result,
        media_type=media_type,
        headers={
            "Content-Disposition": (
                f"attachment; filename*=UTF-8''{encoded_name}"
            ),
        },
    )
