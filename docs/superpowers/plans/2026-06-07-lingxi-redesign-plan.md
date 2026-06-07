# 灵犀 2.0 设计重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将灵犀 Flutter App 从暗色科幻风升级为微信/WhatsApp 风格的浅深双模式现代设计。

**Architecture:** 自底向上重构 — 先建主题系统（app_theme + theme_provider），再改 App Shell（main_screen 导航），然后逐页重写（聊天列表 → 聊天页 → 工具中心 → 个人中心 → 登录页），最后加动画和纹理细节。

**Tech Stack:** Flutter 3.x, Provider, Material 3, CustomPainter (背景纹理), 不新增第三方 UI 库

---

## File Map

### New Files
| File | Purpose |
|------|---------|
| `lib/theme/app_colors.dart` | 全局色板（浅/深） |
| `lib/theme/app_theme.dart` | Material ThemeData 定义 |
| `lib/providers/theme_provider.dart` | 主题状态 + 持久化 |
| `lib/screens/tools/tools_center_screen.dart` | 工具中心宫格页 |
| `lib/widgets/chat_bg_painter.dart` | WhatsApp 点状纹理 CustomPainter |

### Modified Files
| File | Change |
|------|--------|
| `lib/app.dart` | 注入 theme_provider，替换 theme 配置 |
| `lib/screens/main_screen.dart` | 图标式 3-tab 导航 |
| `lib/screens/conversation_list_screen.dart` | 微信式列表 + 搜索栏 + 手势 |
| `lib/screens/chat_screen.dart` | 微信式气泡 + 宠物猫移入顶栏 + 新输入栏 |
| `lib/screens/login_screen.dart` | 浅色温暖风格 |
| `lib/screens/profile_screen.dart` | 卡片式布局 + 主题切换 |
| `lib/widgets/chat_bubble.dart` | 保留已加的时间戳，样式微调 |

---

### Task 1: 全局色板 `app_colors.dart`

**Files:**
- Create: `lib/theme/app_colors.dart`

- [ ] **Step 1: 创建色板常量文件**

```dart
// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Light Mode ──
  static const lightBg = Color(0xFFF5F5F5);         // WhatsApp 浅灰
  static const lightCard = Color(0xFFFFFFFF);        // 白色卡片
  static const lightBubbleUser = Color(0xFFDCF8C6);  // 微信绿气泡（用户）
  static const lightBubbleAi = Color(0xFFFFFFFF);    // 白色气泡（AI）
  static const lightBorder = Color(0xFFE5E5EA);      // 分割线

  // ── Dark Mode ──
  static const darkBg = Color(0xFF0D1117);
  static const darkCard = Color(0xFF161B22);
  static const darkBubbleUser = Color(0xFF056B42);   // 深绿气泡（用户）
  static const darkBubbleAi = Color(0xFF1C2129);     // 深色气泡（AI）
  static const darkBorder = Color(0xFF21262D);

  // ── Shared Accent ──
  static const accent = Color(0xFF10B981);           // 主题绿
  static const accentBlue = Color(0xFF3B82F6);       // 次要蓝
  static const online = Color(0xFF22C55E);           // 在线绿点
  static const danger = Color(0xFFEF4444);           // 删除红

  // ── Text ──
  static const textLight = Color(0xFF1A1A1A);
  static const textLightSecondary = Color(0xFF8E8E93);
  static const textDark = Color(0xFFE6E6E6);
  static const textDarkSecondary = Color(0xFF8B949E);

  // ── Convenience: Theme-dependent accessors ──
  static Color bg(Brightness b) => b == Brightness.light ? lightBg : darkBg;
  static Color card(Brightness b) => b == Brightness.light ? lightCard : darkCard;
  static Color bubbleUser(Brightness b) => b == Brightness.light ? lightBubbleUser : darkBubbleUser;
  static Color bubbleAi(Brightness b) => b == Brightness.light ? lightBubbleAi : darkBubbleAi;
  static Color border(Brightness b) => b == Brightness.light ? lightBorder : darkBorder;
  static Color text(Brightness b) => b == Brightness.light ? textLight : textDark;
  static Color textSecondary(Brightness b) => b == Brightness.light ? textLightSecondary : textDarkSecondary;
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/theme/app_colors.dart
```
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/theme/app_colors.dart
git commit -m "feat: add app_colors — light/dark color tokens for 灵犀 2.0"
```

---

### Task 2: Material 主题定义 `app_theme.dart`

**Files:**
- Create: `lib/theme/app_theme.dart`

- [ ] **Step 1: 创建双模式 ThemeData**

```dart
// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      secondary: AppColors.accentBlue,
      surface: AppColors.lightCard,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.textLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBg,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textLight,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightCard,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textLightSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.lightBorder.withValues(alpha: 0.5)),
      ),
    ),
    dividerColor: AppColors.lightBorder,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentBlue,
      surface: AppColors.darkCard,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.textDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkCard,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textDarkSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.darkBorder),
      ),
    ),
    dividerColor: AppColors.darkBorder,
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/theme/app_theme.dart
```
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/theme/app_theme.dart
git commit -m "feat: add app_theme — light/dark Material ThemeData for 灵犀 2.0"
```

