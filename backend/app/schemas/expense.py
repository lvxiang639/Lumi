from pydantic import BaseModel
from datetime import datetime


class ExpenseItem(BaseModel):
    id: str
    amount: float
    category: str
    remark: str
    recorded_at: datetime
    created_at: datetime


class CreateExpense(BaseModel):
    amount: float
    category: str = "其他"
    remark: str = ""
    recorded_at: datetime | None = None


class UpdateExpense(BaseModel):
    amount: float | None = None
    category: str | None = None
    remark: str | None = None


class ExpenseStats(BaseModel):
    total_expense: float
    total_income: float
    by_category: dict[str, float]
