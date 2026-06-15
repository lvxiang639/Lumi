"""Domain service for authentication — user creation, welcome flow."""

from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession

WELCOME_MESSAGE = """嗨！欢迎来到 **灵犀 AI 伴侣** 🎉

我是你的智能助手，可以陪你聊天、帮你处理各种事务。以下是我的主要功能：

---

### 💬 智能聊天
像朋友一样和我聊天！我会记住你说过的话，根据语境给出贴心的回应。支持语音输入和文字输入，回复中支持 **Markdown 格式**（标题、列表、代码、链接等）。

### 🛠️ 工具中心（底部「工具」Tab）

| 工具 | 功能 |
|------|------|
| 📅 **日历** | 添加和管理日程提醒，支持时间/事件自动提取 |
| 💰 **记账** | 记录收支，按类别统计，每周生成消费洞察报告 |
| 📝 **笔记** | 随手记笔记，支持分类管理 |
| 😊 **心情** | 记录每日心情，跟踪情绪变化 |
| ✉️ **邮件** | 将对话摘要发送到指定邮箱 |
| 📄 **文档** | 文件格式转换（PDF ↔ Word） |
| 📊 **摘要** | 对话内容自动摘要提炼 |
| 🔍 **OCR** | 拍照识别图中文字，支持版面分析（PP-StructureV3） |
| ⏳ **倒数日** | 重要日期倒计时，到期提醒 |
| 📚 **辅导** | AI 辅导解题（数学/语文/英语），含同音字闯关等专项练习 |
| 🤖 **Agent** | AI Agent 多步骤任务执行 |
| 🗂️ **知识库** | 上传文档建立个人知识库，基于文档内容智能问答 |

### 🔍 发现页（底部「发现」Tab）
每日精选内容推送：热点话题、古诗词、成语故事、历史知识等。

### 👤 个人中心（底部「我」Tab）
- 自定义 AI 昵称和性格
- 更换角色服装和语音
- 深色/浅色主题切换

---

### 📌 快速上手

1. **聊天**：直接在底部输入框打字或点击麦克风说话
2. **快捷回复**：AI 回复后会推荐快捷回复，一键点击即可
3. **长按消息**：可以复制、保存为笔记
4. **右上角菜单**：在聊天中点 ⋮ 可以导出对话、发邮件、生成摘要

有任何问题随时问我，开始我们的对话吧！😊"""


class AuthService:
    """Domain service for authentication operations."""

    @staticmethod
    async def create_welcome_conversation(db: AsyncSession, user_id: UUID) -> None:
        """Create a default welcome conversation for a new user."""
        from app.models.conversation import Conversation
        from app.models.message import Message, MessageRole, MessageType

        conv = Conversation(
            id=uuid4(),
            user_id=user_id,
            title="👋 欢迎来到灵犀",
        )
        db.add(conv)
        await db.flush()

        msg = Message(
            conv_id=conv.id,
            role=MessageRole.assistant,
            type=MessageType.text,
            content=WELCOME_MESSAGE,
        )
        db.add(msg)
        await db.commit()
