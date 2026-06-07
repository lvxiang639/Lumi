import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import 'expense_page.dart';
import 'notes_page.dart';
import 'email_page.dart';
import 'file_page.dart';
import 'mood_page.dart';
import 'summary_page.dart';
import 'calendar_page.dart';

// ── Palette ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _userCard(),
          const SizedBox(height: 20),
          _sectionTitle('助手'),
          const SizedBox(height: 10),
          _toolItem(Icons.email_outlined, '邮件记录', const Color(0xFF3B82F6), _onEmailSummary),
          _toolItem(Icons.note_alt_outlined, '笔记', const Color(0xFF10B981), _onNotes),
          _toolItem(Icons.summarize_outlined, '提炼摘要', const Color(0xFF8B5CF6), _onSummary),
          _toolItem(Icons.account_balance_wallet_outlined, '记账', const Color(0xFFF59E0B), _onExpense),
          _toolItem(Icons.mood_outlined, '心情记录', const Color(0xFFEC4899), _onMood),
          _toolItem(Icons.calendar_month_outlined, '日历', const Color(0xFFF59E0B), _onCalendar),
          _toolItem(Icons.insert_drive_file_outlined, '文件转换', const Color(0xFF14B8A6), _onFile),
          _toolItem(Icons.palette_outlined, '角色管理', const Color(0xFF6366F1), _onCharacter),
          const SizedBox(height: 20),
          _logoutButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(44),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('我的',
          style: TextStyle(color: _textMain, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Container(width: 3, height: 14,
            decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: _textDim, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _userCard() {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) {
        final phone = auth.user?.phone ?? '';
        final masked = phone.length >= 7 ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}' : phone;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent.withValues(alpha: 0.10), _accent.withValues(alpha: 0.03)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(auth.user?.nickname.isNotEmpty == true ? auth.user!.nickname : '用户', style: const TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(masked, style: TextStyle(color: _textDim.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _toolItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: _glass,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(color: _textMain, fontSize: 14)),
                const Spacer(),
                Icon(Icons.chevron_right, color: _textDim.withValues(alpha: 0.3), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return Center(
      child: TextButton(
        onPressed: () async {
          await context.read<AuthProvider>().logout();
        },
        child: Text('退出登录', style: TextStyle(color: _textDim.withValues(alpha: 0.5), fontSize: 13)),
      ),
    );
  }

  // ── Tool actions ──

  void _onEmailSummary() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmailPage()));
  }

  void _onNotes() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotesPage()));
  }

  void _onSummary() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryPage()));
  }

  void _onExpense() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpensePage()));
  }

  void _onMood() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MoodPage()));
  }

  void _onCalendar() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarPage()));
  }

  void _onFile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FilePage()));
  }

  void _onCharacter() {
    _showCharacterSheet(context);
  }

  void _showCharacterSheet(BuildContext ctx) {
    final prov = ctx.read<CharacterProvider>();
    prov.loadConfig();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildCharacterSheet(ctx, prov),
    );
  }

  Widget _buildCharacterSheet(BuildContext ctx, CharacterProvider prov) {
    final cfg = prov.config;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 32, height: 3, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)))),
            const Center(child: Text('角色管理', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            if (prov.loading)
              const Center(child: CircularProgressIndicator(color: _accent))
            else if (cfg == null)
              Center(child: Column(children: [
                const Text('未初始化角色', style: TextStyle(color: _textDim)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => prov.initCharacter('小灵').then((_) { if (ctx.mounted) Navigator.pop(ctx); }),
                  style: ElevatedButton.styleFrom(backgroundColor: _accent),
                  child: const Text('初始化'),
                ),
              ]))
            else ...[
              Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.person, color: Colors.white, size: 24)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cfg.name, style: const TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text('${cfg.outfitName ?? "默认"} · ${cfg.voicePackName ?? "默认"}', style: const TextStyle(color: _textDim, fontSize: 11)),
                ]),
              ]),
              const SizedBox(height: 20),
              Text('服装', style: TextStyle(color: _accentWarm, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.outfits.map((o) => _charItem(o['name'] as String, o['equipped'] == true, () => prov.equip('outfit', o['id'] as String))),
              const SizedBox(height: 12),
              Text('声音', style: TextStyle(color: _accentWarm, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.voices.map((v) => _charItem(v['name'] as String, v['equipped'] == true, () => prov.equip('voice_pack', v['id'] as String), sub: v['type'] as String?)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _charItem(String name, bool active, VoidCallback onTap, {String? sub}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: active ? _accent.withValues(alpha: 0.1) : _glass, borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: Text(name, style: const TextStyle(color: _textMain, fontSize: 13)),
        subtitle: sub != null ? Text(sub, style: const TextStyle(color: _textDim, fontSize: 11)) : null,
        dense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        trailing: active
            ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 14, color: _accent), SizedBox(width: 4), Text('使用中', style: TextStyle(fontSize: 11, color: _accent))])
            : TextButton(onPressed: onTap, style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: const Text('使用', style: TextStyle(fontSize: 11, color: _accentWarm))),
      ),
    );
  }
}