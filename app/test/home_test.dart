import 'dart:convert';
import 'dart:io';

import 'package:biseo/data/briefing_repo.dart';
import 'package:biseo/data/calendar.dart';
import 'package:biseo/data/location.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/data/settings.dart';
import 'package:biseo/ui/home_page.dart';
import 'package:biseo/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCal extends CalendarSource {
  final List<Event>? v;
  FakeCal(this.v);
  @override
  Future<List<Event>?> today() async => v;
}

class FakeLoc extends LocationSource {
  final (double, double)? v;
  final bool gps;
  FakeLoc(this.v, {this.gps = true});
  @override
  Future<bool> serviceOn() async => gps;
  @override
  Future<(double, double)?> current() async => v;
}

const home = Place('집', '서울', 37.5, 127.0);
final fixture = File('test/fixtures/briefing.json').readAsStringSync();

/// body 맵: 경로 -> 응답(null이면 실패)
MockClient server(Map<String, Object?> routes) => MockClient((r) async {
      if (r.url.host == 'raw.githubusercontent.com') {
        return http.Response.bytes(utf8.encode(routes['briefing'] as String? ?? fixture), 200);
      }
      final b = routes[r.url.path];
      if (b == null) throw http.ClientException('down');
      return http.Response.bytes(utf8.encode(jsonEncode(b)), 200);
    });

Future<void> pump(WidgetTester t,
    {Map<String, Object?> routes = const {},
    Settings? settings,
    CalendarSource? cal,
    LocationSource? loc,
    DateTime? now}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  final n = now ?? DateTime.utc(2026, 11, 5, 21); // 2026-11-06 KST
  final store = SettingsStore(p, now: () => n);
  if (settings != null) await store.save(settings);
  final c = server(routes);
  await t.pumpWidget(MaterialApp(
    home: HomePage(
      briefingRepo: BriefingRepo(c, p, now: () => n),
      api: ServerApi(c, base: 'http://x', appKey: 'k'),
      store: store,
      calendar: cal ?? FakeCal([Event('c', title: '치과 예약', allDay: true)]),
      location: loc ?? FakeLoc((37.4, 127.1)),
    ),
  ));
  await t.pumpAndSettle();
}

const work = Place('회사', '서울', 37.6, 127.0);
final wx = {'/api/weather': {'tempC': 10, 'sky': '맑음', 'rain': '없음', 'popMax': 0, 'tmin': null, 'tmax': null}};
List<String> wrows(WidgetTester t) => [
      for (final w in t.widgetList<Text>(find.textContaining('강수확률')))
        w.data!.split(' ').first
    ];

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('집·회사 미등록 -> 날씨·걸리는 시간 안내', (t) async {
    await pump(t);
    expect(find.text('설정에서 집·회사를 등록해 주세요'), findsNWidgets(2));
  });

  testWidgets('날씨 서버 실패 -> 날씨 카드만 실패, 일정·뉴스는 정상', (t) async {
    await pump(t, settings: Settings(home: home));
    expect(find.text('날씨를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('하루 종일  치과 예약'), findsOneWidget);
    expect(find.text('관심 뉴스'), findsOneWidget);
    expect(find.text('경제'), findsOneWidget);
  });

  testWidgets('일정 권한 없음 -> 안내와 허용 버튼', (t) async {
    await pump(t, cal: FakeCal(null));
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
    expect(find.text('허용'), findsOneWidget);
  });

  testWidgets('위치 권한 없음 -> 걸리는 시간 카드 안내', (t) async {
    await pump(t, settings: Settings(home: home), loc: FakeLoc(null));
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
    expect(find.text('허용'), findsOneWidget);
  });

  testWidgets('GPS 꺼짐 -> 위치(GPS)를 켜 주세요', (t) async {
    await pump(t, settings: Settings(home: home), loc: FakeLoc(null, gps: false));
    expect(find.text('위치(GPS)를 켜 주세요'), findsOneWidget);
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsNothing);
  });

  testWidgets('😴 누르면 coach 조언', (t) async {
    final advice = (jsonDecode(fixture)['advice']['tired']['coach']) as String;
    await pump(t, settings: Settings(tone: 'coach'));
    await t.tap(find.text('😴'));
    await t.pumpAndSettle();
    expect(find.text(advice), findsOneWidget);
  });

  testWidgets('transitMin null -> 카카오맵에서 보기', (t) async {
    await pump(t,
        settings: Settings(home: home),
        routes: {
          '/api/route': {'carMin': 25, 'transitMin': null, 'transitBlocked': true},
          '/api/weather': {'tempC': 10, 'sky': '맑음', 'rain': '없음', 'popMax': 0, 'tmin': null, 'tmax': null},
        });
    expect(find.text('카카오맵에서 보기'), findsOneWidget);
    expect(find.textContaining('🚗 25분'), findsOneWidget);
    expect(find.textContaining('🚌 오늘은 확인할 수 없어요'), findsOneWidget);
  });

  testWidgets('stale -> 어제 내용이에요', (t) async {
    await pump(t, now: DateTime.utc(2026, 11, 6, 21)); // 하루 뒤
    expect(find.text('어제 내용이에요'), findsWidgets);
  });

  testWidgets('톱니 -> 설정 열림 -> 저장하면 홈이 새로고침된다', (t) async {
    await pump(t); // 기본 주제: 경제, IT, 건강
    expect(find.text('건강'), findsOneWidget);
    await t.tap(find.byTooltip('설정'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    final cb = find.widgetWithText(CheckboxListTile, '건강');
    await t.ensureVisible(cb);
    await t.pumpAndSettle();
    await t.tap(cb);
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('건강'), findsNothing);
    expect(find.text('경제'), findsOneWidget);
  });

  testWidgets('집·회사에서 10km 밖 -> 내 위치, 집, 회사 순', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc((36.0, 127.0)));
    expect(wrows(t), ['내', '집', '회사']);
  });

  testWidgets('집 10km 안 -> 집, 회사만', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc((37.52, 127.0)));
    expect(wrows(t), ['집', '회사']);
  });

  testWidgets('위치 없음 -> 집, 회사만, 날씨 카드가 권한을 묻지 않음', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc(null));
    expect(wrows(t), ['집', '회사']);
    // 권한 안내는 길찾기 카드 한 곳뿐
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('집·회사 미등록 + 위치 있음 -> 내 위치와 안내', (t) async {
    await pump(t, routes: wx);
    expect(wrows(t), ['내']);
    expect(find.text('설정에서 집·회사를 등록해 주세요'), findsNWidgets(2));
  });
}
