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

    def _get_ocr(self):
        """Lazy-load PaddleOCR for text recognition."""
        if self._ocr is None:
            from paddleocr import PaddleOCR
            self._ocr = PaddleOCR(lang='ch', use_textline_orientation=True)
            logger.info("PaddleOCR text model loaded")
        return self._ocr

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
        """Pre-load OCR model at startup so first request is fast."""
        logger.info("Warming up OCR model...")
        try:
            self._get_ocr()
            logger.info("  ✓ PaddleOCR ready")
        except Exception as e:
            logger.warning(f"  ✗ PaddleOCR warmup failed: {e}")


# ── Singleton instance ───────────────────────────────────────────────

ocr_service = OCRService()
