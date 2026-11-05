import 'package:biseo/data/geo.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/ui/cards/weather_card.dart';
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
}
