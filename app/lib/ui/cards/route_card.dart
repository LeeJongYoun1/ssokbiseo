import 'package:flutter/material.dart';

import '../../data/location.dart';
import '../../data/server_api.dart';
import '../theme.dart';
import 'shell.dart';

typedef Leg = (String, Place, Place, RouteTime);

/// 위치를 못 얻으면 null(권한 없음)
Future<List<Leg>?> loadRoutes(
  ServerApi api,
  LocationSource loc,
  Place? home,
  Place? work,
) async {
  final here = await loc.current();
  if (here == null) {
    if (!await loc.serviceOn()) throw const GpsOff();
    return null;
  }
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

/// 어두운 가로 띠 — 회사(없으면 집)까지 걸리는 시간. 누르면 카카오맵.
class RouteTile extends StatelessWidget {
  final Future<List<Leg>?>? future; // null = 집·회사 미등록
  final VoidCallback onAllow;
  const RouteTile(this.future, this.onAllow, {super.key});

  static const _sub = TextStyle(fontSize: 13, color: Color(0xCCFFFBEA));

  @override
  Widget build(BuildContext context) {
    Widget tile(Widget child, [VoidCallback? onTap]) => Tile(
      color: SsokColors.ink,
      onTap: onTap,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: SsokColors.cream, fontSize: 14),
        child: child,
      ),
    );
    Widget ask(String t) => tile(Text(t), onAllow);
    if (future == null) return tile(const Text(kNeedPlaces));
    return FutureBuilder<List<Leg>?>(
      future: future,
      builder: (_, s) {
        if (s.hasError) {
          return s.error is GpsOff
              ? ask(kNeedGps)
              : tile(const Text('시간을 불러오지 못했어요'));
        }
        if (s.connectionState != ConnectionState.done) {
          return tile(const Center(child: CircularProgressIndicator()));
        }
        final l = s.data;
        if (l == null || l.isEmpty) return ask(kNeedPermission);
        final main = l.firstWhere((e) => e.$1 == '회사', orElse: () => l.first);
        return tile(
          _legs(l, main),
          () => openKakao(main.$2, main.$3, 'PUBTRANS'),
        );
      },
    );
  }

  // 가로 띠: 왼쪽 행선지·수단, 오른쪽 큰 분
  Widget _legs(List<Leg> l, Leg main) {
    final other = l.where((e) => e != main).firstOrNull;
    final (name, _, _, r) = main;
    final transit = r.transitBlocked ? null : r.transitMin;
    final big = transit ?? r.carMin;
    final otherMin = other == null
        ? null
        : (other.$4.transitBlocked ? null : other.$4.transitMin) ??
              other.$4.carMin;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$name까지 · ${transit == null ? '차 기준' : '버스·지하철'}',
                style: const TextStyle(fontSize: 14),
              ),
              if (transit == null) const Text('카카오맵에서 보기', style: _sub),
              if (otherMin != null)
                Text('${other!.$1} $otherMin분', style: _sub),
            ],
          ),
        ),
        if (big != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$big',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                const TextSpan(text: '분', style: TextStyle(fontSize: 15)),
                if (transit != null && r.carMin != null)
                  TextSpan(text: '  차 ${r.carMin}분', style: _sub),
              ],
            ),
          ),
      ],
    );
  }
}
