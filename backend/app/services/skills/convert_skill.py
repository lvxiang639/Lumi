import base64
import logging
from pathlib import Path

from app.services.skills.base import BaseSkill, SkillResult
from app.services.conversion_service import convert

logger = logging.getLogger("convert_skill")


class ConvertSkill(BaseSkill):
    name = "convert"

    async def execute(self, user_id: str, user_input: str, db) -> SkillResult:
        """If file data is embedded in the message, convert it.
        Otherwise prompt the user to upload a file."""

        # Determine target format from user's message
        target = _detect_target(user_input)

        # The orchestrator may embed file data in the message (base64)
        # Format:  "BASE64:<filename>|<base64_data>"  or just text
        if user_input.startswith("BASE64:"):
            try:
                _, payload = user_input.split(":", 1)
                fname, b64data = payload.split("|", 1)
                file_bytes = base64.b64decode(b64data)
            except Exception:
                return SkillResult(text="文件数据解析失败，请重新上传")

            # Detect source from filename extension
            ext = Path(fname).suffix.lstrip(".").lower()
            if ext not in ("docx", "pdf"):
                return SkillResult(
                    text=f"不支持的文件格式 .{ext}，请上传 .docx 或 .pdf 文件"
                )

            if not target:
                target = "pdf" if ext == "docx" else "docx"

            if target == ext:
                return SkillResult(text=f"文件已经是 .{ext} 格式了")

            try:
                result_bytes = await convert(file_bytes, source=ext, target=target)
            except Exception:
                logger.exception("conversion failed")
                return SkillResult(text="文件转换失败，请确认文件格式正确")

            # Return as base64
            out_b64 = base64.b64encode(result_bytes).decode()
            out_name = Path(fname).stem + "." + target

            return SkillResult(
                text=f"✅ 转换完成: {out_name}",
                data={
                    "filename": out_name,
                    "content_type": (
                        "application/pdf" if target == "pdf"
                        else "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                    ),
                    "file_base64": out_b64,
                },
            )

        # No file — ask user to upload
        return SkillResult(
            text="请先上传一个文件（.docx 或 .pdf），我会帮你转换成另一种格式。"
        )


def _detect_target(text: str) -> str | None:
    t = text.lower()
    if "pdf" in t or "转成pdf" in t or "转为pdf" in t or "转pdf" in t:
        return "pdf"
    if "word" in t or "docx" in t or "转成word" in t or "转为word" in t:
        return "docx"
    return None


convert_skill = ConvertSkill()
