import 'package:flutter/material.dart';

import '../../data/calendar.dart';
import 'shell.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class PermissionPrompt extends StatelessWidget {
  final VoidCallback onAllow;
  const PermissionPrompt(this.onAllow, {super.key});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: bodyText(kNeedPermission)),
        FilledButton(onPressed: onAllow, child: const Text('허용')),
      ]);
}

class ScheduleCard extends StatelessWidget {
  final Future<List<Event>?> future;
  final VoidCallback onAllow;
  const ScheduleCard(this.future, this.onAllow, {super.key});

  @override
  Widget build(BuildContext context) => CardShell('오늘 일정', [
        CardFuture<List<Event>?>(future, '일정을 불러오지 못했어요', (l) {
          if (l == null) return PermissionPrompt(onAllow);
          if (l.isEmpty) return bodyText('오늘은 일정이 없어요');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final e in l)
              bodyText(e.allDay == true || e.start == null
                  ? '하루 종일  ${e.title ?? ''}'
                  // tz 설정과 무관하게 기기 로컬 시각으로 표시
                  : '${_hm(DateTime.fromMillisecondsSinceEpoch(e.start!.millisecondsSinceEpoch))}  ${e.title ?? ''}'),
          ]);
        }),
      ]);
}
