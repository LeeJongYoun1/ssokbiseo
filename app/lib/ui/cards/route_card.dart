import 'package:flutter/material.dart';

import '../../data/location.dart';
import '../../data/server_api.dart';
import 'schedule_card.dart' show PermissionPrompt;
import 'shell.dart';

typedef Leg = (String, Place, Place, RouteTime);

/// 위치를 못 얻으면 null(권한 없음)
Future<List<Leg>?> loadRoutes(
    ServerApi api, LocationSource loc, Place? home, Place? work) async {
  final here = await loc.current();
  if (here == null) return null;
  final from = Place('현재 위치', '', here.$1, here.$2);
  return Future.wait([
    for (final e in [('집', home), ('회사', work)])
      if (e.$2 != null)
        api.route(from, e.$2!).then<Leg>((r) => (e.$1, from, e.$2!, r)),
  ]);
}

String kakaoApp(Place a, Place b, String by) =>
    'kakaomap://route?sp=${a.lat},${a.lon}&ep=${b.lat},${b.lon}&by=$by';
String kakaoWeb(Place b) =>
    'https://map.kakao.com/link/to/${Uri.encodeComponent(b.name)},${b.lat},${b.lon}';

Future<void> openKakao(Place a, Place b, String by) async {
  if (!await openExternal(kakaoApp(a, b, by))) await openExternal(kakaoWeb(b));
}

class RouteCard extends StatelessWidget {
  final Future<List<Leg>?>? future; // null = 집·회사 미등록
  final VoidCallback onAllow;
  const RouteCard(this.future, this.onAllow, {super.key});

  @override
  Widget build(BuildContext context) => CardShell('걸리는 시간', [
        if (future == null)
          bodyText(kNeedPlaces)
        else
          CardFuture<List<Leg>?>(future!, '시간을 불러오지 못했어요', (l) {
            if (l == null) return PermissionPrompt(onAllow);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (name, from, to, r) in l)
                Row(children: [
                  Expanded(
                      child: bodyText('$name까지  '
                          '🚗 ${r.carMin == null ? '-' : '${r.carMin}분'} · '
                          '🚌 ${r.transitMin == null ? '' : '${r.transitMin}분'}')),
                  if (r.transitMin == null)
                    TextButton(
                        onPressed: () => openKakao(from, to, 'PUBTRANS'),
                        child: const Text('카카오맵에서 보기')),
                ]),
            ]);
          }),
      ]);
}
