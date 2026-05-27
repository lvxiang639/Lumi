import 'package:flutter/foundation.dart';
import '../models/character_config.dart';
import '../services/api_client.dart';

class CharacterProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  CharacterConfig? _config;
  List<Map<String, dynamic>> _outfits = [];
  List<Map<String, dynamic>> _voices = [];
  bool _loading = false;

  CharacterConfig? get config => _config;
  List<Map<String, dynamic>> get outfits => _outfits;
  List<Map<String, dynamic>> get voices => _voices;
  bool get loading => _loading;

  Future<void> initCharacter(String name) async {
    final data = await _api.post('/api/characters/init', body: {'name': name});
    _config = CharacterConfig.fromJson(data);
    notifyListeners();
  }

  Future<void> loadConfig() async {
    _loading = true;
    notifyListeners();
    try {
      final configData = await _api.get('/api/characters/config');
      _config = CharacterConfig.fromJson(configData);
      final outfitsData = await _api.get('/api/characters/outfits');
      _outfits =
          (outfitsData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final voicesData = await _api.get('/api/characters/voices');
      _voices =
          (voicesData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<void> equip(String itemType, String itemId) async {
    await _api.put('/api/characters/equip',
        body: {'item_type': itemType, 'item_id': itemId});
    await loadConfig();
  }
}
