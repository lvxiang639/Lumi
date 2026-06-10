import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/summary_page.dart';
import '../screens/privacy_screen.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(title: const Text('我')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _userCard(brightness),
          const SizedBox(height: 20),
          _sectionTitle('设置', brightness),
          const SizedBox(height: 8),
          _settingsGroup(brightness),
          const SizedBox(height: 24),
          _logoutButton(brightness),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Brightness b) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
            color: AppColors.textSecondary(b),
            fontSize: 12,
            fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _userCard(Brightness b) {
    return Consumer<AuthProvider>(
      builder: (ctx, auth, _) {
        final phone = auth.user?.phone ?? '';
        final masked = phone.length >= 7
            ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}'
            : phone;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card(b),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                child:
                    const Text('🐱', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user?.nickname.isNotEmpty == true
                          ? auth.user!.nickname
                          : '小灵',
                      style: TextStyle(
                          color: AppColors.text(b),
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(masked,
                        style: TextStyle(
                            color: AppColors.textSecondary(b),
                            fontSize: 13)),
                  ],
                ),
              ),
              _themeChip(b),
            ],
          ),
        );
      },
    );
  }

  Widget _themeChip(Brightness b) {
    final themeProvider = context.watch<ThemeProvider>();
    return PopupMenuButton<ThemeMode>(
      onSelected: (m) => themeProvider.setMode(m),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : themeProvider.themeMode == ThemeMode.light
                      ? Icons.light_mode
                      : Icons.auto_mode,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              themeProvider.themeMode == ThemeMode.dark
                  ? '深色'
                  : themeProvider.themeMode == ThemeMode.light
                      ? '浅色'
                      : '自动',
              style:
                  TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
            value: ThemeMode.light, child: Text('浅色模式')),
        const PopupMenuItem(
            value: ThemeMode.dark, child: Text('深色模式')),
        const PopupMenuItem(
            value: ThemeMode.system, child: Text('跟随系统')),
      ],
    );
  }

  Widget _settingsGroup(Brightness b) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              _settingItem(Icons.auto_awesome, '角色管理', b,
                  () => _showCharacterSheet()),
              _divider(b),
              _settingItem(Icons.psychology_outlined, 'AI 人格', b,
                  () => _showPersonaSheet()),
              _divider(b),
              _settingItem(Icons.email_outlined, '邮箱设置', b, () {
                _showEmailDialog();
              }),
              _divider(b),
              _settingItem(Icons.summarize_outlined, '对话摘要列表', b, () {
                _showSummaryList();
              }),
              _divider(b),
              _settingItem(Icons.info_outline, '关于灵犀', b, () {
                _showAboutDialog();
              }),
              _divider(b),
              _settingItem(Icons.privacy_tip_outlined, '隐私政策', b, () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingItem(
      IconData icon, String title, Brightness b, VoidCallback onTap) {
    return ListTile(
      leading:
          Icon(icon, color: AppColors.textSecondary(b), size: 22),
      title: Text(title,
          style:
              TextStyle(color: AppColors.text(b), fontSize: 15)),
      trailing: Icon(Icons.chevron_right,
          color: AppColors.textSecondary(b).withValues(alpha: 0.3),
          size: 20),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _divider(Brightness b) {
    return Divider(
        height: 1, indent: 56, color: AppColors.border(b));
  }

  Widget _logoutButton(Brightness b) {
    return Center(
      child: TextButton(
        onPressed: () async {
          await context.read<AuthProvider>().logout();
        },
        child: Text('退出登录',
            style: TextStyle(
                color: AppColors.textSecondary(b)
                    .withValues(alpha: 0.5),
                fontSize: 14)),
      ),
    );
  }

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邮箱设置'),
        content: const Text('请前往"设置"页面完善邮箱信息，用于接收对话摘要邮件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showSummaryList() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SummaryPage()),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于灵犀'),
        content: const Text('灵犀 — 你的 AI 陪伴伙伴\n\n版本 2.0\n\n基于大语言模型技术，提供智能对话、日程管理、记账、笔记等贴心功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  void _showPersonaSheet() {
    final brightness = Theme.of(context).brightness;
    final personas = [
      {'name': '默认', 'desc': '贴心的AI助手灵犀', 'icon': '🐱'},
      {'name': '温柔姐姐', 'desc': '轻声细语的温暖大姐姐', 'icon': '🌸'},
      {'name': '毒舌损友', 'desc': '犀利吐槽但真心为你', 'icon': '😏'},
      {'name': '学霸老师', 'desc': '博学耐心，冷知识达人', 'icon': '📚'},
      {'name': '二次元', 'desc': '萌系元气娘，喵~的说', 'icon': '🎀'},
      {'name': '小猫', 'desc': '猫视角看世界，喵~', 'icon': '🐈'},
    ];
    // Load current persona from auth provider
    String selected = '默认';
    final auth = context.read<AuthProvider>();
    // Try to read from user data if available
    selected = '默认'; // default fallback
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card(brightness),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.border(brightness), borderRadius: BorderRadius.circular(2))),
              const Text('选择 AI 人格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...personas.map((p) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: selected == p['name'] ? AppColors.accent.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected == p['name'] ? Border.all(color: AppColors.accent.withValues(alpha: 0.3)) : null,
                ),
                child: ListTile(
                  leading: Text(p['icon']!, style: const TextStyle(fontSize: 24)),
                  title: Text(p['name']!, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(p['desc']!, style: const TextStyle(fontSize: 12)),
                  trailing: selected == p['name']
                      ? const Icon(Icons.check_circle, color: AppColors.accent, size: 20)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    setSheetState(() => selected = p['name']!);
                    final prov = context.read<AuthProvider>();
                    prov.updateProfile(persona: p['name']);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已切换为: ${p['name']}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating));
                  },
                ),
              )),
            const SizedBox(height: 8),
          ])),
        ),
      ),
    );
  }

  void _showCharacterSheet() {
    final prov = context.read<CharacterProvider>();
    prov.loadConfig();
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          _buildCharacterSheet(ctx, prov, brightness),
    );
  }

  Widget _buildCharacterSheet(
      BuildContext ctx, CharacterProvider prov, Brightness b) {
    final cfg = prov.config;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border(b),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text('角色管理',
                  style: TextStyle(
                      color: AppColors.text(b),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            if (prov.loading)
              const Center(child: CircularProgressIndicator())
            else if (cfg == null)
              Center(
                child: ElevatedButton(
                  onPressed: () => prov.initCharacter('小灵').then((_) {
                        if (ctx.mounted) Navigator.pop(ctx);
                      }),
                  child: const Text('初始化角色'),
                ),
              )
            else ...[
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor:
                      AppColors.accent.withValues(alpha: 0.1),
                  child: const Text('🐱',
                      style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Text(cfg.name,
                    style: TextStyle(
                        color: AppColors.text(b),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 20),
              Text('服装',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.outfits.map((o) => _charItem(
                  o['name'] as String,
                  o['equipped'] == true,
                  b,
                  () => prov.equip('outfit', o['id'] as String))),
              const SizedBox(height: 12),
              Text('声音',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.voices.map((v) => _charItem(
                  v['name'] as String,
                  v['equipped'] == true,
                  b,
                  () => prov.equip(
                      'voice_pack', v['id'] as String),
                  sub: v['type'] as String?)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _charItem(String name, bool active, Brightness b,
      VoidCallback onTap,
      {String? sub}) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(name,
            style:
                TextStyle(color: AppColors.text(b), fontSize: 13)),
        subtitle: sub != null
            ? Text(sub,
                style: TextStyle(
                    color: AppColors.textSecondary(b),
                    fontSize: 11))
            : null,
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12),
        trailing: active
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle,
                    size: 14, color: AppColors.accent),
                SizedBox(width: 4),
                Text('使用中',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.accent)),
              ])
            : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12)),
                child: const Text('使用',
                    style: TextStyle(fontSize: 11)),
              ),
      ),
    );
  }
}
