import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final ApiClient _api = ApiClient();
  List<Map<String, dynamic>> _outfits = [];
  List<Map<String, dynamic>> _voices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    try {
      final outfitsData = await _api.get('/api/shop/outfits');
      _outfits = (outfitsData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final voicesData = await _api.get('/api/shop/voices');
      _voices = (voicesData['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _purchase(String itemType, String itemId) async {
    try {
      await _api.post('/api/shop/purchase', body: {'item_type': itemType, 'item_id': itemId});
      await _loadShop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('购买失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('商店')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text('服装', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                ..._outfits.map((o) => ListTile(
                  leading: const Icon(Icons.checkroom),
                  title: Text(o['name'] as String? ?? ''),
                  subtitle: Text('¥${o['price'] ?? 0}'),
                  trailing: o['owned'] == true
                      ? const Chip(label: Text('已拥有'))
                      : ElevatedButton(onPressed: () => _purchase('outfit', o['id'] as String), child: const Text('购买')),
                )),
                const Divider(),
                const Padding(padding: EdgeInsets.all(16), child: Text('声音包', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                ..._voices.map((v) => ListTile(
                  leading: const Icon(Icons.music_note),
                  title: Text(v['name'] as String? ?? ''),
                  subtitle: Text('${v['type'] ?? ''} · ¥${v['price'] ?? 0}'),
                  trailing: v['owned'] == true
                      ? const Chip(label: Text('已拥有'))
                      : ElevatedButton(onPressed: () => _purchase('voice_pack', v['id'] as String), child: const Text('购买')),
                )),
              ],
            ),
    );
  }
}
