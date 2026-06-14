import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';

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
    setState(() => _loading = true);
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('购买成功 🎉'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('购买失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.bg(b),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textSecondary(b)), onPressed: () => Navigator.pop(context)),
        title: Text('商店', style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: () => _loadShop(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _sectionTitle('服装', b),
                  const SizedBox(height: 8),
                  if (_outfits.isEmpty) _emptyHint('暂无服装商品', b)
                  else ..._outfits.map((o) => _itemCard(o, 'outfit', b)),
                  const SizedBox(height: 20),
                  _sectionTitle('声音包', b),
                  const SizedBox(height: 8),
                  if (_voices.isEmpty) _emptyHint('暂无声音包商品', b)
                  else ..._voices.map((v) => _itemCard(v, 'voice_pack', b)),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, Brightness b) {
    return Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 15, fontWeight: FontWeight.w600));
  }

  Widget _emptyHint(String text, Brightness b) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.card(b), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(text, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13))),
    );
  }

  Widget _itemCard(Map<String, dynamic> item, String itemType, Brightness b) {
    final owned = item['owned'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: (itemType == 'outfit' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6)).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            itemType == 'outfit' ? Icons.checkroom : Icons.music_note,
            color: itemType == 'outfit' ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['name'] as String? ?? '', style: TextStyle(color: AppColors.text(b), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text('¥${item['price'] ?? 0}${item['type'] != null ? ' · ${item['type']}' : ''}', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
        ])),
        owned
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('已拥有', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
              )
            : ElevatedButton(
                onPressed: () => _purchase(itemType, item['id'] as String),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: const Text('购买', style: TextStyle(fontSize: 12)),
              ),
      ]),
    );
  }
}
