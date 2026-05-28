from typing import Literal
from pydantic import BaseModel, Field


class CharacterConfig(BaseModel):
    id: str
    name: str
    live2d_model: str
    outfit_id: str | None
    voice_pack_id: str | None
    outfit_name: str | None
    voice_pack_name: str | None


class InitCharacterRequest(BaseModel):
    name: str = Field(max_length=50)


class UpdateCharacterRequest(BaseModel):
    name: str | None = Field(None, max_length=50)


class EquipRequest(BaseModel):
    item_type: Literal["outfit", "voice_pack"]
    item_id: str


class OutfitItem(BaseModel):
    model_config = {"protected_namespaces": ()}

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