---

### Task 3: 主题 Provider `theme_provider.dart`

**Files:**
- Create: `lib/providers/theme_provider.dart`

- [ ] **Step 1: 创建 ThemeProvider（with ChangeNotifier + SharedPreferences 持久化）**

```dart
// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get themeMode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v != null) {
      _mode = ThemeMode.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/providers/theme_provider.dart
```
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/providers/theme_provider.dart
git commit -m "feat: add theme_provider with SharedPreferences persistence"
```

---

### Task 4: 重连 App Shell `app.dart`

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: 替换 app.dart，注入 ThemeProvider 并使用新主题**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/expense_provider.dart';
import 'providers/character_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

class LingxiApp extends StatelessWidget {
  const LingxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => ExpenseProvider()),
        ChangeNotifierProvider(create: (_) => CharacterProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '灵犀',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isAuthenticated) return const MainScreen();
                return const LoginScreen();
              },
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/app.dart
```
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/app.dart
git commit -m "feat: wire ThemeProvider into app shell with light/dark AppTheme"
```

---

### Task 5: 底部导航重构 `main_screen.dart`

**Files:**
- Modify: `lib/screens/main_screen.dart`

- [ ] **Step 1: 重写 main_screen.dart — 3 Tab 图标式导航**

完整替换文件内容：

```dart
// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/character_provider.dart';
import 'conversation_list_screen.dart';
import 'tools/tools_center_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ConversationListScreen(),
    ToolsCenterScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().load();
      context.read<CharacterProvider>().loadConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.apps_outlined),
            activeIcon: Icon(Icons.apps),
            label: '工具',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/main_screen.dart
```

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/screens/main_screen.dart
git commit -m "refactor: 3-tab icon nav — 聊天/工具/我 replacing dark sci-fi shell"
```

---

### Task 6: 聊天列表页重构 `conversation_list_screen.dart`

**Files:**
- Modify: `lib/screens/conversation_list_screen.dart`

- [ ] **Step 1: 重写 conversation_list_screen.dart — 微信式列表**

完整替换：

