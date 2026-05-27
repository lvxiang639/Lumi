import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../models/calendar_event.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('日历提醒')),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : provider.events.isEmpty
                  ? const Center(child: Text('暂无提醒事件', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: provider.events.length,
                      itemBuilder: (context, i) {
                        final event = provider.events[i];
                        return ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(event.title),
                          subtitle: Text('${event.time.year}/${event.time.month}/${event.time.day} ${event.time.hour}:${event.time.minute.toString().padLeft(2, '0')}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => provider.deleteEvent(event.id),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加提醒'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: '事件标题'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final event = CalendarEvent(
                id: '', title: title, time: DateTime.now().add(const Duration(hours: 1)),
                createdAt: DateTime.now(), updatedAt: DateTime.now(),
              );
              context.read<CalendarProvider>().createEvent(event);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
