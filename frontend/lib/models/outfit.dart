class Outfit {
  final String id;
  final String name;
  final String modelFile;
  final String thumbnail;
  final double price;
  final bool equipped;
  final bool owned;

  const Outfit({
    required this.id, required this.name, required this.modelFile,
    this.thumbnail = '', this.price = 0, this.equipped = false, this.owned = false,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) => Outfit(
    id: json['id'] as String,
    name: json['name'] as String,
    modelFile: json['model_file'] as String? ?? '',
    thumbnail: json['thumbnail'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    equipped: json['equipped'] as bool? ?? false,
    owned: json['owned'] as bool? ?? false,
  );
}
