import 'package:flutter/material.dart';

import '../../data/server_api.dart';
import 'shell.dart';

typedef WeatherRows = List<(String, Weather)>;

/// 집·회사 날씨를 한 번에 — 하나라도 실패하면 카드 전체가 실패 문구
Future<WeatherRows> loadWeather(ServerApi api, Place? home, Place? work) =>
    Future.wait([
      for (final e in [('집', home), ('회사', work)])
        if (e.$2 != null)
          api.weather(e.$2!.lat, e.$2!.lon).then((w) => (e.$1, w)),
    ]);

class WeatherCard extends StatelessWidget {
  final Future<WeatherRows>? future; // null = 집·회사 미등록
  const WeatherCard(this.future, {super.key});

  @override
  Widget build(BuildContext context) => CardShell('날씨', [
        if (future == null)
          bodyText(kNeedPlaces)
        else
          CardFuture<WeatherRows>(
              future!,
              '날씨를 불러오지 못했어요',
              (l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final (name, w) in l)
                      bodyText('$name ${w.tempC.round()}° ${w.sky}'
                          '${w.rain == '없음' ? '' : ' · ${w.rain}'}'
                          ' · 강수확률 ${w.popMax.round()}%'),
                  ])),
      ]);
}