```dart
// lib/screens/conversation_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({super.key});

  @override
  State<ConversationListScreen> createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  Future<void> _refresh() async {
    await context.read<ConversationProvider>().load();
  }

  void _newConversation() {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    ).then((_) => _refresh());
  }

  void _openConversation(String convId) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversationId: convId)),
    ).then((_) => _refresh());
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        title: const Text('灵犀'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: AppColors.accent),
            onPressed: _newConversation,
          ),
        ],
      ),
      body: Consumer<ConversationProvider>(
        builder: (ctx, provider, _) {
          if (provider.loading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.conversations.isEmpty) {
            return _errorState(brightness);
          }
          if (provider.conversations.isEmpty) {
            return _emptyState(brightness);
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: provider.conversations.length,
              itemBuilder: (ctx, i) => _convItem(brightness, provider.conversations[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _convItem(Brightness b, dynamic conv) {
    final id = conv.id as String;
    final title = conv.title as String;
    final lastMessage = conv.lastMessage as String?;
    final updatedAt = conv.updatedAt as DateTime;
    final emoji = ['🐱','🤖','📝','💡','🎯','🌟'][id.hashCode.abs() % 6];

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accent.withValues(alpha: 0.1),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        title: Text(title,
          style: TextStyle(
            color: AppColors.text(b),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: lastMessage != null && lastMessage.isNotEmpty
          ? Text(lastMessage,
              style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
        trailing: Text(_formatRelativeTime(updatedAt),
          style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)),
        onTap: () => _openConversation(id),
        onLongPress: () => _showContextMenu(id, title),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showContextMenu(String id, String title) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('重命名'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(id, title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('删除', style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(id, title);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(String id, String currentTitle) {
    final ctrl = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名对话'),
        content: TextField(controller: ctrl, autofocus: true,
          decoration: const InputDecoration(hintText: '输入新标题')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) context.read<ConversationProvider>().rename(id, t);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String id, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除 "$title"？此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      context.read<ConversationProvider>().delete(id);
    }
  }

  Widget _emptyState(Brightness b) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textSecondary(b).withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('开始第一段对话吧', style: TextStyle(color: AppColors.textSecondary(b), fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _newConversation,
            icon: const Icon(Icons.add),
            label: const Text('新建对话'),
          ),
        ],
      ),
    );
  }

  Widget _errorState(Brightness b) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: AppColors.textSecondary(b)),
          const SizedBox(height: 12),
          Text('加载失败', style: TextStyle(color: AppColors.textSecondary(b))),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/conversation_list_screen.dart
```

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/screens/conversation_list_screen.dart
git commit -m "refactor: WeChat-style conversation list with emoji avatars, time stamps, context menu"
```

---

### Task 7: WhatsApp 背景纹理 `chat_bg_painter.dart`

**Files:**
- Create: `lib/widgets/chat_bg_painter.dart`

- [ ] **Step 1: 创建点状纹理 CustomPainter**

```dart
// lib/widgets/chat_bg_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ChatBgPainter extends CustomPainter {
  final Color dotColor;

  ChatBgPainter({required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final rng = Random(42); // fixed seed for consistent pattern
    const dotCount = 120;
    const maxRadius = 2.5;

    for (int i = 0; i < dotCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = rng.nextDouble() * maxRadius + 0.8;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ChatBgPainter oldDelegate) => oldDelegate.dotColor != dotColor;
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/widgets/chat_bg_painter.dart
```
Expected: No issues found.

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/widgets/chat_bg_painter.dart
git commit -m "feat: add WhatsApp-style dot pattern CustomPainter for chat background"
```

---

### Task 8: 聊天页重构 — 新气泡 + 输入栏 `chat_screen.dart`

**Files:**
- Modify: `lib/screens/chat_screen.dart`

- [ ] **Step 1: 完整重写 chat_screen.dart**

```dart
// lib/screens/chat_screen.dart
import 'dart:convert' show jsonDecode;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../providers/chat_provider.dart';
import '../theme/app_colors.dart';
import '../services/ws_service.dart';
import '../services/email_service.dart';
import '../services/notes_service.dart';
import '../services/conversation_service.dart';
import '../widgets/chat_bg_painter.dart';
import '../widgets/assistant_menu.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? conversationTitle;
  const ChatScreen({super.key, this.conversationId, this.conversationTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showField = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversation(
        conversationId: widget.conversationId,
      );
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    context.read<ChatProvider>().sendText(t);
    setState(() => _showField = false);
  }

  void _showAssistantMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => AssistantMenu(
        conversationId: widget.conversationId,
        onEmailSummary: _onEmailSummary,
        onNotes: _onSaveNote,
        onExtractSummary: _onExtractSummary,
      ),
    );
  }

  Future<void> _onEmailSummary() async {
    final chat = context.read<ChatProvider>();
    if (chat.conversationId == null) {
      _snack('请先发送一条消息');
      return;
    }
    chat.sendText('📧 正在处理邮件发送...');
    try {
      final svc = EmailService();
      await svc.sendEmailSummary(chat.conversationId!);
      svc.dispose();
      chat.sendText('✅ 对话总结已发送到邮箱');
    } catch (_) {
      chat.sendText('❌ 邮件发送失败');
    }
  }

  Future<void> _onSaveNote() async {
    final chat = context.read<ChatProvider>();
    if (chat.messages.isEmpty) return;
    try {
      final svc = NotesService();
      await svc.createNote({
        'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}',
        'content': chat.messages.last.content,
        'note_type': 'note',
      });
      svc.dispose();
      chat.sendText('📝 已保存为笔记');
    } catch (_) {
      chat.sendText('❌ 笔记保存失败');
    }
  }

  Future<void> _onExtractSummary() async {
    final chat = context.read<ChatProvider>();
    if (chat.conversationId == null) return;
    chat.sendText('📋 正在提炼对话摘要...');
    try {
      final svc = ConversationService();
      final summary = await svc.summarizeConversation(chat.conversationId!);
      svc.dispose();
      if (summary.isNotEmpty) {
        chat.sendText('📋 对话摘要:\n$summary');
      } else {
        chat.sendText('❌ 摘要生成失败');
      }
    } catch (_) {
      chat.sendText('❌ 摘要生成失败');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Consumer<ChatProvider>(
      builder: (ctx, chat, _) {
        final msgs = chat.messages;
        final streaming = chat.streamingText;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });

        return Scaffold(
          backgroundColor: AppColors.bg(brightness),
          appBar: _bar(chat),
          body: Stack(
            children: [
              // WhatsApp-style dot background
              Positioned.fill(
                child: CustomPaint(
                  painter: ChatBgPainter(
                    dotColor: brightness == Brightness.light
                        ? const Color(0xFFD0D0D0)
                        : const Color(0xFF30363D),
                  ),
                ),
              ),
              // Messages
              Positioned(
                top: 0, left: 0, right: 0, bottom: 64,
                child: _Msgs(
                  msgs: msgs,
                  streaming: streaming,
                  ctrl: _scrollCtrl,
                  brightness: brightness,
                  chat: chat,
                ),
              ),
              // Empty state
              if (msgs.isEmpty && streaming.isEmpty && chat.historyLoaded)
                Positioned(
                  top: 0, left: 0, right: 0, bottom: 64,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48,
                          color: AppColors.textSecondary(brightness).withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text('开始一段新对话吧', style: TextStyle(
                          color: AppColors.textSecondary(brightness).withValues(alpha: 0.5), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              // Connecting indicator
              if (chat.wsState == WsState.connecting)
                const Positioned(top: 0, left: 0, right: 0,
                  child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent)),
            ],
          ),
          // Input bar
          bottomSheet: _InputBar(
            ctrl: _textCtrl,
            showField: _showField,
            onToggle: () => setState(() => _showField = !_showField),
            onSend: _send,
            brightness: brightness,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _bar(ChatProvider chat) {
    final brightness = Theme.of(context).brightness;
    final title = widget.conversationTitle ?? '小灵';

    return AppBar(
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.text(brightness)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Pet cat avatar in nav bar (moved from chat area)
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent.withValues(alpha: 0.1),
            child: const Text('🐱', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(
                color: AppColors.text(brightness), fontSize: 15, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: chat.wsState == WsState.connected ? AppColors.online : AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    chat.wsState == WsState.connected ? '在线' : '连接中...',
                    style: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: _showAssistantMenu,
        ),
      ],
    );
  }
}

// ── Messages ──

class _Msgs extends StatelessWidget {
  final List msgs;
  final String streaming;
  final ScrollController ctrl;
  final Brightness brightness;
  final ChatProvider chat;
  const _Msgs({
    required this.msgs, required this.streaming, required this.ctrl,
    required this.brightness, required this.chat,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    if (msgDay == today) return '$hour:$minute';
    if (msgDay == today.subtract(const Duration(days: 1))) return '昨天 $hour:$minute';
    return '${dt.month}/${dt.day} $hour:$minute';
  }

  // Only show timestamp every 5+ messages apart
  bool _shouldShowTime(int index) {
    if (index == 0) return false; // iOS-style: hide for first
    return index % 5 == 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      itemCount: msgs.length + (streaming.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < msgs.length) {
          return Column(
            children: [
              if (_shouldShowTime(i) && msgs[i].createdAt != null)
                _timeStamp(msgs[i].createdAt as DateTime),
              _bubble(ctx, msgs[i]),
            ],
          );
        }
        return _streamBubble(ctx, streaming);
      },
    );
  }

  Widget _timeStamp(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _formatTime(dt),
        style: TextStyle(color: AppColors.textSecondary(brightness).withValues(alpha: 0.6), fontSize: 11),
      ),
    );
  }

  Widget _bubble(BuildContext ctx, dynamic m) {
    final isUser = m.role == 'user';
    final content = (m.content ?? '').toString();
    final createdAt = m.createdAt as DateTime?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onLongPress: () => _showMessageMenu(ctx, content),
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(ctx).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isUser
                  ? AppColors.bubbleUser(brightness)
                  : AppColors.bubbleAi(brightness),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: isUser ? null : Border.all(color: AppColors.border(brightness)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(content,
                  style: TextStyle(
                    color: AppColors.text(brightness),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(createdAt),
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness).withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _streamBubble(BuildContext ctx, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(ctx).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bubbleAi(brightness),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text,
              style: TextStyle(color: AppColors.text(brightness), fontSize: 15, height: 1.5))),
            const SizedBox(width: 6),
            const SizedBox(
              width: 16, height: 12,
              child: _TypingIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageMenu(BuildContext ctx, String content) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating));
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: const Text('保存为笔记'),
              onTap: () {
                Navigator.pop(ctx);
                _saveMessageAsNote(ctx, content);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMessageAsNote(BuildContext ctx, String content) async {
    try {
      final svc = NotesService();
      await svc.createNote({
        'title': '对话记录 ${DateTime.now().toString().substring(0, 16)}',
        'content': content,
        'note_type': 'note',
      });
      svc.dispose();
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('已保存为笔记 📝'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating));
      }
    }
  }
}

// ── Typing Indicator ──

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final delay = i * 0.2;
            final t = (_ctrl.value - delay).clamp(0.0, 1.0);
            final scale = 0.4 + 0.6 * (t < 0.5 ? t * 2 : 2 - t * 2);
            return Container(
              width: 5, height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: AppColors.textSecondary(Brightness.light).withValues(alpha: 0.4 + 0.6 * scale),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Input Bar ──

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final bool showField;
  final VoidCallback onToggle, onSend;
  final Brightness brightness;
  const _InputBar({
    required this.ctrl, required this.showField,
    required this.onToggle, required this.onSend, required this.brightness,
  });

  @override
  Widget build(BuildContext ctx) {
    final hasText = ctrl.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.card(brightness),
        border: Border(top: BorderSide(color: AppColors.border(brightness))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Voice toggle
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                showField ? Icons.keyboard : Icons.mic_none,
                color: AppColors.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36, maxHeight: 100),
              decoration: BoxDecoration(
                color: brightness == Brightness.light
                    ? Colors.white
                    : AppColors.darkCard,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border(brightness)),
              ),
              child: TextField(
                controller: ctrl,
                autofocus: showField,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => (ctx as Element).markNeedsBuild(),
                style: TextStyle(
                  color: AppColors.text(brightness),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: showField ? '输入消息...' : '语音输入',
                  hintStyle: TextStyle(color: AppColors.textSecondary(brightness), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Send / Attach button
          GestureDetector(
            onTap: hasText ? onSend : onToggle,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: hasText
                    ? AppColors.accent
                    : AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                hasText ? Icons.send_rounded : Icons.add,
                color: hasText ? Colors.white : AppColors.accent,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/chat_screen.dart
```

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/screens/chat_screen.dart
git commit -m "refactor: full chat screen rewrite — WeChat bubbles, WhatsApp bg, pet cat in nav, typing indicator"
```

---

### Task 9: 工具中心页 `tools_center_screen.dart`

**Files:**
- Create: `lib/screens/tools/tools_center_screen.dart`

- [ ] **Step 1: 创建工具中心宫格页**

```dart
// lib/screens/tools/tools_center_screen.dart
import 'package:flutter/material.dart';
import '../calendar_page.dart';
import '../expense_page.dart';
import '../notes_page.dart';
import '../mood_page.dart';
import '../email_page.dart';
import '../file_page.dart';
import '../summary_page.dart';
import '../../theme/app_colors.dart';

class ToolsCenterScreen extends StatelessWidget {
  const ToolsCenterScreen({super.key});

  static const _tools = <_Tool>[
    _Tool('日历', Icons.calendar_month, Color(0xFFF59E0B)),
    _Tool('记账', Icons.account_balance_wallet, Color(0xFF10B981)),
    _Tool('笔记', Icons.note_alt, Color(0xFF3B82F6)),
    _Tool('心情', Icons.mood, Color(0xFFEC4899)),
    _Tool('邮件', Icons.email, Color(0xFF8B5CF6)),
    _Tool('转换', Icons.swap_horiz, Color(0xFF14B8A6)),
    _Tool('搜索', Icons.search, Color(0xFF6366F1)),
    _Tool('摘要', Icons.summarize, Color(0xFFF97316)),
    _Tool('OCR', Icons.document_scanner, Color(0xFF06B6D4)),
  ];

  void _navigate(BuildContext ctx, String name) {
    Widget page;
    switch (name) {
      case '日历': page = const CalendarPage(); break;
      case '记账': page = const ExpensePage(); break;
      case '笔记': page = const NotesPage(); break;
      case '心情': page = const MoodPage(); break;
      case '邮件': page = const EmailPage(); break;
      case '转换': page = const FilePage(); break;
      case '摘要': page = const SummaryPage(); break;
      default: return;
    }
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(title: const Text('工具中心')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.88,
          ),
          itemCount: _tools.length,
          itemBuilder: (ctx, i) => _toolCard(ctx, _tools[i], brightness),
        ),
      ),
    );
  }

  Widget _toolCard(BuildContext ctx, _Tool tool, Brightness b) {
    return GestureDetector(
      onTap: () => _navigate(ctx, tool.name),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(b),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(tool.icon, color: tool.color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(tool.name,
              style: TextStyle(
                color: AppColors.text(b),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool {
  final String name;
  final IconData icon;
  final Color color;
  const _Tool(this.name, this.icon, this.color);
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/tools/tools_center_screen.dart
```

- [ ] **Step 3: 提交**

```bash
mkdir -p frontend/lib/screens/tools
git add frontend/lib/screens/tools/tools_center_screen.dart
git commit -m "feat: add tools center — 3×3 grid with colored icons replacing scattered tool items"
```

---

### Task 10: 个人中心重构 `profile_screen.dart`

**Files:**
- Modify: `lib/screens/profile_screen.dart`

- [ ] **Step 1: 重写 profile_screen.dart — 卡片式布局 + 主题切换**

```dart
// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../providers/theme_provider.dart';
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
      child: Text(title,
        style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12, fontWeight: FontWeight.w500),
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
              // Cat avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                child: const Text('🐱', style: TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.user?.nickname.isNotEmpty == true ? auth.user!.nickname : '小灵',
                      style: TextStyle(
                        color: AppColors.text(b),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(masked,
                      style: TextStyle(color: AppColors.textSecondary(b), fontSize: 13)),
                  ],
                ),
              ),
              // Theme switcher chip
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              themeProvider.themeMode == ThemeMode.dark ? Icons.dark_mode :
              themeProvider.themeMode == ThemeMode.light ? Icons.light_mode :
              Icons.auto_mode,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              themeProvider.themeMode == ThemeMode.dark ? '深色' :
              themeProvider.themeMode == ThemeMode.light ? '浅色' : '自动',
              style: TextStyle(color: AppColors.accent, fontSize: 12),
            ),
          ],
        ),
      ),
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: ThemeMode.light, child: Text('浅色模式')),
        const PopupMenuItem(value: ThemeMode.dark, child: Text('深色模式')),
        const PopupMenuItem(value: ThemeMode.system, child: Text('跟随系统')),
      ],
    );
  }

  Widget _settingsGroup(Brightness b) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(b),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _settingItem(Icons.auto_awesome, '角色管理', b, () => _showCharacterSheet()),
          _divider(b),
          _settingItem(Icons.email_outlined, '邮箱设置', b, () {}),
          _divider(b),
          _settingItem(Icons.summarize_outlined, '对话摘要', b, () {}),
          _divider(b),
          _settingItem(Icons.info_outline, '关于灵犀', b, () {}),
        ],
      ),
    );
  }

  Widget _settingItem(IconData icon, String title, Brightness b, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary(b), size: 22),
      title: Text(title, style: TextStyle(color: AppColors.text(b), fontSize: 15)),
      trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary(b).withValues(alpha: 0.3), size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _divider(Brightness b) {
    return Divider(height: 1, indent: 56, color: AppColors.border(b));
  }

  Widget _logoutButton(Brightness b) {
    return Center(
      child: TextButton(
        onPressed: () async {
          await context.read<AuthProvider>().logout();
        },
        child: Text('退出登录',
          style: TextStyle(color: AppColors.textSecondary(b).withValues(alpha: 0.5), fontSize: 14)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _buildCharacterSheet(ctx, prov, brightness),
    );
  }

  Widget _buildCharacterSheet(BuildContext ctx, CharacterProvider prov, Brightness b) {
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
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border(b),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Center(
              child: Text('角色管理',
                style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),
            if (prov.loading)
              const Center(child: CircularProgressIndicator())
            else if (cfg == null)
              Center(
                child: ElevatedButton(
                  onPressed: () => prov.initCharacter('小灵').then((_) { if (ctx.mounted) Navigator.pop(ctx); }),
                  child: const Text('初始化角色'),
                ),
              )
            else ...[
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.1),
                  child: const Text('🐱', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Text(cfg.name, style: TextStyle(color: AppColors.text(b), fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 20),
              Text('服装', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.outfits.map((o) => _charItem(o['name'] as String, o['equipped'] == true, b, () => prov.equip('outfit', o['id'] as String))),
              const SizedBox(height: 12),
              Text('声音', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...prov.voices.map((v) => _charItem(v['name'] as String, v['equipped'] == true, b, () => prov.equip('voice_pack', v['id'] as String), sub: v['type'] as String?)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _charItem(String name, bool active, Brightness b, VoidCallback onTap, {String? sub}) {
    return ListTile(
      title: Text(name, style: TextStyle(color: AppColors.text(b), fontSize: 13)),
      subtitle: sub != null ? Text(sub, style: TextStyle(color: AppColors.textSecondary(b), fontSize: 11)) : null,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      trailing: active
          ? const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.accent),
              SizedBox(width: 4),
              Text('使用中', style: TextStyle(fontSize: 11, color: AppColors.accent)),
            ])
          : TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
              child: const Text('使用', style: TextStyle(fontSize: 11)),
            ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/profile_screen.dart
```

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/screens/profile_screen.dart
git commit -m "refactor: redesigned profile — card layout, theme switcher chip, pet cat header"
```

---

### Task 11: 登录页视觉升级 `login_screen.dart`

**Files:**
- Modify: `lib/screens/login_screen.dart`

- [ ] **Step 1: 重写 login_screen.dart — 浅色温暖风**

```dart
// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/character_provider.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuth();
    });
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入正确的手机号'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final provider = context.read<AuthProvider>();
      final isNew = await provider.login(phone);
      if (!mounted) return;
      if (isNew) _showNameDialog(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showNameDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('给你的AI伴侣起个名字'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '如：小白、小灵'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              ctrl.dispose();
              await context.read<CharacterProvider>().initCharacter(name);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              // App icon
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Text('🐱', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('灵犀',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textLight)),
              const SizedBox(height: 6),
              const Text('你的 AI 陪伴伙伴',
                style: TextStyle(fontSize: 15, color: AppColors.textLightSecondary)),
              const Spacer(),
              // Phone input
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  style: const TextStyle(fontSize: 17, letterSpacing: 1.5),
                  decoration: InputDecoration(
                    hintText: '请输入手机号',
                    hintStyle: const TextStyle(color: AppColors.textLightSecondary, fontSize: 15, letterSpacing: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Login button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('登录 / 注册', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证编译**

```bash
cd frontend && flutter analyze lib/screens/login_screen.dart
```

- [ ] **Step 3: 提交**

```bash
git add frontend/lib/screens/login_screen.dart
git commit -m "refactor: warm clean login screen with cat icon, rounded card input, green accent"
```

---

### Task 12: 清理 & 最终验证

**Files:**
- Remove unused imports, check all pages compile

- [ ] **Step 1: 全量分析**

```bash
cd frontend && flutter analyze
```
Expected: No issues found (无关紧要的 info/warning 除外).

- [ ] **Step 2: 移除不再使用的文件（可选）**

检查 `discover_screen.dart` 和 `sci_fi_bg.dart` 是否仍被引用：
```bash
grep -r "discover_screen\|sci_fi_bg" frontend/lib/ --include="*.dart"
```
如果没有引用，删除它们。
```bash
git rm frontend/lib/screens/discover_screen.dart frontend/lib/widgets/sci_fi_bg.dart
```

- [ ] **Step 3: 最终提交**

```bash
git add -A
git commit -m "chore: final cleanup — remove unused discover/sci-fi files, pass flutter analyze"
```

---

## 验证方式

每个 Task 之后运行 `flutter analyze`，确保零错误。全量完成后：

```bash
# 编译检查
cd frontend && flutter analyze

# 在模拟器/真机上启动看效果
cd frontend && flutter run
```

主要验证点：
1. 浅色/深色切换正常，持久化生效
2. 3 个 tab 切换正常
3. 聊天列表加载、空状态、新建对话
4. 聊天页气泡样式正确、时间戳显示、背景纹理可见
5. 工具中心宫格 + 跳转各工具页
6. 个人中心主题切换 chip + 角色管理 sheet
7. 登录页视觉刷新

---

**Plan complete.** 合计 12 个 Task，P0 全覆盖（主题 / 导航 / 聊天 / 个人中心 / 登录），P1 覆盖（工具中心 / 时间显示 / 背景纹理 / 动画指示器），P2 部分留待后续（手势滑动 / 骨架屏）。
