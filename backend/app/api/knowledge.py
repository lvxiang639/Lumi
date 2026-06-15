"""Knowledge base API — thin controller."""

import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models import User
from app.models.knowledge_base import KnowledgeBase
from app.api.deps import get_current_user
from app.domain.knowledge.service import KnowledgeService
from app.domain.knowledge.repository import KnowledgeRepository
from app.infrastructure.knowledge.repository import SqlKnowledgeRepository
from app.services.llm_service import llm_router
from app.services.minio_service import upload_file, get_file

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/knowledge", tags=["knowledge"])


def _get_service(db: AsyncSession) -> KnowledgeService:
    repo: KnowledgeRepository = SqlKnowledgeRepository(db)
    return KnowledgeService(repo)


@router.post("/upload")
async def upload_document(
    file: UploadFile = File(...),
    title: str = Form(""),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload a document, parse it, and create a knowledge base."""
    if not file.filename:
        raise HTTPException(400, "文件名为空")

    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    logger.info("kb upload: user=%s file=%s ext=%s", str(current_user.id)[:8], file.filename, ext)

    # Read + decode
    content = await file.read()
    logger.info("kb upload: read %d bytes", len(content))

    # Save original file to MinIO
    media_type = file.content_type or "application/octet-stream"
    object_name = await upload_file(bytes(content), file.filename, media_type)
    logger.info("kb upload: saved to MinIO as %s", object_name)

    text = _extract_text(content, file.filename)
    if not text or not text.strip():
        logger.warning("kb upload: empty text after extraction (ext=%s, size=%d)", ext, len(content))
        raise HTTPException(400, f"无法解析文档内容（格式: .{ext}，大小: {len(content)} bytes）。请确认文件未被加密或扫描。")

    logger.info("kb upload: extracted %d chars, starting ingest", len(text))

    try:
        svc = _get_service(db)
        kb = await svc.ingest_document(
            current_user.id, title or file.filename, file.filename,
            text, object_name=object_name or "", file_size=len(content),
        )
        logger.info("kb upload: success kb_id=%s chunks=%d", str(kb.id)[:8], kb.chunk_count)
    except ValueError as e:
        logger.warning("kb upload: validation error: %s", e)
        raise HTTPException(400, str(e))
    except Exception as e:
        logger.exception("kb upload: ingest failed")
        raise HTTPException(500, f"知识库创建失败: {e}")

    return {"id": str(kb.id), "title": kb.title, "chunk_count": kb.chunk_count}


@router.get("/{kb_id}/download")
async def download_original(
    kb_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Download the original uploaded document from MinIO."""
    r = await db.execute(
        select(KnowledgeBase).where(
            KnowledgeBase.id == kb_id,
            KnowledgeBase.user_id == current_user.id,
        )
    )
    kb = r.scalar_one_or_none()
    if not kb:
        raise HTTPException(404, "知识库不存在")
    if not kb.object_name:
        raise HTTPException(404, "原始文件不存在")

    content = await get_file(kb.object_name)
    if not content:
        raise HTTPException(500, "文件下载失败")

    from urllib.parse import quote
    return Response(
        content=content,
        media_type="application/octet-stream",
        headers={"Content-Disposition": f"attachment; filename*=UTF-8''{quote(kb.file_name)}"},
    )


@router.get("")
async def list_knowledge(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """List user's knowledge bases."""
    repo = SqlKnowledgeRepository(db)
    items = await repo.list_by_user(current_user.id)
    return {"items": [{"id": str(k.id), "title": k.title, "file_name": k.file_name, "chunk_count": k.chunk_count, "file_size": k.file_size, "created_at": k.created_at.isoformat() if k.created_at else ""} for k in items]}


@router.delete("/{kb_id}")
async def delete_knowledge(
    kb_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    repo = SqlKnowledgeRepository(db)
    ok = await repo.delete(kb_id, current_user.id)
    if not ok:
        raise HTTPException(404, "Not found")
    return {"status": "deleted"}


@router.post("/{kb_id}/chat")
async def rag_chat(
    kb_id: UUID,
    query: str = Form(...),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Chat with a knowledge base — retrieve + LLM answer."""
    svc = _get_service(db)

    # Retrieve relevant chunks
    chunks = await svc.retrieve(kb_id, current_user.id, query, top_k=3)
    if not chunks:
        return {"answer": "在知识库中没有找到相关内容。", "sources": []}

    # Build RAG prompt
    context = "\n\n---\n\n".join(chunks)
    prompt = f"""根据以下文档内容回答用户的问题。如果文档中没有相关信息，请明确说明。

文档内容:
{context}

用户问题: {query}

请基于文档内容回答，并在回答中标注信息来源。"""

    try:
        answer = await llm_router.chat([{"role": "user", "content": prompt}])
        return {"answer": answer or "无法生成回答", "sources": [c[:100] + "..." for c in chunks]}
    except Exception:
        raise HTTPException(500, "AI回答生成失败")


def _extract_text(content: bytes, filename: str) -> str:
    """Extract text from various file formats."""
    ext = filename.lower().rsplit(".", 1)[-1] if "." in filename else ""
    try:
        if ext == "pdf":
            import io
            from PyPDF2 import PdfReader
            reader = PdfReader(io.BytesIO(content))
            return "\n".join(page.extract_text() or "" for page in reader.pages)
        elif ext == "docx":
            import io
            from docx import Document
            doc = Document(io.BytesIO(content))
            return "\n".join(p.text for p in doc.paragraphs)
        elif ext == "txt":
            return content.decode("utf-8", errors="ignore")
        else:
            return content.decode("utf-8", errors="ignore")
    except Exception as e:
        logger.exception("text extraction failed: %s", filename)
        return ""
