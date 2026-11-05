import 'package:flutter/material.dart';

import '../../data/geo.dart';
import '../../data/server_api.dart';
import 'shell.dart';

typedef WeatherRows = List<(String, Weather)>;

/// 현재 위치가 집·회사 10km 안이면 집·회사만, 아니면 내 위치부터
List<(String, Place)> weatherTargets({Place? here, Place? home, Place? work}) {
  bool near(Place? p) =>
      here != null &&
      p != null &&
      distanceKm(here.lat, here.lon, p.lat, p.lon) <= 10 + 1e-9; // 부동소수 오차
  return [
    if (here != null && !near(home) && !near(work)) ('내 위치', here),
    if (home != null) ('집', home),
    if (work != null) ('회사', work),
  ];
}

/// 날씨를 한 번에 — 하나라도 실패하면 카드 전체가 실패 문구.
/// 위치는 이미 얻을 수 있을 때만 쓴다(권한 요청 없음).
Future<WeatherRows> loadWeather(ServerApi api, Place? home, Place? work,
    [Future<(double, double)?>? loc]) async {
  (double, double)? h;
  try {
    h = await loc;
  } catch (_) {}
  final t = weatherTargets(
      here: h == null ? null : Place('내 위치', '', h.$1, h.$2), home: home, work: work);
  return Future.wait([
    for (final e in t) api.weather(e.$2.lat, e.$2.lon).then((w) => (e.$1, w)),
  ]);
}

class WeatherCard extends StatelessWidget {
  final Future<WeatherRows>? future; // null = 날씨 없음
  final bool needPlaces; // 집·회사 미등록 안내
  const WeatherCard(this.future, {this.needPlaces = false, super.key});

  @override
  Widget build(BuildContext context) => CardShell('날씨', [
        if (future != null)
          CardFuture<WeatherRows>(
              future!,
              '날씨를 불러오지 못했어요',
              (l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final (name, w) in l)
                      bodyText('$name ${w.tempC.round()}° ${w.sky}'
                          '${w.rain == '없음' ? '' : ' · ${w.rain}'}'
                          ' · 강수확률 ${w.popMax.round()}%'),
                  ])),
        if (needPlaces) bodyText(kNeedPlaces),
      ]);
}
