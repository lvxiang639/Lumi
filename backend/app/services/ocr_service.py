"""
Unified OCR service — PaddleOCR + PP-StructureV3 + Qwen-VL fallback.

Usage:
    from app.services.ocr_service import ocr_service
    text = await ocr_service.recognize_text(image_bytes)
    structure = await ocr_service.analyze_structure(image_bytes)
    description = await ocr_service.understand_with_qwen(image_bytes)
"""

import io
import base64
import logging
import asyncio
from typing import Optional

logger = logging.getLogger(__name__)


class OCRService:
    """Singleton OCR service wrapping PaddleOCR, PP-StructureV3, and Qwen-VL."""

    def __init__(self):
        self._ocr = None
        self._structure = None

    # ── Lazy-load helpers ────────────────────────────────────────────

    def _get_ocr(self):
        """Lazy-load PaddleOCR for text recognition."""
        if self._ocr is None:
            from paddleocr import PaddleOCR
            self._ocr = PaddleOCR(lang='ch', use_textline_orientation=True)
            logger.info("PaddleOCR text model loaded")
        return self._ocr

    def _get_structure(self):
        """Lazy-load PPStructureV3 for document layout analysis."""
        if self._structure is None:
            from paddleocr import PPStructureV3
            self._structure = PPStructureV3(
                use_doc_orientation_classify=True,
                use_doc_unwarping=True,
            )
            logger.info("PPStructureV3 model loaded")
        return self._structure

    # ── Sync recognition methods (called via run_in_executor) ─────────

    def _recognize_text_sync(self, image_bytes: bytes) -> str:
        """Run PaddleOCR text recognition on image bytes.

        Returns extracted text lines joined by newlines, or empty string on failure.
        """
        try:
            from PIL import Image
            import numpy as np

            ocr = self._get_ocr()
            img = Image.open(io.BytesIO(image_bytes))
            img_np = np.array(img)
            result = ocr.predict(img_np)

            lines = []
            for r in result:
                data = r.json if hasattr(r, 'json') else {}
                res = data.get('res', data)
                texts = res.get('rec_texts', [])
                for text in texts:
                    if text and text.strip():
                        lines.append(text.strip())
            return '\n'.join(lines) if lines else ''
        except ImportError:
            logger.warning("PaddleOCR not installed — install paddleocr>=3.0")
            return ''
        except Exception:
            logger.exception("PaddleOCR text recognition failed")
            return ''

    def _analyze_structure_sync(self, image_bytes: bytes, use_chart_recognition: bool = False) -> dict:
        """Run PPStructureV3 document layout analysis.

        Returns dict with:
          - markdown: full markdown reconstruction
          - elements: list of {type, bbox, content} for each region
          - error: error message if analysis failed (optional)
        """
        try:
            from PIL import Image
            import numpy as np

            structure = self._get_structure()
            img = Image.open(io.BytesIO(image_bytes))
            img_np = np.array(img)

            # PPStructureV3.predict() returns list of layout elements
            result = structure.predict(img_np)

            elements = self._extract_elements(result)
            markdown = self._build_markdown(elements)

            return {
                "markdown": markdown,
                "elements": elements,
            }
        except ImportError:
            logger.warning("PPStructureV3 not installed — install paddleocr>=3.0")
            return {"markdown": "", "elements": [], "error": "PPStructureV3 未安装"}
        except Exception:
            logger.exception("PPStructureV3 analysis failed")
            return {"markdown": "", "elements": [], "error": "版面分析失败"}

    def _extract_elements(self, result) -> list:
        """Convert PPStructureV3 raw result to a list of element dicts.

        PPStructureV3 returns a list where each item has:
          - type: 'text' | 'table' | 'figure' | 'formula' | ...
          - bbox: [x1, y1, x2, y2]
          - res: extracted content (varies by type)
        """
        elements = []
        for item in result:
            elem = {}
            if isinstance(item, dict):
                elem["type"] = item.get("type", "text")
                elem["bbox"] = item.get("bbox", [])
                elem["content"] = item.get("res", "")
            elif hasattr(item, 'json'):
                # Handle PaddleOCR result objects
                data = item.json if callable(item.json) else item.json
                elem["type"] = data.get("type", "text")
                elem["bbox"] = data.get("bbox", [])
                elem["content"] = data.get("res", "")
            else:
                elem["type"] = "text"
                elem["bbox"] = []
                elem["content"] = str(item)
            elements.append(elem)
        return elements

    def _build_markdown(self, elements: list) -> str:
        """Build a Markdown string from structured layout elements."""
        parts = []
        for elem in elements:
            t = elem.get("type", "text")
            content = elem.get("content", "")
            if not content:
                continue

            if t == "text":
                parts.append(content)
            elif t == "table":
                parts.append(f"\n{content}\n")
            elif t == "formula":
                parts.append(f"$$\n{content}\n$$")
            elif t == "figure":
                parts.append(f"> [图片区域]\n")
            elif t == "chart":
                parts.append(f"\n{content}\n")
            else:
                parts.append(content)
        return "\n\n".join(parts)

    # ── Async wrappers ───────────────────────────────────────────────

    async def recognize_text(self, image_bytes: bytes) -> str:
        """Async wrapper for text OCR."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(None, self._recognize_text_sync, image_bytes)

    async def analyze_structure(self, image_bytes: bytes, use_chart_recognition: bool = False) -> dict:
        """Async wrapper for PPStructureV3 layout analysis."""
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, self._analyze_structure_sync, image_bytes, use_chart_recognition
        )

    async def understand_with_qwen(self, image_bytes: bytes) -> str:
        """Use Qwen-VL to fully describe an image (text + diagrams + context).

        Used as fallback when PaddleOCR returns empty or for images
        with complex charts/diagrams that need semantic understanding.
        """
        try:
            from openai import AsyncOpenAI
            from app.config import settings

            b64 = base64.b64encode(image_bytes).decode()
            client = AsyncOpenAI(
                api_key=settings.qwen_api_key,
                base_url=settings.qwen_base_url,
            )
            model = getattr(settings, 'qwen_vision_model_name', 'qwen-vl-plus')

            resp = await client.chat.completions.create(
                model=model,
                messages=[{
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": (
                                "请完整描述这张图片中的所有内容，包括：\n"
                                "1. 所有文字内容\n"
                                "2. 图表、图形、公式的描述\n"
                                "3. 如果是题目，完整描述题目信息（含图表数据）\n\n"
                                "请尽可能详细，以便后续解题。"
                            ),
                        },
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
                        },
                    ],
                }],
                max_tokens=1024,
            )
            return (resp.choices[0].message.content or "").strip()
        except Exception:
            logger.exception("Qwen-VL image understanding failed")
            return ""

    # ── Warmup ───────────────────────────────────────────────────────

    def warmup(self):
        """Pre-load OCR models at startup so first request is fast."""
        logger.info("Warming up OCR models...")
        try:
            self._get_ocr()
            logger.info("  ✓ PaddleOCR text model ready")
        except Exception as e:
            logger.warning(f"  ✗ PaddleOCR warmup failed: {e}")

        try:
            self._get_structure()
            logger.info("  ✓ PPStructureV3 model ready")
        except Exception as e:
            logger.warning(f"  ✗ PPStructureV3 warmup failed: {e}")


# ── Singleton instance ───────────────────────────────────────────────

ocr_service = OCRService()
