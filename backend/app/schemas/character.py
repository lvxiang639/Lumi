from pydantic import BaseModel


class CharacterConfig(BaseModel):
    id: str
    name: str
    live2d_model: str
    outfit_id: str | None
    voice_pack_id: str | None
    outfit_name: str | None
    voice_pack_name: str | None


class InitCharacterRequest(BaseModel):
    name: str


class UpdateCharacterRequest(BaseModel):
    name: str | None = None


class EquipRequest(BaseModel):
    item_type: str  # "outfit" or "voice_pack"
    item_id: str


class OutfitItem(BaseModel):
    id: str
    name: str
    model_file: str
    thumbnail: str
    price: float
    equipped: bool
    owned: bool


class VoicePackItem(BaseModel):
    id: str
    name: str
    type: str
    cosyvoice_id: str
    price: float
    preview_url: str
    equipped: bool
    owned: bool
