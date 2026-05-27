from pydantic import BaseModel


class ShopOutfitItem(BaseModel):
    id: str
    name: str
    model_file: str
    thumbnail: str
    price: float
    owned: bool


class ShopVoiceItem(BaseModel):
    id: str
    name: str
    type: str
    price: float
    preview_url: str
    owned: bool


class PurchaseRequest(BaseModel):
    item_type: str  # "outfit" or "voice_pack"
    item_id: str
