class CharacterConfig {
  final String id;
  final String name;
  final String live2dModel;
  final String? outfitId;
  final String? voicePackId;
  final String? outfitName;
  final String? voicePackName;

  const CharacterConfig({
    required this.id,
    required this.name,
    required this.live2dModel,
    this.outfitId,
    this.voicePackId,
    this.outfitName,
    this.voicePackName,
  });

  factory CharacterConfig.fromJson(Map<String, dynamic> json) => CharacterConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    live2dModel: json['live2d_model'] as String,
    outfitId: json['outfit_id'] as String?,
    voicePackId: json['voice_pack_id'] as String?,
    outfitName: json['outfit_name'] as String?,
    voicePackName: json['voice_pack_name'] as String?,
  );
}
