import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'briefing.dart';
import 'briefing_repo.dart';
import '../ui/cards/weather_card.dart' show slotHours;
import 'server_api.dart';

const _delay = Duration(milliseconds: 300);

/// 키·서버 없이 쓰는 예시 응답.
class DemoServerApi extends ServerApi {
  final DateTime Function() _now;
  DemoServerApi({DateTime Function()? now})
      : _now = now ?? DateTime.now,
        super(http.Client());

  @override
  Future<Weather> weather(double lat, double lon) async {
    await Future<void>.delayed(_delay);
    final d = (lat * 10).round() % 3; // 집·회사가 조금 다르게 보이도록
    const skies = ['맑음', '맑음', '구름많음', '흐림', '흐림', '맑음'];
    final hours = slotHours(_now());
    return Weather(12 + d, '맑음', '없음', 10, 6 + d, 17 + d, [
      for (var i = 0; i < 6; i++)
        HourWeather(hours[i], 12 + d + (i < 3 ? i : 5 - i) - 1, skies[i],
            i == 3 ? '비' : '없음', i == 3 ? 70 : 10 + i * 5),
    ]);
  }

  @override
  Future<List<Place>> geocode(String q) async {
    await Future<void>.delayed(_delay);
    if (q.trim().isEmpty) return [];
    return [
      Place('$q (예시)', '경기 성남시 분당구 판교역로 (예시)', 37.3948, 127.1112),
      Place('$q 2호점 (예시)', '경기 성남시 분당구 정자일로 (예시)', 37.3670, 127.1080),
      Place('$q 3호점 (예시)', '경기 성남시 수정구 위례광장로 (예시)', 37.4700, 127.1400),
    ];
  }

  @override
  Future<RouteTime> route(Place from, Place to) async {
    await Future<void>.delayed(_delay);
    return const RouteTime(25, 42, false);
  }
}

/// 번들된 예시 브리핑. 예시이므로 stale 아님.
class DemoBriefingRepo extends BriefingRepo {
  DemoBriefingRepo(super.c, super.p);

  @override
  Future<BriefingResult> load() async => BriefingResult(
    Briefing.fromJson(
      jsonDecode(await rootBundle.loadString('assets/demo/briefing.json'))
          as Map<String, dynamic>,
    ),
    false,
  );
}
