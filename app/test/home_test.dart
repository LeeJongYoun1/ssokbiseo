import 'dart:convert';
import 'dart:io';

import 'package:biseo/data/briefing_repo.dart';
import 'package:biseo/data/calendar.dart';
import 'package:biseo/data/location.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/data/settings.dart';
import 'package:biseo/data/briefing.dart';
import 'package:biseo/ui/cards/mood_card.dart';
import 'package:biseo/ui/cards/section_list.dart';
import 'package:biseo/ui/cards/weather_card.dart';
import 'package:biseo/ui/home_page.dart';
import 'package:biseo/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
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
void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('집·회사 미등록 -> 날씨·걸리는 시간 안내', (t) async {
    await pump(t);
    expect(find.text('설정에서 집·회사를 등록해 주세요'), findsNWidgets(2));
  });

  testWidgets('날씨 서버 실패 -> 날씨 카드만 실패, 일정·뉴스는 정상', (t) async {
    await pump(t, settings: Settings(home: home));
    expect(find.text('날씨를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('하루 종일'), findsOneWidget);
    expect(find.text('치과 예약'), findsOneWidget);
    expect(find.text('관심 뉴스'), findsOneWidget);
    expect(find.textContaining('경제 · 건강 · IT'), findsOneWidget);
  });

  testWidgets('일정 권한 없음 -> 안내(누르면 허용)', (t) async {
    await pump(t, cal: FakeCal(null));
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('일정 여러 개 -> 다음 일정과 외 N, 누르면 전체 목록', (t) async {
    final d = tz.TZDateTime.from(DateTime.now().add(const Duration(hours: 1)), tz.UTC);
    final cal = FakeCal([
      Event('c', title: '회의', start: d, end: d),
      Event('c', title: '치과', allDay: true),
    ]);
    await pump(t, cal: cal);
    expect(find.text('회의 외 1'), findsOneWidget);
    await t.tap(find.text('회의 외 1'));
    await t.pumpAndSettle();
    expect(find.text('오늘 일정'), findsOneWidget);
    expect(find.text('하루 종일  치과'), findsOneWidget);
  });

  testWidgets('위치 권한 없음 -> 걸리는 시간 카드 안내', (t) async {
    await pump(t, settings: Settings(home: home), loc: FakeLoc(null));
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('GPS 꺼짐 -> 위치(GPS)를 켜 주세요', (t) async {
    await pump(t, settings: Settings(home: home), loc: FakeLoc(null, gps: false));
    expect(find.text('위치(GPS)를 켜 주세요'), findsOneWidget);
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsNothing);
  });

  testWidgets('피곤 누르면 coach 조언', (t) async {
    final advice = (jsonDecode(fixture)['advice']['tired']['coach']) as String;
    await pump(t, settings: Settings(tone: 'coach'));
    await t.tap(find.text('피곤'));
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
    expect(find.text('집까지'), findsOneWidget);
    expect(find.text('카카오맵에서 보기'), findsOneWidget);
    expect(find.text('25분'), findsOneWidget);
    expect(find.text('차 기준'), findsOneWidget);
  });

  testWidgets('stale -> 어제 내용이에요', (t) async {
    await pump(t, now: DateTime.utc(2026, 11, 6, 21)); // 하루 뒤
    expect(find.text('어제 내용이에요'), findsWidgets);
  });

  testWidgets('톱니 -> 설정 열림 -> 저장하면 홈이 새로고침된다', (t) async {
    await pump(t); // 기본 주제: 경제, IT, 건강
    expect(find.textContaining('건강'), findsOneWidget);
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
    expect(find.textContaining('건강'), findsNothing);
    expect(find.textContaining('경제'), findsOneWidget);
  });

  testWidgets('집·회사에서 10km 밖 -> 내 위치가 크게, 집·회사는 줄로', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc((36.0, 127.0)));
    expect(find.text('내 위치 · 맑음'), findsOneWidget);
    expect(find.text('집 10° 맑음'), findsOneWidget);
    expect(find.text('회사 10° 맑음'), findsOneWidget);
  });

  testWidgets('집 10km 안 -> 집이 크게, 회사만 줄로', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc((37.52, 127.0)));
    expect(find.text('집 · 맑음'), findsOneWidget);
    expect(find.text('회사 10° 맑음'), findsOneWidget);
    expect(find.textContaining('내 위치'), findsNothing);
  });

  testWidgets('위치 없음 -> 집, 회사만, 날씨가 권한을 묻지 않음', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc(null));
    expect(find.text('집 · 맑음'), findsOneWidget);
    expect(find.text('회사 10° 맑음'), findsOneWidget);
    // 권한 안내는 걸리는 시간 타일 한 곳뿐
    expect(find.text('권한을 허용하면 볼 수 있어요'), findsOneWidget);
  });

  testWidgets('집·회사 미등록 + 위치 있음 -> 내 위치와 안내', (t) async {
    await pump(t, routes: wx);
    expect(find.text('내 위치 · 맑음'), findsOneWidget);
    expect(find.text('설정에서 집·회사를 등록해 주세요'), findsNWidgets(2));
  });

  testWidgets('날씨 타일: 다른 곳 줄을 누르면 그 곳이 크게', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work), loc: FakeLoc(null));
    await t.tap(find.text('회사 10° 맑음'));
    await t.pumpAndSettle();
    expect(find.text('회사 · 맑음'), findsOneWidget);
    expect(find.text('집 10° 맑음'), findsOneWidget);
  });

  testWidgets('기분 버튼에 이모지가 없다', (t) async {
    await pump(t);
    final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    final texts = t
        .widgetList<Text>(find.descendant(of: find.byType(MoodBlock), matching: find.byType(Text)))
        .map((e) => e.data ?? '')
        .toList();
    expect(texts, containsAll(kMoods.map((m) => m.label)));
    expect(texts.where(emoji.hasMatch), isEmpty);
  });

  testWidgets('목록 줄을 누르면 그 구역 화면이 열린다', (t) async {
    await pump(t);
    await t.tap(find.text('관심 뉴스'));
    await t.pumpAndSettle();
    expect(find.byType(SectionPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, '관심 뉴스'), findsOneWidget);
    expect(find.text('경제'), findsOneWidget);
  });

  // 실기기 버그: 아래로 갔다가 쓸어내리면 위 카드가 새로 만들어지며 한 프레임 로딩(작은 높이)으로
  // 그려지고, 높이가 바뀌어 목록이 제자리로 밀려 올라가지 않았다.
  testWidgets('아래 끝에서 쓸어내려도 위 카드가 로딩으로 다시 그려지지 않고 맨 위까지 올라간다', (t) async {
    await pump(t, routes: wx, settings: Settings(home: home, work: work));
    await t.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await t.pumpAndSettle();
    expect(find.text('커뮤니티'), findsOneWidget);
    for (var i = 0; i < 60; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, 100), touchSlopY: 0);
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
    expect(find.text('다음 일정'), findsOneWidget);
  });

  testWidgets('맨 아래 카드가 시스템 내비게이션 바에 가리지 않는다', (t) async {
    t.view.padding = const FakeViewPadding(bottom: 144); // 3버튼 내비 바
    addTearDown(t.view.reset);
    await pump(t);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -5000));
    await t.pumpAndSettle();
    final screenH = t.view.physicalSize.height / t.view.devicePixelRatio;
    final navTop = screenH - 144 / t.view.devicePixelRatio;
    expect(t.getRect(find.text('커뮤니티')).bottom, lessThanOrEqualTo(navTop));
  });

  testWidgets('날씨 타일과 목록의 가로 폭이 같다', (t) async {
    await pump(t);
    expect(t.getSize(find.byType(WeatherTile)).width, t.getSize(find.byType(SectionList)).width);
  });
}
