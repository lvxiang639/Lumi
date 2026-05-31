from pydantic import BaseModel, Field

class LoginRequest(BaseModel):
    phone: str = Field(..., pattern=r"^1[3-9]\d{9}$")

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    is_new_user: bool = False

class RefreshResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"

class UserProfile(BaseModel):
    id: str
    phone: str
    nickname: str
    avatar: str
    email: str | None = None

class UpdateProfileRequest(BaseModel):
    nickname: str | None = None
    avatar: str | None = None
    email: str | None = None
