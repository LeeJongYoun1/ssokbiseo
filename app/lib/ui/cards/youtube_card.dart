import 'package:flutter/material.dart';

import '../../data/youtube.dart';
import '../theme.dart';
import 'shell.dart';

String agoText(DateTime p, DateTime now) {
  final d = now.difference(p);
  return d.inHours >= 1 ? '${d.inHours}시간 전' : '${d.inMinutes < 1 ? 1 : d.inMinutes}분 전';
}

class YoutubeCard extends StatelessWidget {
  final Future<ChannelVideos?>? videos; // null이면 채널 없음
  final DateTime Function() now;
  final Future<bool> Function(String) open;
  const YoutubeCard(this.videos, {this.now = DateTime.now, this.open = openExternal, super.key});

  @override
  Widget build(BuildContext context) => CardShell('유튜브 새 영상', [
        if (videos == null)
          bodyText('설정에서 유튜브 채널을 추가해 주세요')
        else
          CardFuture<ChannelVideos?>(videos!, '영상을 불러오지 못했어요', (r) {
            if (r == null) return bodyText('영상을 불러오지 못했어요');
            if (r.isEmpty) return bodyText('지난 하루 새 영상이 없어요');
            return Column(children: [
              for (final (ch, vs) in r)
                ExpansionTile(
                  title: Text('${ch.name} (${vs.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  tilePadding: EdgeInsets.zero,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    for (final v in vs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(v.title, style: const TextStyle(fontSize: 17)),
                        subtitle: Text(agoText(v.published, now()),
                            style: const TextStyle(fontSize: 15, color: SsokColors.inkSub)),
                        onTap: () => open(v.url),
                      ),
                  ],
                ),
            ]);
          }),
      ]);
}
