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

class EmailRegisterRequest(BaseModel):
    email: str = Field(..., max_length=200)
    password: str = Field(..., min_length=6, max_length=100)
    nickname: str = Field(default="", max_length=50)

class EmailLoginRequest(BaseModel):
    email: str = Field(..., max_length=200)
    password: str = Field(..., min_length=1, max_length=100)

class UpdateProfileRequest(BaseModel):
    nickname: str | None = None
    avatar: str | None = None
    email: str | None = None
    persona: str | None = None
