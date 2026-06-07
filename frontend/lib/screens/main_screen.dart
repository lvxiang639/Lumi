import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/character_provider.dart';
import '../providers/discover_provider.dart';
import 'conversation_list_screen.dart';
import 'tools/tools_center_screen.dart';
import 'discover_screen.dart';
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Consumer<DiscoverProvider>(
        builder: (ctx, discover, _) {
          final badge = discover.unreadCount;
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              setState(() => _currentIndex = i);
              if (i == 2) discover.markAllRead();
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: '聊天',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.apps_outlined),
                activeIcon: Icon(Icons.apps),
                label: '工具',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge', style: const TextStyle(fontSize: 10)),
                  child: Icon(_currentIndex == 2 ? Icons.explore : Icons.explore_outlined),
                ),
                activeIcon: Badge(
                  isLabelVisible: badge > 0,
                  label: Text('$badge', style: const TextStyle(fontSize: 10)),
                  child: const Icon(Icons.explore),
                ),
                label: '发现',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '我',
              ),
            ],
          );
        },
      ),
    );
  }
}
