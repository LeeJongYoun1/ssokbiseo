import 'dart:io';

import 'package:biseo/data/calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime u(int d, [int h = 0, int m = 0]) => tz.TZDateTime.utc(2026, 11, d, h, m);
Event all(String t, int s, int e) => Event('c', title: t, allDay: true, start: u(s), end: u(e));
// 기기 로컬 시각의 순간을 만든다
Event timed(String t, DateTime s, DateTime e) => Event('c',
    title: t,
    start: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, s.millisecondsSinceEpoch),
    end: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, e.millisecondsSinceEpoch));

void main() {
  final now = DateTime(2026, 11, 6, 12);
  List<String?> titles(List<Event> l) => todayEvents(l, now).map((e) => e.title).toList();

  test('all-day: yesterday/tomorrow excluded, today included', () {
    expect(titles([all('y', 5, 6), all('t', 6, 7), all('n', 7, 8)]), ['t']);
  });
  test('multi-day all-day covering today included', () {
    expect(titles([all('m', 4, 8)]), ['m']);
  });
  test('timed: 00:30 today in, 23:59 yesterday out', () {
    final in_ = timed('in', DateTime(2026, 11, 6, 0, 30), DateTime(2026, 11, 6, 1));
    final out = timed('out', DateTime(2026, 11, 5, 23, 0), DateTime(2026, 11, 5, 23, 59));
    expect(titles([out, in_]), ['in']);
  });
  test('all-day sorted first', () {
    final t = timed('t', DateTime(2026, 11, 6, 9), DateTime(2026, 11, 6, 10));
    expect(titles([t, all('a', 6, 7)]), ['a', 't']);
  });

  // release(R8)에서 device_calendar 모델 필드명이 바뀌면 캘린더 id가 null → 일정이 항상 비어 보인다
  test('release keeps device_calendar models from R8 renaming', () {
    expect(File('android/app/proguard-rules.pro').readAsStringSync(),
        contains('-keep class com.builttoroam.devicecalendar.** { *; }'));
  });
}
