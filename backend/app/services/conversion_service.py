import io
import logging
import tempfile
from pathlib import Path

from docx import Document
from fpdf import FPDF

logger = logging.getLogger("conversion")


async def convert(file_bytes: bytes, source: str, target: str) -> bytes:
    """Convert between DOCX and PDF.  *source* / *target* are 'docx' or 'pdf'."""

    if source == "pdf" and target == "docx":
        return await _pdf_to_docx(file_bytes)
    if source == "docx" and target == "pdf":
        return await _docx_to_pdf(file_bytes)
    raise ValueError(f"Unsupported conversion: {source} → {target}")


# ── PDF → DOCX ────────────────────────────────────────────────────

async def _pdf_to_docx(pdf_bytes: bytes) -> bytes:
    from pdf2docx import Converter

    with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as src:
        src.write(pdf_bytes)
        src.flush()
        src_path = Path(src.name)

    dst_path = src_path.with_suffix(".docx")

    try:
        cv = Converter(str(src_path))
        cv.convert(str(dst_path))
        cv.close()
        logger.info("PDF→DOCX converted, size=%d", dst_path.stat().st_size)
        return dst_path.read_bytes()
    finally:
        src_path.unlink(missing_ok=True)
        dst_path.unlink(missing_ok=True)


# ── DOCX → PDF ────────────────────────────────────────────────────

async def _docx_to_pdf(docx_bytes: bytes) -> bytes:
    """Simple DOCX → PDF using python-docx + fpdf2.

    Preserves basic formatting: paragraphs, bold, font size, alignment.
    Images and complex tables are not preserved by this pure-Python path.
    """

    doc = Document(io.BytesIO(docx_bytes))
    pdf = FPDF()
    pdf.add_page()

    # Try to use a CJK-capable font on macOS
    font_path = _find_cjk_font()
    if font_path:
        pdf.add_font("cjk", "", font_path, uni=True)
        pdf.add_font("cjk", "B", font_path, uni=True)
        font_name = "cjk"
    else:
        font_name = "Helvetica"

    pdf.set_auto_page_break(auto=True, margin=15)

    for para in doc.paragraphs:
        text = para.text.strip()
        if not text:
            pdf.ln(4)
            continue

        # Determine style
        style = para.style.name or ""
        is_heading = style.startswith("Heading") or style == "Title"
        is_bold = any(run.bold for run in para.runs if run.bold)

        size = 16 if style == "Title" else (14 if is_heading else 11)

        fn = font_name
        if is_bold:
            fn += "B" if font_path else font_name

        try:
            pdf.set_font(fn, size=size)
        except Exception:
            pdf.set_font(font_name, size=size)

        # Alignment
        align_map = {0: "L", 1: "C", 2: "R"}
        align = align_map.get(para.alignment, "L") if para.alignment else "L"

        pdf.multi_cell(0, 6, text, align=align)
        pdf.ln(1)

    pdf_bytes = pdf.output()
    logger.info("DOCX→PDF converted, size=%d", len(pdf_bytes))
    return pdf_bytes


def _find_cjk_font() -> str | None:
    """Look for a CJK font on the system so Chinese text renders."""
    candidates = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Light.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/System/Library/Fonts/Supplemental/Songti.ttc",
    ]
    for p in candidates:
        if Path(p).exists():
            return p
    return None
