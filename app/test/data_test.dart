import 'dart:convert';
import 'dart:io';

import 'package:biseo/data/briefing_repo.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/data/settings.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 2026-11-06 KST 오전 (UTC로는 11-05 21:00)
DateTime today() => DateTime.utc(2026, 11, 5, 21);
final fixture = File('test/fixtures/briefing.json').readAsStringSync();
final yesterdayJson = fixture.replaceFirst('2026-11-06', '2026-11-05');
final fail = MockClient((_) async => throw http.ClientException('down'));
MockClient ok(String body) => MockClient((_) async => http.Response.bytes(_u8(body), 200));
List<int> _u8(String s) => utf8.encode(s);

Future<SharedPreferences> prefs([Map<String, Object> v = const {}]) async {
  SharedPreferences.setMockInitialValues(v);
  return SharedPreferences.getInstance();
}

void main() {
  group('BriefingRepo', () {
    test('network ok today -> fresh, saved', () async {
      final p = await prefs();
      final r = await BriefingRepo(ok(fixture), p, now: today).load();
      expect(r.stale, false);
      expect(p.getString('briefing_json'), fixture);
    });
    test('network ok yesterday -> stale', () async {
      final r = await BriefingRepo(ok(yesterdayJson), await prefs(), now: today).load();
      expect(r.briefing!.date, '2026-11-05');
      expect(r.stale, true);
    });
    test('fail + saved -> saved copy, stale by date', () async {
      final r = await BriefingRepo(fail, await prefs({'briefing_json': yesterdayJson}), now: today).load();
      expect(r.briefing!.date, '2026-11-05');
      expect(r.stale, true);
    });
    test('fail + nothing saved -> null', () async {
      final r = await BriefingRepo(fail, await prefs(), now: today).load();
      expect(r.briefing, isNull);
    });
    test('malformed body -> saved copy kept, not overwritten', () async {
      final bad = fixture.replaceFirst('"advice"', '"advice": {"good": 5}, "x"');
      for (final body in ['not json', '[]', bad]) {
        final p = await prefs({'briefing_json': yesterdayJson});
        final r = await BriefingRepo(ok(body), p, now: today).load();
        expect(r.briefing!.date, '2026-11-05', reason: body);
        expect(p.getString('briefing_json'), yesterdayJson);
      }
    });
    test('KST boundary: 14:59 UTC is still same KST day, 15:00 is next', () async {
      final p = await prefs({'briefing_json': fixture}); // 2026-11-06
      expect((await BriefingRepo(fail, p, now: () => DateTime.utc(2026, 11, 6, 14, 59)).load()).stale, false);
      expect((await BriefingRepo(fail, p, now: () => DateTime.utc(2026, 11, 6, 15)).load()).stale, true);
    });
  });

  group('ServerApi', () {
    test('sends key header + parses weather/geocode/route', () async {
      final seen = <http.Request>[];
      final c = MockClient((r) async {
        seen.add(r);
        final body = {
          '/api/weather': '{"tempC":12,"sky":"맑음","rain":"없음","popMax":10,"tmin":null,"tmax":18}',
          '/api/geocode': '{"items":[{"name":"집","address":"서울","lat":37.5,"lon":127}]}',
          '/api/route': '{"carMin":20,"transitMin":null,"transitBlocked":true}',
        }[r.url.path]!;
        return http.Response.bytes(_u8(body), 200);
      });
      final api = ServerApi(c, base: 'https://s', appKey: 'K');
      final w = await api.weather(37.5, 127);
      expect((w.sky, w.tmin, w.tmax), ('맑음', null, 18));
      final g = await api.geocode('집');
      expect(g.single.lon, 127.0);
      final rt = await api.route(g.single, g.single);
      expect((rt.carMin, rt.transitMin, rt.transitBlocked), (20, null, true));
      expect(seen.every((r) => r.headers['x-ssok-key'] == 'K'), true);
      expect(seen[2].url.queryParameters.keys, containsAll(['fromLat', 'fromLon', 'toLat', 'toLon']));
    });
    test('non-200 -> ServerException', () async {
      final api = ServerApi(MockClient((_) async => http.Response('', 401)), base: 'https://s');
      expect(api.weather(1, 1), throwsA(isA<ServerException>()));
    });
    test('server takes 6s -> ServerException (5s timeout)', () {
      fakeAsync((async) {
        final api = ServerApi(
            MockClient((_) => Future.delayed(const Duration(seconds: 6), () => http.Response('{}', 200))),
            base: 'https://s');
        Object? err;
        api.weather(1, 1).then((_) {}, onError: (Object e) { err = e; });
        async.elapse(const Duration(seconds: 5, milliseconds: 1));
        expect(err, isA<ServerException>());
      });
    });
  });

  group('SettingsStore', () {
    test('defaults', () async {
      final s = SettingsStore(await prefs(), now: today).load();
      expect(s.topics, ['경제', 'IT', '건강']);
      expect(s.communities, ['geeknews']);
      expect(s.taxSources, ['sejungilbo', 'nts_press', 'nts_notice']);
      expect((s.tone, s.home), ('friend', null));
    });
    test('round trip + mood valid only today (KST)', () async {
      final p = await prefs();
      final st = SettingsStore(p, now: today);
      await st.save(Settings(home: const Place('집', '서울', 37.5, 127), moodToday: 'tired', moodDate: '2026-11-06'));
      expect(st.load().home!.name, '집');
      expect(st.load().moodToday, 'tired');
      final tomorrow = SettingsStore(p, now: () => today().add(const Duration(days: 1)));
      expect(tomorrow.load().moodToday, isNull);
      expect(tomorrow.load().home!.address, '서울');
    });
    test('communities round trip; legacy saved settings -> default', () async {
      final p = await prefs();
      final st = SettingsStore(p, now: today);
      await st.save(Settings(communities: ['ppomppu', '82cook']));
      expect(st.load().communities, ['ppomppu', '82cook']);
      p.setString('settings_json', '{"topics":["IT"],"tone":"coach"}');
      expect(st.load().communities, ['geeknews']);
      await st.save(Settings(communities: []));
      expect(st.load().communities, isEmpty);
    });
    test('taxSources round trip; legacy -> all three', () async {
      final p = await prefs();
      final st = SettingsStore(p, now: today);
      await st.save(Settings(taxSources: ['nts_press']));
      expect(st.load().taxSources, ['nts_press']);
      p.setString('settings_json', '{"topics":["IT"]}');
      expect(st.load().taxSources, ['sejungilbo', 'nts_press', 'nts_notice']);
      await st.save(Settings(taxSources: []));
      expect(st.load().taxSources, isEmpty);
    });
  });
}
