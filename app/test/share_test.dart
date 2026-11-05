import 'package:biseo/data/briefing.dart';
import 'package:biseo/ui/cards/shell.dart';
import 'package:biseo/ui/cards/news_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _b = Briefing(
    '2026-11-05',
    {'IT': [const NewsItem('제목', '요약', 'https://a.com/1')]},
    {},
    [const GeekItem('긱', 3, '긱요약', 'https://g.com/o', 'https://g.com/d')]);

Future<void> _open(WidgetTester t, Widget Function(ShareText) card, ShareText s,
    String tap) async {
  await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: card(s)))));
  await t.pumpAndSettle();
  if (tap == '제목') await t.tap(find.text('IT'));
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
    await _open(t, (ShareText s) => GeekNewsCard(Future.value(_b), false, share: s),
        (x, {subject}) async { got = x; }, '긱');
    expect(got, '긱\n긱요약\nhttps://g.com/o');
    expect(find.text('토론 보기'), findsOneWidget);
  });

  testWidgets('공유 실패 -> 안내', (t) async {
    await _open(t, (ShareText s) => GeekNewsCard(Future.value(_b), false, share: s),
        (x, {subject}) async => throw Exception('x'), '긱');
    expect(find.text('공유하지 못했어요'), findsOneWidget);
  });
}
