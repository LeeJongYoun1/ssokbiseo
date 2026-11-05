import 'package:flutter/material.dart';

import '../../data/calendar.dart';
import '../theme.dart';
import 'shell.dart';

// tz 설정과 무관하게 기기 로컬 시각으로 표시
String _hm(Event e) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    e.start!.millisecondsSinceEpoch,
  );
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

bool _allDay(Event e) => e.allDay == true || e.start == null;

/// 흰 타일 — 다음 일정. 누르면 오늘 일정 전체.
class ScheduleTile extends StatelessWidget {
  final Future<List<Event>?> future;
  final VoidCallback onAllow;
  final DateTime Function() now;
  const ScheduleTile(
    this.future,
    this.onAllow, {
    this.now = DateTime.now,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(Widget body, [VoidCallback? onTap]) => Tile(
      color: SsokColors.card,
      side: const BorderSide(color: SsokColors.border),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다음 일정',
            style: TextStyle(fontSize: 13, color: SsokColors.inkSub),
          ),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
    return FutureBuilder<List<Event>?>(
      future: future,
      builder: (_, s) {
        if (s.hasError) return tile(const Text('일정을 불러오지 못했어요'));
        if (s.connectionState != ConnectionState.done) {
          return tile(const Center(child: CircularProgressIndicator()));
        }
        final l = s.data;
        if (l == null) return tile(const Text(kNeedPermission), onAllow);
        if (l.isEmpty) {
          return tile(
            const Text(
              '오늘 일정 없음',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          );
        }
        // 아직 안 지난 시간 일정 중 가장 빠른 것, 없으면 맨 앞(하루 종일)
        final next = l.firstWhere(
          (e) => !_allDay(e) && !e.start!.isBefore(now()),
          orElse: () => l.first,
        );
        return tile(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _allDay(next) ? '하루 종일' : _hm(next),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${next.title ?? ''}${l.length > 1 ? ' 외 ${l.length - 1}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          () => _showAll(context, l),
        );
      },
    );
  }
}

void _showAll(BuildContext context, List<Event> l) => showModalBottomSheet(
  context: context,
  backgroundColor: SsokColors.cream,
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘 일정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final e in l)
            bodyText(
              _allDay(e)
                  ? '하루 종일  ${e.title ?? ''}'
                  : '${_hm(e)}  ${e.title ?? ''}',
            ),
        ],
      ),
    ),
  ),
);
