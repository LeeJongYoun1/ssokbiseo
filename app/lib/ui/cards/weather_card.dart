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
Future<WeatherRows> loadWeather(
  ServerApi api,
  Place? home,
  Place? work, [
  Future<(double, double)?>? loc,
]) async {
  (double, double)? h;
  try {
    h = await loc;
  } catch (_) {}
  final t = weatherTargets(
    here: h == null ? null : Place('내 위치', '', h.$1, h.$2),
    home: home,
    work: work,
  );
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
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      children: [
        for (final h in hourly)
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text('${h.hour}시', style: const TextStyle(fontSize: 15)),
                  Icon(
                    weatherIcon(h.sky, h.rain, h.hour),
                    size: 24,
                    color: SsokColors.ink,
                  ),
                  Text(
                    '${h.tempC.round()}°',
                    style: const TextStyle(fontSize: 15),
                  ),
                  Text(
                    '${h.pop.round()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: SsokColors.inkSub,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

/// 레몬색 날씨 타일 — 한 곳을 크게, 나머지 곳은 줄로 보여 주고 누르면 바뀐다.
class WeatherTile extends StatefulWidget {
  final Future<WeatherRows>? future; // null = 날씨 없음
  final bool needPlaces; // 집·회사 미등록 안내
  const WeatherTile(this.future, {this.needPlaces = false, super.key});

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) => Tile(
    color: SsokColors.lemon,
    padding: 18,
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: SsokColors.ink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.future != null)
            CardFuture<WeatherRows>(widget.future!, '날씨를 불러오지 못했어요', _body),
          if (widget.needPlaces) bodyText(kNeedPlaces),
        ],
      ),
    ),
  );

  Widget _body(WeatherRows l) {
    if (l.isEmpty) return const SizedBox.shrink();
    final i = _sel < l.length ? _sel : 0;
    final (name, w) = l[i];
    final range = w.tmin == null || w.tmax == null
        ? null
        : '최저 ${w.tmin!.round()}° · 최고 ${w.tmax!.round()}°';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name · ${w.sky}${w.rain == '없음' ? '' : ' · ${w.rain}'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${w.tempC.round()}°',
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (range != null)
                    Text(range, style: const TextStyle(fontSize: 14)),
                  Text(
                    '비 올 확률 ${w.popMax.round()}%',
                    style: const TextStyle(fontSize: 14),
                  ),
                  for (final (j, (n, o)) in l.indexed)
                    if (j != i)
                      InkWell(
                        onTap: () => setState(() => _sel = j),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '$n ${o.tempC.round()}° ${o.sky}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
        if (w.hourly.isNotEmpty) _HourStrip(w.hourly),
      ],
    );
  }
}
