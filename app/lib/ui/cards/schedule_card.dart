import 'package:flutter/material.dart';

import '../../data/calendar.dart';
import '../theme.dart';
import 'shell.dart';

// tz 설정과 무관하게 기기 로컬 시각으로 표시
DateTime _local(DateTime d) =>
    DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch);
String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

bool _allDay(Event e) => e.allDay == true || e.start == null;

String _until(Duration d) {
  final h = d.inMinutes ~/ 60, m = d.inMinutes % 60;
  if (h == 0) return '$m분';
  return m == 0 ? '$h시간' : '$h시간 $m분';
}

/// 남은 일정 — 지금부터 시간 순 5개까지 세로 타임라인. 넘치면 '그 외 N개 더 보기'.
class ScheduleTimeline extends StatelessWidget {
  static const max = 5;
  final Future<List<Event>?> future;
  final VoidCallback onAllow;
  final DateTime Function() now;
  const ScheduleTimeline(
    this.future,
    this.onAllow, {
    this.now = DateTime.now,
    super.key,
  });

  static const _sub = TextStyle(fontSize: 13, color: SsokColors.inkSub);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Event>?>(
    future: future,
    builder: (_, s) {
      Widget wrap(List<Widget> body, [String allDay = '']) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  '남은 일정',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    allDay,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _sub,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...body,
          ],
        ),
      );
      Widget msg(String t, [VoidCallback? onTap]) => wrap([
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(t, style: const TextStyle(fontSize: 16)),
          ),
        ),
      ]);
      if (s.hasError) return msg('일정을 불러오지 못했어요');
      if (s.connectionState != ConnectionState.done) {
        return wrap([const Center(child: CircularProgressIndicator())]);
      }
      final l = s.data;
      if (l == null) return msg(kNeedPermission, onAllow);
      final t = now();
      final allDay = [
        for (final e in l)
          if (_allDay(e)) e.title ?? '',
      ];
      // 지금 진행 중이거나 아직 시작 안 한 일정, 시작 순
      final left =
          l.where((e) => !_allDay(e) && (e.end ?? e.start)!.isAfter(t)).toList()
            ..sort((a, b) => a.start!.compareTo(b.start!));
      final head = allDay.isEmpty ? '' : '하루 종일 · ${allDay.join(', ')}';
      if (left.isEmpty) {
        return wrap([
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l.isEmpty ? '오늘은 일정이 없어요' : '남은 일정이 없어요',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ], head);
      }
      final shown = left.take(max).toList();
      final gap = shown.first.start!.difference(t);
      return wrap([
        _NowRow(
          '${_hm(t)} · ${gap.isNegative ? '지금 진행 중' : '다음 일정까지 ${_until(gap)}'}',
        ),
        for (final (i, e) in shown.indexed)
          _EventRow(e, first: i == 0, last: i == shown.length - 1),
        if (left.length > max)
          InkWell(
            onTap: () => _showAll(context, l),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(76, 4, 0, 8),
              child: Text(
                '그 외 ${left.length - max}개 더 보기',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ], head);
    },
  );
}

const _timeW = 52.0, _lineW = 16.0, _gapW = 8.0;

class _NowRow extends StatelessWidget {
  final String text;
  const _NowRow(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const SizedBox(
          width: _timeW,
          child: Text(
            '지금',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: SsokColors.inkSub,
            ),
          ),
        ),
        const SizedBox(width: _gapW),
        SizedBox(
          width: _lineW,
          child: Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: SsokColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: _gapW),
        Expanded(child: Text(text, style: ScheduleTimeline._sub)),
      ],
    ),
  );
}

class _EventRow extends StatelessWidget {
  final Event e;
  final bool first, last;
  const _EventRow(this.e, {required this.first, required this.last});

  @override
  Widget build(BuildContext context) {
    final where = e.location?.trim() ?? '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _timeW,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _hm(_local(e.start!)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: _gapW),
          SizedBox(
            width: _lineW,
            child: Column(
              children: [
                Container(width: 2, height: 14, color: SsokColors.lemon),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: first ? SsokColors.lemon : SsokColors.cream,
                    shape: BoxShape.circle,
                    border: Border.all(color: SsokColors.ink, width: 2),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : SsokColors.lemon,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: _gapW),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title ?? '',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: first ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (where.isNotEmpty)
                    Text(where, style: ScheduleTimeline._sub),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showAll(BuildContext context, List<Event> l) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: SsokColors.cream,
  builder: (_) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
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
                    : '${_hm(_local(e.start!))}  ${e.title ?? ''}',
              ),
          ],
        ),
      ),
    ),
  ),
);
