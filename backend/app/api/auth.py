from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from app.database import get_db
from app.models import User
from app.schemas.auth import LoginRequest, LoginResponse, RefreshResponse, UserProfile, UpdateProfileRequest
from app.core.security import create_access_token
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])

@router.post("/login", response_model=LoginResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.phone == req.phone))
    user = result.scalar_one_or_none()
    is_new = False
    if user is None:
        user = User(phone=req.phone, nickname=f"用户{req.phone[-4:]}")
        db.add(user)
        try:
            await db.commit()
            await db.refresh(user)
            is_new = True
        except IntegrityError:
            await db.rollback()
            # Race: another request created this user, re-query
            result = await db.execute(select(User).where(User.phone == req.phone))
            user = result.scalar_one_or_none()
            if user is None:
                raise HTTPException(500, "Registration failed")
    token = create_access_token({"sub": str(user.id)})
    return LoginResponse(access_token=token, is_new_user=is_new)

@router.post("/refresh", response_model=RefreshResponse)
async def refresh_token(current_user: User = Depends(get_current_user)):
    token = create_access_token({"sub": str(current_user.id)})
    return RefreshResponse(access_token=token)

@router.get("/profile", response_model=UserProfile)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserProfile(id=str(current_user.id), phone=current_user.phone, nickname=current_user.nickname, avatar=current_user.avatar)

@router.put("/profile", response_model=UserProfile)
async def update_profile(req: UpdateProfileRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if req.nickname is not None:
        current_user.nickname = req.nickname
    if req.avatar is not None:
        current_user.avatar = req.avatar
    await db.commit()
    await db.refresh(current_user)
    return UserProfile(id=str(current_user.id), phone=current_user.phone, nickname=current_user.nickname, avatar=current_user.avatar)
