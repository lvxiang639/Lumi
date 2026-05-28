from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update
from sqlalchemy.orm import selectinload
from app.database import get_db
from app.models import Character, UserInventory, ItemType, Outfit, VoicePack, User
from app.api.deps import get_current_user
from app.schemas.character import (
    CharacterConfig, InitCharacterRequest, UpdateCharacterRequest,
    EquipRequest, OutfitItem, VoicePackItem,
)

router = APIRouter(prefix="/api/characters", tags=["characters"])


def _char_to_config(c: Character) -> CharacterConfig:
    return CharacterConfig(
        id=str(c.id), name=c.name, live2d_model=c.live2d_model,
        outfit_id=str(c.outfit_id) if c.outfit_id else None,
        voice_pack_id=str(c.voice_pack_id) if c.voice_pack_id else None,
        outfit_name=c.outfit.name if c.outfit else None,
        voice_pack_name=c.voice_pack.name if c.voice_pack else None,
    )


@router.post("/init", response_model=CharacterConfig)
async def init_character(
    req: InitCharacterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    existing = await db.execute(
        select(Character)
        .options(selectinload(Character.outfit), selectinload(Character.voice_pack))
        .where(Character.user_id == current_user.id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(400, "Character already initialized")

    default_outfit = await db.execute(select(Outfit).where(Outfit.price == 0).limit(1))
    outfit = default_outfit.scalar_one_or_none()
    default_voice = await db.execute(select(VoicePack).where(VoicePack.price == 0).limit(1))
    voice = default_voice.scalar_one_or_none()

    char = Character(user_id=current_user.id, name=req.name,
                     outfit_id=outfit.id if outfit else None,
                     voice_pack_id=voice.id if voice else None)
    db.add(char)

    if outfit:
        db.add(UserInventory(user_id=current_user.id, item_type=ItemType.outfit,
                             item_id=outfit.id, equipped=True))
    if voice:
        db.add(UserInventory(user_id=current_user.id, item_type=ItemType.voice_pack,
                             item_id=voice.id, equipped=True))

    await db.commit()
    await db.refresh(char)
    return _char_to_config(char)


@router.get("/config", response_model=CharacterConfig)
async def get_character_config(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Character)
        .options(selectinload(Character.outfit), selectinload(Character.voice_pack))
        .where(Character.user_id == current_user.id)
    )
    char = result.scalar_one_or_none()
    if not char:
        raise HTTPException(404, "Character not initialized")
    return _char_to_config(char)


@router.put("/config", response_model=CharacterConfig)
async def update_character(
    req: UpdateCharacterRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Character)
        .options(selectinload(Character.outfit), selectinload(Character.voice_pack))
        .where(Character.user_id == current_user.id)
    )
    char = result.scalar_one_or_none()
    if not char:
        raise HTTPException(404, "Character not initialized")
    if req.name is not None:
        char.name = req.name
    await db.commit()
    await db.refresh(char)
    return _char_to_config(char)


@router.get("/outfits")
async def get_my_outfits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[OutfitItem]:
    result = await db.execute(
        select(UserInventory, Outfit)
        .join(Outfit, UserInventory.item_id == Outfit.id)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == ItemType.outfit)
    )
    rows = result.all()
    return [
        OutfitItem(id=str(o.id), name=o.name, model_file=o.model_file,
                   thumbnail=o.thumbnail, price=float(o.price),
                   equipped=inv.equipped, owned=True)
        for inv, o in rows
    ]


@router.get("/voices")
async def get_my_voices(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[VoicePackItem]:
    result = await db.execute(
        select(UserInventory, VoicePack)
        .join(VoicePack, UserInventory.item_id == VoicePack.id)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == ItemType.voice_pack)
    )
    rows = result.all()
    return [
        VoicePackItem(id=str(v.id), name=v.name, type=v.type, cosyvoice_id=v.cosyvoice_id,
                      price=float(v.price), preview_url=v.preview_url,
                      equipped=inv.equipped, owned=True)
        for inv, v in rows
    ]


@router.put("/equip")
async def equip_item(
    req: EquipRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    item_type = ItemType(req.item_type)
    item_id = UUID(req.item_id)

    # verify ownership
    inv_result = await db.execute(
        select(UserInventory).where(
            UserInventory.user_id == current_user.id,
            UserInventory.item_type == item_type,
            UserInventory.item_id == item_id,
        )
    )
    inv = inv_result.scalar_one_or_none()
    if not inv:
        raise HTTPException(400, "Item not owned")

    # unequip all of this type
    await db.execute(
        update(UserInventory)
        .where(UserInventory.user_id == current_user.id,
               UserInventory.item_type == item_type)
        .values(equipped=False)
    )
    await db.flush()

    # refresh inv to get post-unequip state, then mark equipped
    await db.refresh(inv)
    inv.equipped = True

    # update Character table
    char_result = await db.execute(select(Character).where(Character.user_id == current_user.id))
    char = char_result.scalar_one_or_none()
    if char:
        if item_type == ItemType.outfit:
            char.outfit_id = item_id
        else:
            char.voice_pack_id = item_id

    await db.commit()
    return {"status": "ok"}
