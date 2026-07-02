# ── Domain models (lightweight DDD) ──

# User domain
from app.models.user import User
from app.models.user_memory import UserMemory
from app.models.emotion_state import UserEmotionState

# Chat domain
from app.models.conversation import Conversation
from app.models.message import Message, MessageRole, MessageType
from app.models.conv_memory import ConvMemory

# Calendar domain
from app.models.calendar_event import CalendarEvent

# Expense domain
from app.models.expense_record import ExpenseRecord

# Character domain
from app.models.character import Character
from app.models.inventory import UserInventory, ItemType
from app.models.voice_pack import VoicePack
from app.models.outfit import Outfit

# Tools domain
from app.models.converted_file import ConvertedFile
from app.models.note import Note, MoodLog
from app.models.sent_email import SentEmail
from app.models.countdown import Countdown
from app.models.proactive_push import ProactivePush
from app.models.reminder_schedule import ReminderSchedule
from app.models.knowledge_base import KnowledgeBase, KnowledgeChunk

from app.models.study_record import StudyRecord, PracticePush, StudyChild
from app.models.knowledge_point import KnowledgePoint
from app.models.lesson_content import LessonContent
from app.models.homophone_exercise import HomophoneExercise
from app.models.user_agent import UserAgent, AgentStep
from app.models.daily_content_config import DailyContentConfig
from app.models.daily_content import DailyContent
from app.models.ocr_record import OcrRecord
from app.database import Base

__all__ = [
    "Base",
    # User
    "User", "UserMemory", "UserEmotionState",
    # Chat
    "Conversation", "ConvMemory", "Message", "MessageRole", "MessageType",
    # Calendar
    "CalendarEvent",
    # Expense
    "ExpenseRecord",
    # Character
    "Character", "UserInventory", "ItemType", "VoicePack", "Outfit",
    # Tools
    "ConvertedFile", "SentEmail", "Note", "MoodLog", "Countdown", "ProactivePush", "ReminderSchedule",
]
