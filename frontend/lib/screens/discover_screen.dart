import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/calendar_provider.dart';

// ── Palette ──
const _accent = Color(0xFF818CF8);
const _accentWarm = Color(0xFFF0ABFC);
const _textMain = Color(0xFFE2E8F0);
const _textDim = Color(0xFF94A3B8);
const _glass = Color(0x1AFFFFFF);
const _border = Color(0x1AFFFFFF);

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CalendarProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _appBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _weatherCard(),
          const SizedBox(height: 10),
          _calendarCard(),
          const SizedBox(height: 20),
          _sectionTitle('今日动态'),
          const SizedBox(height: 10),
          _aiPostCard(
            icon: '💡',
            title: '灵犀小记',
            content: '今天天气不错，适合出去走走 🌸\n记得带水哦~',
            time: '刚刚',
          ),
          const SizedBox(height: 8),
          _aiPostCard(
            icon: '🌟',
            title: '每日一句',
            content: '"生活中最重要的不是你拥有什么，\n而是你体验了什么。"',
            time: '1小时前',
          ),
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
        title: const Text('发现',
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

  Widget _weatherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_accent.withValues(alpha: 0.12), _accent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('☀️', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('北京 晴 25°', style: const TextStyle(color: _textMain, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('6月6日 周六', style: TextStyle(color: _textDim.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
          const Spacer(),
          Icon(Icons.wb_sunny, color: _accent.withValues(alpha: 0.4), size: 28),
        ],
      ),
    );
  }

  Widget _calendarCard() {
    return Consumer<CalendarProvider>(
      builder: (ctx, prov, _) {
        final now = DateTime.now();
        final todayEvents = prov.events.where((e) =>
          e.time.year == now.year && e.time.month == now.month && e.time.day == now.day
        ).toList();
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: Text('📅', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日日程', style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  if (todayEvents.isEmpty)
                    Text('暂无安排', style: TextStyle(color: _textDim.withValues(alpha: 0.6), fontSize: 11))
                  else
                    ...todayEvents.take(3).map((e) => Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text('${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')} ${e.title}',
                        style: TextStyle(color: _textDim, fontSize: 11)),
                    )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _aiPostCard({
    required String icon,
    required String title,
    required String content,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _glass,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_accent, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: _textMain, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(time, style: TextStyle(color: _textDim.withValues(alpha: 0.4), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(color: _textDim, fontSize: 12, height: 1.6)),
        ],
      ),
    );
  }
}