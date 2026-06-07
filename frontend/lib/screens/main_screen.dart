import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/conversation_provider.dart';
import '../providers/character_provider.dart';
import '../widgets/sci_fi_bg.dart';
import 'conversation_list_screen.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';

// ── Palette ──
const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ConversationListScreen(),
    DiscoverScreen(),
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
    return Stack(
      children: [
        const SciFiBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: _bottomNav(),
        ),
      ],
    );
  }

  Widget _bottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _accent.withValues(alpha: 0.15), width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: _surface.withValues(alpha: 0.95),
        selectedItemColor: _accent,
        unselectedItemColor: _textDim.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}