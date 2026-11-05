import 'package:flutter/material.dart';

import '../../data/briefing.dart';
import '../theme.dart';
import 'shell.dart';

class MoodCard extends StatelessWidget {
  final Future<Briefing?> briefing;
  final bool stale;
  final String? mood;
  final String tone;
  final ValueChanged<String> onPick;
  const MoodCard(this.briefing, this.stale, this.mood, this.tone, this.onPick,
      {super.key});

  @override
  Widget build(BuildContext context) => CardShell('오늘 기분은요?', [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final m in kMoods)
            InkWell(
              onTap: () => onPick(m.key),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: m.key == mood ? SsokColors.selected : null,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text(m.emoji, style: const TextStyle(fontSize: 32)),
                  Text(m.label, style: const TextStyle(fontSize: 14)),
                ]),
              ),
            ),
        ]),
        if (mood != null)
          CardFuture<Briefing?>(briefing, '조언을 불러오지 못했어요', (b) {
            final t = b?.advice[mood]?[tone];
            return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(t ?? '조언을 불러오지 못했어요',
                    style: const TextStyle(fontSize: 17, height: 1.5)));
          }),
      ], stale: stale);
}
