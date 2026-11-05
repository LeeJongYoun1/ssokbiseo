import 'package:biseo/data/briefing.dart';
import 'package:biseo/ui/cards/shell.dart';
import 'package:biseo/ui/cards/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _b = Briefing(
    '2026-11-05',
    {'IT': [const NewsItem('제목', '요약', 'https://a.com/1')]},
    {},
    {'geeknews': [const CommunityItem('긱', 3, '긱요약', 'https://g.com/o', 'https://g.com/d')]});

Future<void> _open(WidgetTester t, Widget Function(ShareText) card, ShareText s,
    String tap) async {
  await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card(s)))));
  await t.pumpAndSettle();
  if (tap == '제목') await t.tap(find.text('IT'));
  if (tap == '긱') await t.tap(find.text('GeekNews (1)'));
  await t.pumpAndSettle();
  await t.tap(find.text(tap));
  await t.pumpAndSettle();
  await t.tap(find.text('공유하기'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('뉴스 공유: 제목/요약/원문 url', (t) async {
    String? got, subj;
    await _open(t, (ShareText s) => NewsCard(Future.value(_b), false, const ['IT'], share: s),
        (x, {subject}) async { got = x; subj = subject; }, '제목');
    expect(got, '제목\n요약\nhttps://a.com/1');
    expect(subj, '제목');
  });

  testWidgets('GeekNews 공유: discussUrl 아닌 url', (t) async {
    String? got;
    await _open(t, (ShareText s) => CommunityCard(Future.value(_b), false, const ['geeknews'], share: s),
        (x, {subject}) async { got = x; }, '긱');
    expect(got, '긱\n긱요약\nhttps://g.com/o');
    expect(find.text('토론 보기'), findsOneWidget);
  });

  testWidgets('커뮤니티: 접힘 -> 펼치면 제목, 어제 표시', (t) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CommunityCard(Future.value(_b), true, const ['geeknews'])))));
    await t.pumpAndSettle();
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('어제 내용이에요'), findsOneWidget);
    expect(find.text('긱'), findsNothing);
    await t.tap(find.text('GeekNews (1)'));
    await t.pumpAndSettle();
    expect(find.text('긱'), findsOneWidget);
  });

  testWidgets('공유 실패 -> 안내', (t) async {
    await _open(t, (ShareText s) => CommunityCard(Future.value(_b), false, const ['geeknews'], share: s),
        (x, {subject}) async => throw Exception('x'), '긱');
    expect(find.text('공유하지 못했어요'), findsOneWidget);
  });

  Future<void> pumpCard(WidgetTester t, List<String> sel, Briefing b) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: CommunityCard(Future.value(b), false, sel)))));
    await t.pumpAndSettle();
  }

  testWidgets('선택한 커뮤니티만 kCommunities 순서로, 점수 라벨은 곳마다 다르다', (t) async {
    final b = Briefing('d', {}, {}, {
      'geeknews': [const CommunityItem('g', 5, 's', 'https://g', 'https://d')],
      'ppomppu': [const CommunityItem('p', null, 's', 'https://p')],
      'ruliweb': [const CommunityItem('r', 7, 's', 'https://r')],
      '82cook': [const CommunityItem('c', 9, 's', 'https://c')],
    });
    await pumpCard(t, ['82cook', 'ppomppu', 'ruliweb'], b); // 선택 순서와 무관하게 정해진 순서
    expect(find.text('GeekNews (1)'), findsNothing);
    final y = [for (final l in ['뽐뿌 (1)', '루리웹 (1)', '82cook (1)']) t.getTopLeft(find.text(l)).dy];
    expect(y, [...y]..sort());
    for (final l in ['뽐뿌 (1)', '루리웹 (1)', '82cook (1)']) { await t.tap(find.text(l)); }
    await t.pumpAndSettle();
    expect(find.text('추천 7'), findsOneWidget);
    expect(find.text('조회 9'), findsOneWidget);
    expect(find.textContaining('추천'), findsOneWidget); // 뽐뿌 points null -> 표시 없음
  });

  testWidgets('GeekNews 점수는 N점, 토론 버튼은 discussUrl 있을 때만', (t) async {
    final b = Briefing('d', {}, {}, {
      'geeknews': [const CommunityItem('g', 5, 's', 'https://g', 'https://d')],
      'ruliweb': [const CommunityItem('r', 7, 's', 'https://r')],
    });
    await pumpCard(t, ['geeknews', 'ruliweb'], b);
    await t.tap(find.text('GeekNews (1)'));
    await t.tap(find.text('루리웹 (1)'));
    await t.pumpAndSettle();
    expect(find.text('5점'), findsOneWidget);
    await t.tap(find.text('r'));
    await t.pumpAndSettle();
    expect(find.text('원문 보기'), findsOneWidget);
    expect(find.text('토론 보기'), findsNothing);
  });

  testWidgets('세무 소식: 선택·순서·라벨, 비면 안내', (t) async {
    final b = Briefing('d', {}, {}, {}, {
      'sejungilbo': [const CommunityItem('s', null, 'x', 'https://s')],
      'nts_press': [const CommunityItem('p', 12, 'x', 'https://p')],
      'nts_notice': [const CommunityItem('n', 3, 'x', 'https://n')],
    });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: TaxCard(Future.value(b), false, const ['nts_press', 'sejungilbo'])))));
    await t.pumpAndSettle();
    expect(find.text('세무 소식'), findsOneWidget);
    expect(find.text('국세청 공지사항 (1)'), findsNothing);
    expect(t.getTopLeft(find.text('세정일보 (1)')).dy < t.getTopLeft(find.text('국세청 보도자료 (1)')).dy, true);
    await t.tap(find.text('국세청 보도자료 (1)'));
    await t.tap(find.text('세정일보 (1)'));
    await t.pumpAndSettle();
    expect(find.text('조회 12'), findsOneWidget);
    expect(find.textContaining('조회'), findsOneWidget);
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: TaxCard(Future.value(b), false, const []))));
    await t.pumpAndSettle();
    expect(find.text('설정에서 볼 세무 소식을 골라 주세요'), findsOneWidget);
  });

  testWidgets('아무것도 안 골랐으면 안내', (t) async {
    await pumpCard(t, [], const Briefing('d', {}, {}, {}));
    expect(find.text('설정에서 볼 커뮤니티를 골라 주세요'), findsOneWidget);
  });
}
