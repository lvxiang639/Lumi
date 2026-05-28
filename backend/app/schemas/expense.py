from typing import Literal
from pydantic import BaseModel, Field
from datetime import datetime


class ExpenseItem(BaseModel):
    id: str
    amount: float
    category: str
    remark: str
    recorded_at: datetime
    created_at: datetime


class CreateExpense(BaseModel):
    amount: float = Field(..., description="正数=支出, 负数=收入")
    category: Literal["餐饮", "交通", "购物", "娱乐", "住房", "医疗", "教育", "其他"] = "其他"
    remark: str = Field("", max_length=500)
    recorded_at: datetime | None = None


class UpdateExpense(BaseModel):
    amount: float | None = None
    category: str | None = None
    remark: str | None = None


class ExpenseStats(BaseModel):
    total_expense: float
    total_income: float
    by_category: dict[str, float]
