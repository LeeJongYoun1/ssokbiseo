import 'dart:convert';

import 'package:biseo/data/briefing.dart';
import 'package:biseo/data/kst.dart';
import 'package:biseo/data/server_api.dart';
import 'package:biseo/data/settings.dart';
import 'package:biseo/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

late SettingsStore store;
bool? popped;

Future<void> pump(
  WidgetTester t,
  List<Map<String, Object?>>? items, {
  Settings? settings,
}) async {
  SharedPreferences.setMockInitialValues({});
  store = SettingsStore(await SharedPreferences.getInstance());
  if (settings != null) await store.save(settings);
  popped = null;
  t.view.physicalSize = const Size(800, 3000); // 목록 전체가 한 화면에 보이게
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = MockClient((r) async {
    if (items == null) throw http.ClientException('down');
    return http.Response.bytes(utf8.encode(jsonEncode({'items': items})), 200);
  });
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async => popped = await Navigator.push<bool>(
              ctx,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  api: ServerApi(c, base: 'http://x', appKey: 'k'),
                  store: store,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> search(WidgetTester t, String label, String q) async {
  await t.tap(find.text(label));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), q);
  await t.tap(find.text('찾기'));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  testWidgets('회사 주소 검색 -> 후보 고르기 -> 저장', (t) async {
    await pump(t, [
      {'name': '판교역', 'address': '경기 성남시', 'lat': 37.39, 'lon': 127.11},
    ]);
    await search(t, '회사', '판교역');
    await t.tap(find.widgetWithText(ListTile, '판교역'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().work?.name, '판교역');
    expect(popped, true);
  });

  testWidgets('주제는 마지막 하나를 끌 수 없다', (t) async {
    await pump(t, [], settings: Settings(topics: ['경제', 'IT']));
    await t.tap(find.text('IT'));
    await t.tap(find.text('경제'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().topics, ['경제']);
  });

  testWidgets('커뮤니티 체크: 기본 GeekNews, 켜고 끄기, 0개 허용', (t) async {
    await pump(t, []);
    await t.tap(find.text('뽐뿌'));
    await t.tap(find.text('GeekNews'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().communities, ['ppomppu']);
    await pump(t, [], settings: Settings(communities: ['ppomppu']));
    await t.tap(find.text('뽐뿌'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().communities, isEmpty);
  });

  testWidgets('세무 소식 체크: 기본 3곳, 끄기, 0개 허용', (t) async {
    await pump(t, []);
    await t.tap(find.text('세정일보'));
    await t.tap(find.text('국세청 공지사항'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().taxSources, ['nts_press']);
    await pump(t, [], settings: Settings(taxSources: ['nts_press']));
    await t.tap(find.text('국세청 보도자료'));
    await t.pumpAndSettle();
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().taxSources, isEmpty);
  });

  testWidgets('말투 명언 인용 선택 -> quote', (t) async {
    await pump(t, []);
    await t.tap(find.text(kTones.firstWhere((e) => e.key == 'quote').label));
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    expect(store.load().tone, 'quote');
  });

  testWidgets('검색 0건 안내', (t) async {
    await pump(t, []);
    await search(t, '집', '없는곳');
    expect(find.text('찾는 곳이 없어요. 동 이름이나 건물 이름으로 찾아보세요'), findsOneWidget);
  });

  testWidgets('검색 서버 실패 안내', (t) async {
    await pump(t, null);
    await search(t, '집', '판교역');
    expect(find.text('주소를 찾지 못했어요. 잠시 뒤 다시 해 보세요'), findsOneWidget);
  });

  testWidgets('저장해도 오늘 기분(moodToday/moodDate)은 보존된다', (t) async {
    final today = kstToday(DateTime.now());
    await pump(t, [], settings: Settings(moodToday: 'tired', moodDate: today));
    await t.tap(find.text('저장'));
    await t.pumpAndSettle();
    final s = store.load();
    expect(s.moodToday, 'tired');
    expect(s.moodDate, today);
  });
}
