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
    final brightness = Theme.of(context).brightness;
    final titleCtrl = TextEditingController();
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
                    borderSide: BorderSide(color: AppColors.border(brightness))),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent)),
              )),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消', style: TextStyle(color: AppColors.textSecondary(brightness)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, {'title': titleCtrl.text}),
              child: const Text('添加', style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
    if (result != null && (result['title'] as String).isNotEmpty) {
      await context.read<CalendarProvider>().createEvent(CalendarEvent(
        id: '', title: result['title'], time: DateTime.now(),
        repeatRule: 'none', notified: false,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      ));
    }
  }

  Future<void> _delete(String id) async {
    await context.read<CalendarProvider>().deleteEvent(id);
  }

  String _fmtTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(dt.year, dt.month, dt.day);
    final diff = eventDay.difference(today).inDays;
    final timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return '今天 $timeStr';
    if (diff == 1) return '明天 $timeStr';
    if (diff == -1) return '昨天 $timeStr';
    return '${dt.month}/${dt.day} $timeStr';
  }

  String _repeatLabel(String rule) {
    switch (rule) {
      case 'daily': return '每天';
      case 'weekly': return '每周';
      case 'monthly': return '每月';
      case 'yearly': return '每年';
      default: return '';
    }
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
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: Consumer<CalendarProvider>(
        builder: (ctx, prov, _) {
          if (prov.loading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (prov.events.isEmpty) {
            return _emptyState(brightness);
          }
          // Sort by time ascending
          final events = List<CalendarEvent>.from(prov.events)
            ..sort((a, b) => a.time.compareTo(b.time));

          final upcoming = events.where((e) => e.time.isAfter(DateTime.now())).toList();
          final past = events.where((e) => !e.time.isAfter(DateTime.now())).toList();

          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.card(brightness),
            onRefresh: () => prov.loadEvents(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              children: [
                _statsHeader(brightness, events, upcoming),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('即将到来', brightness),
                  const SizedBox(height: 8),
                  ...upcoming.map((e) => _eventCard(e, true, brightness)),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('已过期', brightness),
                  const SizedBox(height: 8),
                  ...past.map((e) => _eventCard(e, false, brightness)),
                ],
              ],
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

  Widget _sectionTitle(String title, Brightness b) {
    return Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: AppColors.textSecondary(b),
              fontSize: 13, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _statsHeader(Brightness b, List<CalendarEvent> all,
      List<CalendarEvent> upcoming) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF59E0B).withValues(alpha: 0.08),
                   const Color(0xFFF59E0B).withValues(alpha: 0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('日程总览',
                  style: TextStyle(color: AppColors.textSecondary(b), fontSize: 12)),
              const SizedBox(height: 4),
              Text('${all.length} 个日程',
                  style: TextStyle(color: AppColors.text(b), fontSize: 22, fontWeight: FontWeight.w700)),
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('下一个: ${_fmtTime(upcoming.first.time)}',
                    style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 12)),
              ],
            ],
          ),
        ),
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.calendar_month, color: Color(0xFFF59E0B), size: 24),
        ),
      ]),
    );
  }

  Widget _eventCard(CalendarEvent e, bool upcoming, Brightness b) {
    final isToday = DateTime(e.time.year, e.time.month, e.time.day) ==
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final accentColor = isToday ? Colors.red : AppColors.accent;

    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.red)),
      onDismissed: (_) => _delete(e.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card(b),
          borderRadius: BorderRadius.circular(12),
          border: isToday
              ? Border.all(color: Colors.red.withValues(alpha: 0.2))
              : null,
        ),
        child: Row(children: [
          // Time indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('${e.time.day}',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 18, fontWeight: FontWeight.w700)),
                Text('${e.time.month}月',
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(e.title,
                        style: TextStyle(
                            color: AppColors.text(b),
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                      child: const Text('今天',
                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(_fmtTime(e.time),
                    style: TextStyle(
                        color: AppColors.textSecondary(b).withValues(alpha: 0.7),
                        fontSize: 12)),
                if (e.repeatRule != 'none') ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.repeat, size: 12,
                        color: AppColors.textSecondary(b).withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(_repeatLabel(e.repeatRule),
                        style: TextStyle(
                            color: AppColors.textSecondary(b).withValues(alpha: 0.5),
                            fontSize: 11)),
                  ]),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right,
              color: AppColors.textSecondary(b).withValues(alpha: 0.2), size: 18),
        ]),
      ),
    );
  }

  Widget _emptyState(Brightness b) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_month_outlined,
            size: 56, color: AppColors.textSecondary(b).withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Text('还没有日程',
            style: TextStyle(color: AppColors.textSecondary(b), fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('添加日程'),
        ),
      ]),
    );
  }
}
