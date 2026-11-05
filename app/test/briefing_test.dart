import 'dart:convert';
import 'dart:io';

import 'package:biseo/data/briefing.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> load() =>
    jsonDecode(File('test/fixtures/briefing.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('fromJson parses fixture', () {
    final b = Briefing.fromJson(load());
    expect(b.date, '2026-11-06');
    expect(b.news['경제']!.first.title, isNotEmpty);
    expect(b.advice['tired']!['coach'], isNotEmpty);
    expect(b.geeknews.length, 3);
    expect(b.geeknews.first.discussUrl, startsWith('https://news.hada.io'));
  });

  test('unknown topic keys ignored', () {
    final j = load();
    (j['news'] as Map)['낚시'] = [
      {'title': 't', 'summary': 's', 'url': 'u'}
    ];
    expect(Briefing.fromJson(j).news.containsKey('낚시'), false);
  });

  test('missing geeknews/news tolerated', () {
    final j = load()..remove('geeknews')..remove('news');
    final b = Briefing.fromJson(j);
    expect(b.geeknews, isEmpty);
    expect(b.news, isEmpty);
  });

  test('constants', () {
    expect(kTopics.length, 12);
    expect(kMoods.map((m) => m.key), ['good', 'tired', 'worried', 'down', 'eager']);
    expect(kTones.map((t) => t.key), ['friend', 'coach', 'quote', 'action']);
  });
}
