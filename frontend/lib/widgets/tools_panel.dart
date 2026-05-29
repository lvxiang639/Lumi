import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/expense_provider.dart';

class ToolsPanel extends StatefulWidget {
  const ToolsPanel({super.key});

  @override
  State<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends State<ToolsPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
      context.read<ExpenseProvider>().load();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const Text('助手工具',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: Colors.indigo,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: '📅 日历'),
                Tab(text: '💰 记账'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _CalendarTab(),
                  _ExpenseTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CalendarProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.events.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 80),
              Center(
                  child: Text('暂无提醒事件',
                      style: TextStyle(color: Colors.grey))),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.events.length,
          itemBuilder: (context, i) {
            final event = provider.events[i];
            final dt = event.time;
            return ListTile(
              leading: const Icon(Icons.event, color: Colors.indigo),
              title: Text(event.title),
              subtitle: Text(
                  '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => provider.deleteEvent(event.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpenseTab extends StatelessWidget {
  const _ExpenseTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        if (provider.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        final totalExpense =
            (provider.stats?['total_expense'] as num?)?.toDouble() ?? 0.0;
        if (provider.records.isEmpty) {
          return ListView(
            children: [
              const SizedBox(height: 80),
              const Center(
                  child: Text('暂无记账记录',
                      style: TextStyle(color: Colors.grey))),
              if (totalExpense > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: Text('本月支出: ¥${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.indigo)),
                  ),
                ),
            ],
          );
        }
        return ListView.builder(
          itemCount: provider.records.length,
          itemBuilder: (context, i) {
            final record = provider.records[i];
            final isExpense = record.amount > 0;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isExpense
                    ? Colors.red.shade100
                    : Colors.green.shade100,
                child: Text(record.category,
                    style: const TextStyle(fontSize: 12)),
              ),
              title: Text(
                  record.remark.isEmpty ? record.category : record.remark),
              subtitle: Text(_fmtDt(record.recordedAt)),
              trailing: Text(
                '${isExpense ? "-" : "+"}¥${record.amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  color: isExpense ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onLongPress: () => provider.delete(record.id),
            );
          },
        );
      },
    );
  }

  static String _fmtDt(DateTime dt) {
    final s = dt.toString();
    return s.length >= 16 ? s.substring(0, 16) : s;
  }
}
