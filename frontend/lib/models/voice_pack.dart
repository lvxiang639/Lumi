class VoicePack {
  final String id;
  final String name;
  final String type;
  final String cosyvoiceId;
  final double price;
  final String previewUrl;
  final bool equipped;
  final bool owned;

  const VoicePack({
    required this.id, required this.name, required this.type,
    required this.cosyvoiceId, this.price = 0, this.previewUrl = '',
    this.equipped = false, this.owned = false,
  });

  factory VoicePack.fromJson(Map<String, dynamic> json) => VoicePack(
    id: json['id'] as String,
    name: json['name'] as String,
    type: json['type'] as String,
    cosyvoiceId: json['cosyvoice_id'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    previewUrl: json['preview_url'] as String? ?? '',
    equipped: json['equipped'] as bool? ?? false,
    owned: json['owned'] as bool? ?? false,
  );
}
