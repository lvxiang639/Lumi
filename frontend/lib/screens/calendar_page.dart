import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';
import '../theme/app_colors.dart';

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
    final brightness = Theme.of(context).brightness;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(brightness),
        title: Text('新建日程',
            style: TextStyle(color: AppColors.text(brightness))),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: titleCtrl,
              autofocus: true,
              style: TextStyle(color: AppColors.text(brightness)),
              decoration: InputDecoration(
                hintText: '日程标题',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary(brightness)),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: AppColors.border(brightness))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.accent)),
              )),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消',
                  style: TextStyle(
                      color:
                          AppColors.textSecondary(brightness)))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, {'title': titleCtrl.text}),
              child: const Text('添加',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (result != null && (result['title'] as String).isNotEmpty) {
      await context.read<CalendarProvider>().createEvent(CalendarEvent(
        id: '',
        title: result['title'],
        time: DateTime.now(),
        repeatRule: 'none',
        notified: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _delete(String id) async {
    await context.read<CalendarProvider>().deleteEvent(id);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.bg(brightness),
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.textSecondary(brightness)),
            onPressed: () => Navigator.pop(context)),
        title: Text('日历',
            style: TextStyle(
                color: AppColors.text(brightness),
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: Consumer<CalendarProvider>(
        builder: (ctx, prov, _) {
          if (prov.loading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: AppColors.accent));
          }
          if (prov.events.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 48,
                      color: AppColors.textSecondary(brightness)
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text('还没有日程',
                      style: TextStyle(
                          color:
                              AppColors.textSecondary(brightness))),
                ],
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card(brightness),
            onRefresh: () => prov.loadEvents(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: prov.events.length,
              itemBuilder: (ctx, i) {
                final e = prov.events[i];
                final timeStr =
                    '${e.time.month}/${e.time.day} ${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}';
                return Dismissible(
                  key: ValueKey(e.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete,
                          color: Colors.red)),
                  onDismissed: (_) => _delete(e.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card(brightness),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(timeStr,
                            style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Text(e.title,
                          style: TextStyle(
                              color: AppColors.text(brightness),
                              fontSize: 14)),
                      if (e.repeatRule != 'none') ...[
                        const SizedBox(width: 6),
                        const Text('🔄',
                            style: TextStyle(fontSize: 12)),
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
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
