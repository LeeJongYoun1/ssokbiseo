import 'package:biseo/data/briefing.dart';
import 'package:biseo/data/calendar.dart';
import 'package:biseo/data/demo.dart';
import 'package:biseo/data/location.dart';
import 'package:biseo/data/settings.dart';
import 'package:biseo/ui/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class _Cal extends CalendarSource {
  @override
  Future<List<Event>?> today() async => [];
}

class _Loc extends LocationSource {
  @override
  Future<bool> serviceOn() async => true;
  @override
  Future<(double, double)?> current() async => (37.4, 127.1);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DemoServerApi 고정값', () async {
    final a = DemoServerApi();
    final w = await a.weather(37.5, 127.0);
    expect((w.sky, w.rain, w.popMax), ('맑음', '없음', 10));
    final g = await a.geocode('판교');
    expect(g.length, 3);
    expect(g.first.name, '판교 (예시)');
    expect(await a.geocode(' '), isEmpty);
    final r = await a.route(g[0], g[1]);
    expect((r.carMin, r.transitMin, r.transitBlocked), (25, 42, false));
  });

  testWidgets('예시 브리핑 에셋 파싱, stale 아님', (t) async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final r = await DemoBriefingRepo(http.Client(), p).load();
    expect(r.briefing, isA<Briefing>());
    expect(r.stale, false);
  });

  testWidgets('demo:true 이면 배너', (t) async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    await t.pumpWidget(
      MaterialApp(
        home: HomePage(
          briefingRepo: DemoBriefingRepo(http.Client(), p),
          api: DemoServerApi(),
          store: SettingsStore(p),
          calendar: _Cal(),
          location: _Loc(),
          demo: true,
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('예시 화면이에요'), findsOneWidget);
  });
}
