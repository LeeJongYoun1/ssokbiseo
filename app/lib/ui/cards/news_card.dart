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
  final ShareText share;
  const CommunityCard(this.briefing, this.stale, {this.share = shareText, super.key});

  @override
  Widget build(BuildContext context) => CardShell('커뮤니티', [
        CardFuture<Briefing?>(briefing, '글을 불러오지 못했어요', (b) {
          if (b == null) return bodyText('글을 불러오지 못했어요');
          // 다른 커뮤니티는 이 목록에 (이름, 글 목록)만 더하면 된다.
          final sections = [('GeekNews', b.geeknews)];
          return Column(children: [
            for (final (label, items) in sections)
              ExpansionTile(
                title: Text(items.isEmpty ? label : '$label (${items.length})',
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
                      subtitle: Text('${g.points}점'),
                      onTap: () => showDetail(context, g.title, g.summary,
                          [('원문 보기', g.url), ('토론 보기', g.discussUrl)],
                          share: share),
                    ),
                ],
              ),
          ]);
        }),
      ], stale: stale);
}
