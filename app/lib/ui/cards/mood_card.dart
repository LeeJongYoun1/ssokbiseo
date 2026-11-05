import 'package:flutter/material.dart';

import '../../data/briefing.dart';
import '../theme.dart';

class MoodBlock extends StatelessWidget {
  final Future<Briefing?> briefing;
  final bool stale;
  final String? mood;
  final String tone;
  final ValueChanged<String> onPick;
  const MoodBlock(
    this.briefing,
    this.stale,
    this.mood,
    this.tone,
    this.onPick, {
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            for (final (i, m) in kMoods.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: Material(
                    color: m.key == mood ? SsokColors.ink : SsokColors.selected,
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onPick(m.key),
                      child: Center(
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 14,
                            color: m.key == mood
                                ? SsokColors.cream
                                : SsokColors.ink,
                            fontWeight: m.key == mood ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      if (mood != null)
        FutureBuilder<Briefing?>(
          future: briefing,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done && !s.hasError) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final t = s.data?.advice[mood]?[tone];
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                t ?? '조언을 불러오지 못했어요',
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            );
          },
        ),
      if (stale)
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Text(
            '어제 내용이에요',
            style: TextStyle(fontSize: 13, color: SsokColors.inkSub),
          ),
        ),
    ],
  );
}
