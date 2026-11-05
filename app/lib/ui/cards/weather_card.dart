import 'package:flutter/material.dart';

import '../../data/geo.dart';
import '../../data/server_api.dart';
import '../theme.dart';
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

/// 지금 KST 시각 다음의 3의 배수 시각부터 3시간 간격 6칸
List<int> slotHours(DateTime now) {
  final h = now.toUtc().add(const Duration(hours: 9)).hour;
  return [for (var i = 1; i <= 6; i++) ((h ~/ 3) + i) * 3 % 24];
}

IconData weatherIcon(String sky, String rain, int hour) {
  if (rain == '소나기') return Icons.umbrella_outlined;
  if (rain == '비') return Icons.water_drop_outlined;
  if (rain != '없음') return Icons.ac_unit; // 눈, 비/눈
  final night = hour >= 21 || hour <= 5;
  if (sky == '흐림') return Icons.cloud_outlined;
  if (sky == '구름많음') return night ? Icons.cloud_outlined : Icons.filter_drama_outlined;
  return night ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined;
}

class _HourStrip extends StatelessWidget {
  final List<HourWeather> hourly;
  const _HourStrip(this.hourly);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(children: [
          for (final h in hourly)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(children: [
                  Text('${h.hour}시', style: const TextStyle(fontSize: 15)),
                  Icon(weatherIcon(h.sky, h.rain, h.hour),
                      size: 24, color: SsokColors.inkSub),
                  Text('${h.tempC.round()}°', style: const TextStyle(fontSize: 15)),
                  Text('${h.pop.round()}%', style: const TextStyle(fontSize: 13)),
                ]),
              ),
            ),
        ]),
      );
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
                    for (final (i, (name, w)) in l.indexed) ...[
                      if (i > 0)
                        const Divider(height: 20, color: SsokColors.border),
                      Align(alignment: Alignment.centerLeft, child: PlaceChip(name)),
                      const SizedBox(height: 4),
                      bodyText('${w.tempC.round()}° ${w.sky}'
                          '${w.rain == '없음' ? '' : ' · ${w.rain}'}'
                          ' · 강수확률 ${w.popMax.round()}%'),
                      if (w.hourly.isNotEmpty) _HourStrip(w.hourly),
                    ],
                  ])),
        if (needPlaces) bodyText(kNeedPlaces),
      ]);
}
