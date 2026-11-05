import 'package:biseo/data/geo.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/ui/cards/weather_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distanceKm', () {
    expect(distanceKm(37.5665, 126.9780, 37.4979, 127.0276), closeTo(8.8, 0.3));
    expect(distanceKm(37.5, 127, 37.5, 127), 0);
    expect(distanceKm(37.5665, 126.9780, 35.1796, 129.0756), closeTo(325, 5));
  });

  const home = Place('집', '', 37.5, 127.0);
  const work = Place('회사', '', 37.7, 127.0); // 약 22km 북쪽
  List<String> labels(List<(String, Place)> l) => [for (final e in l) e.$1];
  final near = Place('x', '', 37.55, 127.0); // 집 약 5.6km
  final nearWork = Place('x', '', 37.65, 127.0);
  final far = Place('x', '', 36.0, 127.0);

  test('weatherTargets', () {
    expect(labels(weatherTargets(here: near, home: home, work: work)), ['집', '회사']);
    expect(labels(weatherTargets(here: nearWork, home: home, work: work)), ['집', '회사']);
    expect(labels(weatherTargets(here: far, home: home, work: work)), ['내 위치', '집', '회사']);
    expect(labels(weatherTargets(here: null, home: home, work: work)), ['집', '회사']);
    expect(labels(weatherTargets(here: far)), ['내 위치']);
    expect(labels(weatherTargets(home: home)), ['집']);
  });

  test('정확히 10km는 안', () {
    // 위도 1도 = 2*pi*6371/360 km; 10km에 해당하는 도 값
    final d = 10 / (2 * 3.141592653589793 * 6371 / 360);
    final h = Place('h', '', 37.5 + d, 127.0);
    expect(distanceKm(37.5, 127, h.lat, h.lon), closeTo(10, 1e-9));
    expect(labels(weatherTargets(here: h, home: home)), ['집']);
  });

  test('slotHours: KST 10:20 -> 12,15,18,21,0,3', () {
    expect(slotHours(DateTime.utc(2026, 11, 5, 1, 20)), [12, 15, 18, 21, 0, 3]);
    expect(slotHours(DateTime.utc(2026, 11, 5, 15, 5)), [3, 6, 9, 12, 15, 18]); // KST 0:05
  });

  test('weatherIcon', () {
    expect(weatherIcon('맑음', '비', 12), Icons.water_drop_outlined);
    expect(weatherIcon('맑음', '눈', 12), Icons.ac_unit);
    expect(weatherIcon('맑음', '비/눈', 12), Icons.ac_unit);
    expect(weatherIcon('흐림', '소나기', 12), Icons.umbrella_outlined);
    expect(weatherIcon('맑음', '없음', 12), Icons.wb_sunny_outlined);
    expect(weatherIcon('맑음', '없음', 0), Icons.nights_stay_outlined);
    expect(weatherIcon('구름많음', '없음', 15), Icons.filter_drama_outlined);
    expect(weatherIcon('흐림', '없음', 15), Icons.cloud_outlined);
  });

  testWidgets('시간대 칸 6개, 가로 스크롤 없음', (t) async {
    final w = Weather(12, '맑음', '없음', 10, 5, 15, [
      for (var i = 0; i < 6; i++) HourWeather(i * 3, 20 + i, '맑음', '없음', 20),
    ]);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: WeatherTile(Future.value([('집', w)])))));
    await t.pump();
    for (var i = 0; i < 6; i++) {
      expect(find.text('${i * 3}시'), findsOneWidget);
      expect(find.text('${20 + i}°'), findsOneWidget);
    }
    expect(find.descendant(of: find.byType(WeatherTile), matching: find.byType(Scrollable)),
        findsNothing);
  });
}
