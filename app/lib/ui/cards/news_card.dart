import 'package:flutter/material.dart';

import '../../data/briefing.dart';
import 'shell.dart';

class NewsCard extends StatelessWidget {
  final Future<Briefing?> briefing;
  final bool stale;
  final List<String> topics;
  final ShareText share;
  const NewsCard(this.briefing, this.stale, this.topics,
      {this.share = shareText, super.key});

  @override
  Widget build(BuildContext context) => CardShell('관심 뉴스', [
        CardFuture<Briefing?>(briefing, '뉴스를 불러오지 못했어요', (b) {
          if (b == null) return bodyText('뉴스를 불러오지 못했어요');
          return Column(children: [
            for (final t in kTopics.where(topics.contains))
              ExpansionTile(
                title: Text(t,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                tilePadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  if ((b.news[t] ?? []).isEmpty) bodyText('오늘은 소식이 없어요'),
                  for (final n in b.news[t] ?? [])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(n.title, style: const TextStyle(fontSize: 17)),
                      onTap: () =>
                          showDetail(context, n.title, n.summary, [('원문 보기', n.url)],
                              share: share),
                    ),
                ],
              ),
          ]);
        }),
      ], stale: stale);
}

class CommunityCard extends StatelessWidget {
  final Future<Briefing?> briefing;
  final bool stale;
  final List<String> selected;
  final ShareText share;
  const CommunityCard(this.briefing, this.stale, this.selected,
      {this.share = shareText, super.key});

  @override
  Widget build(BuildContext context) => CardShell('커뮤니티', [
        if (kCommunities.every((c) => !selected.contains(c.key)))
          bodyText('설정에서 볼 커뮤니티를 골라 주세요')
        else
          CardFuture<Briefing?>(briefing, '글을 불러오지 못했어요', (b) {
            if (b == null) return bodyText('글을 불러오지 못했어요');
            return Column(children: [
              for (final c in kCommunities.where((c) => selected.contains(c.key)))
                _section(context, c, b.community[c.key] ?? const []),
            ]);
          }),
      ], stale: stale);

  Widget _section(BuildContext context, Community c, List<CommunityItem> items) =>
      ExpansionTile(
        title: Text(items.isEmpty ? c.label : '${c.label} (${items.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        tilePadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          if (items.isEmpty) bodyText('오늘은 소식이 없어요'),
          for (final g in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(g.title, style: const TextStyle(fontSize: 17)),
              subtitle: g.points == null
                  ? null
                  : Text(c.pointsLabel == '점'
                      ? '${g.points}점'
                      : '${c.pointsLabel} ${g.points}'),
              onTap: () => showDetail(context, g.title, g.summary, [
                ('원문 보기', g.url),
                if (g.discussUrl != null) ('토론 보기', g.discussUrl!),
              ], share: share),
            ),
        ],
      );
}
