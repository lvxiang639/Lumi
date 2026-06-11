from time import time
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from app.database import get_db
from app.models import User
from app.schemas.auth import (
    LoginRequest, LoginResponse, RefreshResponse, UserProfile,
    UpdateProfileRequest, EmailRegisterRequest, EmailLoginRequest,
)
from app.core.security import create_access_token
from app.api.deps import get_current_user

router = APIRouter(prefix="/api/auth", tags=["auth"])

# Simple in-memory rate limiter: phone → (count, window_start)
_rate_limits: dict[str, tuple[int, float]] = {}

def _check_rate_limit(key: str, max_req: int = 10, window: int = 60) -> bool:
    now = time()
    entry = _rate_limits.get(key)
    if entry is None or (now - entry[1]) > window:
        _rate_limits[key] = (1, now)
        return True
    count, start = entry
    if count >= max_req:
        return False
    _rate_limits[key] = (count + 1, start)
    return True


@router.post("/login", response_model=LoginResponse)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    # Rate limit: 10 requests per 60 seconds per phone number
    if not _check_rate_limit(req.phone):
        raise HTTPException(429, "请求过于频繁，请稍后再试")
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

# ── Email auth ──

import bcrypt

def _hash_pw(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()

def _verify_pw(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode(), hashed.encode())


@router.post("/register", response_model=LoginResponse)
async def register(req: EmailRegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check email uniqueness
    existing = await db.execute(select(User).where(User.email == req.email))
    if existing.scalar_one_or_none():
        raise HTTPException(409, "该邮箱已注册")

    nickname = req.nickname or f"用户{req.email[:4]}"
    user = User(
        phone=f"em_{req.email[:30]}",  # placeholder phone for email users
        email=req.email,
        nickname=nickname,
        hashed_password=_hash_pw(req.password),
    )
    db.add(user)
    try:
        await db.commit()
        await db.refresh(user)
    except IntegrityError:
        await db.rollback()
        raise HTTPException(409, "注册失败，请重试")

    token = create_access_token({"sub": str(user.id)})
    return LoginResponse(access_token=token, is_new_user=True)


@router.post("/email-login", response_model=LoginResponse)
async def email_login(req: EmailLoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == req.email))
    user = result.scalar_one_or_none()
    if not user or not user.hashed_password:
        raise HTTPException(401, "邮箱或密码错误")
    if not _verify_pw(req.password, user.hashed_password):
        raise HTTPException(401, "邮箱或密码错误")

    token = create_access_token({"sub": str(user.id)})
    return LoginResponse(access_token=token, is_new_user=False)


@router.delete("/account")
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Permanently delete user account and all associated data."""
    await db.delete(current_user)
    await db.commit()
    return {"status": "deleted"}


@router.post("/refresh", response_model=RefreshResponse)
async def refresh_token(current_user: User = Depends(get_current_user)):
    token = create_access_token({"sub": str(current_user.id)})
    return RefreshResponse(access_token=token)

@router.get("/profile", response_model=UserProfile)
async def get_profile(current_user: User = Depends(get_current_user)):
    return UserProfile(
        id=str(current_user.id), phone=current_user.phone,
        nickname=current_user.nickname, avatar=current_user.avatar,
        email=current_user.email,
    )

@router.put("/profile", response_model=UserProfile)
async def update_profile(req: UpdateProfileRequest, current_user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    if req.nickname is not None:
        current_user.nickname = req.nickname
    if req.avatar is not None:
        current_user.avatar = req.avatar
    if req.email is not None:
        current_user.email = req.email
    if req.persona is not None:
        # Save persona preference as user memory
        from app.models.user_memory import UserMemory
        from sqlalchemy import select as sa_select
        r = await db.execute(sa_select(UserMemory).where(
            UserMemory.user_id == current_user.id, UserMemory.key == "ai_persona"))
        mems = r.scalars().all()
        # Clean duplicates, keep first
        if len(mems) > 1:
            for m in mems[1:]:
                await db.delete(m)
            await db.flush()
        mem = mems[0] if mems else None
        if mem:
            mem.value = req.persona
        else:
            db.add(UserMemory(user_id=current_user.id, key="ai_persona", value=req.persona))
    await db.commit()
    await db.refresh(current_user)
    return UserProfile(
        id=str(current_user.id), phone=current_user.phone,
        nickname=current_user.nickname, avatar=current_user.avatar,
        email=current_user.email,
    )
