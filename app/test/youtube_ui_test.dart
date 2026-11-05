import 'dart:convert';

import 'package:biseo/data/briefing_repo.dart';
import 'package:biseo/data/calendar.dart';
import 'package:biseo/data/location.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/data/settings.dart';
import 'package:biseo/data/youtube.dart';
import 'package:biseo/ui/home_page.dart';
import 'package:biseo/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCal extends CalendarSource {
  @override
  Future<List<Event>?> today() async => [];
}

class FakeLoc extends LocationSource {
  @override
  Future<bool> serviceOn() async => true;
  @override
  Future<(double, double)?> current() async => null;
}

class FakeYt extends YoutubeSource {
  final ChannelVideos? result;
  final YtChannel? resolved;
  FakeYt({this.result, this.resolved}) : super(MockClient((_) async => http.Response('', 500)));
  @override
  Future<ChannelVideos?> newVideos(List<YtChannel> c, DateTime now) async => result;
  @override
  Future<YtChannel?> resolve(String input) async => resolved;
}

const ch = YtChannel('UCaaaaaaaaaaaaaaaaaaaaaa', '맛집채널');
final now = DateTime.now();
YtVideo vid(String t, int h) =>
    YtVideo(t, t, 'https://www.youtube.com/watch?v=$t', now.subtract(Duration(hours: h)));

late SettingsStore store;

Future<void> pumpHome(WidgetTester t, FakeYt yt,
    {List<YtChannel> channels = const [], List<String>? opened}) async {
  SharedPreferences.setMockInitialValues({});
  final p = await SharedPreferences.getInstance();
  store = SettingsStore(p);
  await store.save(Settings(channels: channels));
  t.view.physicalSize = const Size(800, 6000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = MockClient((r) async => throw http.ClientException('down'));
  await t.pumpWidget(const SizedBox()); // 이전 화면 상태 버리기
  await t.pumpWidget(MaterialApp(
    home: HomePage(
      briefingRepo: BriefingRepo(c, p),
      api: ServerApi(c, base: 'http://x', appKey: 'k'),
      store: store,
      calendar: FakeCal(),
      location: FakeLoc(),
      youtube: yt,
      openUrl: (u) async {
        opened?.add(u);
        return true;
      },
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('채널 없음 -> 안내', (t) async {
    await pumpHome(t, FakeYt());
    expect(find.text('유튜브 새 영상'), findsOneWidget);
    expect(find.text('설정에서 유튜브 채널을 추가해 주세요'), findsOneWidget);
  });

  testWidgets('채널별 아코디언(개수), 영상 탭 -> 열기', (t) async {
    final opened = <String>[];
    await pumpHome(t, FakeYt(result: [(ch, [vid('v1', 2), vid('v2', 5)])]),
        channels: [ch], opened: opened);
    expect(find.text('맛집채널 (2)'), findsOneWidget);
    expect(find.text('v1'), findsNothing); // 접힌 상태
    await t.tap(find.text('맛집채널 (2)'));
    await t.pumpAndSettle();
    expect(find.text('2시간 전'), findsOneWidget);
    await t.tap(find.text('v1'));
    expect(opened, ['https://www.youtube.com/watch?v=v1']);
  });

  testWidgets('하루 새 영상 없음 / 전부 실패', (t) async {
    await pumpHome(t, FakeYt(result: []), channels: [ch]);
    expect(find.text('지난 하루 새 영상이 없어요'), findsOneWidget);
    await pumpHome(t, FakeYt(result: null), channels: [ch]);
    expect(find.text('영상을 불러오지 못했어요'), findsOneWidget);
  });

  testWidgets('설정: 채널 추가 / 중복 / 삭제 / 저장', (t) async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    await store.save(Settings(channels: [ch]));
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = MockClient((r) async => throw http.ClientException('down'));
    Future<void> open(YtChannel? resolved) async {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(MaterialApp(
        home: SettingsPage(
            api: ServerApi(c, base: 'http://x', appKey: 'k'),
            store: store,
            youtube: FakeYt(resolved: resolved)),
      ));
    }

    Future<void> add(String text) async {
      await t.tap(find.text('채널 추가'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), text);
      await t.tap(find.text('추가'));
      await t.pumpAndSettle();
    }

    await open(null);
    expect(find.text('맛집채널'), findsOneWidget);
    await add('@x');
    expect(find.text('채널을 찾지 못했어요. 주소를 다시 확인해 주세요'), findsOneWidget);
    await open(ch);
    await add('@dup');
    expect(find.text('이미 등록한 채널이에요'), findsOneWidget);

    await open(const YtChannel('UCbbbbbbbbbbbbbbbbbbbbbb', '새채널'));
    await add('@new');
    expect(find.text('새채널'), findsOneWidget);
    await t.tap(find.byTooltip('맛집채널 삭제'));
    await t.pumpAndSettle();
    expect(find.text('맛집채널'), findsNothing);
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().channels.map((e) => e.name), ['새채널']);
  });

  test('옛 저장값(channels 없음)은 []', () async {
    SharedPreferences.setMockInitialValues({'settings_json': jsonEncode({'tone': 'friend'})});
    final s = SettingsStore(await SharedPreferences.getInstance()).load();
    expect(s.channels, isEmpty);
  });
}
