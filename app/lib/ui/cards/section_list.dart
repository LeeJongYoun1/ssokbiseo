import 'package:flutter/material.dart';

import '../../data/briefing.dart';
import '../../data/settings.dart';
import '../../data/youtube.dart';
import '../theme.dart';
import 'news_card.dart';
import 'youtube_card.dart';

/// 맨 아래 목록 — 한 줄이 한 구역이고, 누르면 그 줄 아래로 펼쳐진다.
class SectionList extends StatelessWidget {
  final Future<Briefing?> briefing;
  final Future<ChannelVideos?>? videos; // null = 채널 없음
  final Settings settings;
  final Future<bool> Function(String) open;
  const SectionList(
    this.briefing,
    this.videos,
    this.settings, {
    required this.open,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final topics = kTopics.where(s.topics.contains).toList();
    final tax = kTaxSources.where((c) => s.taxSources.contains(c.key)).toList();
    final com = kCommunities
        .where((c) => s.communities.contains(c.key))
        .toList();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: SsokColors.ink, width: 2)),
      ),
      child: Column(
        children: [
          if (topics.isNotEmpty)
            _Row<Briefing?>(
              '관심 뉴스',
              briefing,
              (b) =>
                  '${topics.join(' · ')}${_n(b == null ? null : topics.fold<int>(0, (a, t) => a + (b.news[t]?.length ?? 0)), sep: '  ')}',
              NewsCard(briefing, s.topics),
            ),
          if (tax.isNotEmpty)
            _Row<Briefing?>(
              '세무 소식',
              briefing,
              // 다른 줄처럼 이름 · 이름  합계 — 한 줄에 들어가게 '국세청 '은 뺀다
              (b) =>
                  '${tax.map((c) => c.label.replaceFirst('국세청 ', '')).join(' · ')}${_n(b == null ? null : tax.fold<int>(0, (a, c) => a + (b.tax[c.key]?.length ?? 0)), sep: '  ')}',
              TaxCard(briefing, s.taxSources),
            ),
          if (videos != null)
            _Row<ChannelVideos?>(
              '유튜브 새 영상',
              videos!,
              (r) => _n(r?.fold<int>(0, (a, e) => a + e.$2.length)).trim(),
              YoutubeCard(videos!, open: open),
            ),
          if (com.isNotEmpty)
            _Row<Briefing?>(
              '커뮤니티',
              briefing,
              (b) =>
                  '${com.map((c) => c.label).join(' · ')}${_n(b == null ? null : com.fold<int>(0, (a, c) => a + (b.community[c.key]?.length ?? 0)), sep: '  ')}',
              CommunityCard(briefing, s.communities),
            ),
        ],
      ),
    );
  }
}

String _n(int? n, {String sep = ''}) => n == null ? '' : '$sep$n개';

class _Row<T> extends StatefulWidget {
  final String label;
  final Future<T> future;
  final String Function(T?) summary;
  final Widget body;
  const _Row(this.label, this.future, this.summary, this.body);

  @override
  State<_Row<T>> createState() => _RowState<T>();
}

// 화면을 넘기지 않고 줄 바로 아래에 펼친다
class _RowState<T> extends State<_Row<T>> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: SsokColors.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<T>(
                    future: widget.future,
                    builder: (_, s) => Text(
                      widget.summary(s.hasData ? s.data : null),
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SsokColors.inkSub,
                      ),
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: SsokColors.inkSub,
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 4, 12),
            child: widget.body,
          ),
      ],
    ),
  );
}
