import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';

const _surface = Color(0xFF0F1229);
const _accent = Color(0xFF818CF8);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _border = Color(0x1AFFFFFF);

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
    });
  }

  Future<void> _add() async {
    final titleCtrl = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        title: const Text('新建日程', style: TextStyle(color: _textMain)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, autofocus: true,
            style: const TextStyle(color: _textMain),
            decoration: const InputDecoration(
              hintText: '日程标题', hintStyle: TextStyle(color: _textDim),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消', style: TextStyle(color: _textDim))),
          TextButton(onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text}),
            child: const Text('添加', style: TextStyle(color: _accent))),
        ],
      ),
    );
    if (result != null && (result['title'] as String).isNotEmpty) {
      await context.read<CalendarProvider>().createEvent(
        CalendarEvent(id: '', title: result['title'], time: DateTime.now(), repeatRule: 'none', notified: false,
          createdAt: DateTime.now(), updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> _delete(String id) async {
    await context.read<CalendarProvider>().deleteEvent(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(44), child: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _textDim, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('日历', style: TextStyle(color: _textMain, fontSize: 16, fontWeight: FontWeight.w600)),
      )),
      body: Consumer<CalendarProvider>(
        builder: (ctx, prov, _) {
          if (prov.loading) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          if (prov.events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 48, color: _textDim.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('还没有日程', style: TextStyle(color: _textDim)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: _accent, backgroundColor: _surface,
            onRefresh: () => prov.loadEvents(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: prov.events.length,
              itemBuilder: (ctx, i) {
                final e = prov.events[i];
                final timeStr = '${e.time.month}/${e.time.day} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.red)),
                  onDismissed: (_) => _delete(e.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_accent.withValues(alpha: 0.08), _accent.withValues(alpha: 0.02)],
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withValues(alpha: 0.12)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(timeStr, style: const TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Text(e.title, style: const TextStyle(color: _textMain, fontSize: 14)),
                      if (e.repeatRule != 'none') ...[
                        const SizedBox(width: 6),
                        Text('🔄', style: const TextStyle(fontSize: 12)),
                      ],
                    ]),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: _accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}