from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.database import get_db
from app.models import Outfit, VoicePack, UserInventory, ItemType, User
from app.api.deps import get_current_user
from app.schemas.shop import ShopOutfitItem, ShopVoiceItem, PurchaseRequest

router = APIRouter(prefix="/api/shop", tags=["shop"])


@router.get("/outfits")
async def list_shop_outfits(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShopOutfitItem]:
    outfits_result = await db.execute(select(Outfit).order_by(Outfit.price))
    outfits = outfits_result.scalars().all()

    inventory_result = await db.execute(
        select(UserInventory.item_id).where(
            UserInventory.user_id == current_user.id,
            UserInventory.item_type == ItemType.outfit,
        )
    )
    owned_ids = {row[0] for row in inventory_result.all()}

    return [
        ShopOutfitItem(
            id=str(o.id), name=o.name, model_file=o.model_file,
            thumbnail=o.thumbnail, price=float(o.price),
            owned=o.id in owned_ids,
        )
        for o in outfits
    ]


@router.get("/voices")
async def list_shop_voices(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[ShopVoiceItem]:
    voices_result = await db.execute(select(VoicePack).order_by(VoicePack.price))
    voices = voices_result.scalars().all()

    inventory_result = await db.execute(
        select(UserInventory.item_id).where(
            UserInventory.user_id == current_user.id,
            UserInventory.item_type == ItemType.voice_pack,
        )
    )
    owned_ids = {row[0] for row in inventory_result.all()}

    return [
        ShopVoiceItem(
            id=str(v.id), name=v.name, type=v.type,
            price=float(v.price), preview_url=v.preview_url,
            owned=v.id in owned_ids,
        )
        for v in voices
    ]


@router.post("/purchase")
async def purchase_item(
    req: PurchaseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    item_type = ItemType(req.item_type)
    item_uuid = UUID(req.item_id)

    # Verify the item exists in the catalog
    if item_type == ItemType.outfit:
        item_result = await db.execute(select(Outfit).where(Outfit.id == item_uuid))
    else:
        item_result = await db.execute(select(VoicePack).where(VoicePack.id == item_uuid))

    if not item_result.scalar_one_or_none():
        raise HTTPException(404, "Item not found")

    # Check not already owned
    inv_result = await db.execute(
        select(UserInventory).where(
            UserInventory.user_id == current_user.id,
            UserInventory.item_type == item_type,
            UserInventory.item_id == item_uuid,
        )
    )
    if inv_result.scalar_one_or_none():
        raise HTTPException(400, "Item already owned")

    inv = UserInventory(
        user_id=current_user.id,
        item_type=item_type,
        item_id=item_uuid,
    )
    db.add(inv)
    await db.commit()
    return {"status": "purchased"}
