import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

export 'package:device_calendar/device_calendar.dart' show Event;

/// null = 권한 없음
abstract class CalendarSource {
  Future<List<Event>?> today();
  Future<bool> request() async => false;
}

class DeviceCalendarSource extends CalendarSource {
  final _p = DeviceCalendarPlugin();

  @override
  Future<bool> request() async =>
      (await _p.requestPermissions()).data ?? false;

  @override
  Future<List<Event>?> today() async {
    if (!((await _p.hasPermissions()).data ?? false)) return null;
    final n = DateTime.now();
    final d0 = DateTime(n.year, n.month, n.day);
    tz.TZDateTime at(DateTime d) =>
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, d.millisecondsSinceEpoch);
    // 로컬 자정~다음 자정(로컬 달력 기준 +1일)
    final p = RetrieveEventsParams(
        startDate: at(d0), endDate: at(DateTime(n.year, n.month, n.day + 1)));
    final cals = (await _p.retrieveCalendars()).data ?? [];
    final out = <Event>[];
    for (final c in cals) {
      out.addAll((await _p.retrieveEvents(c.id, p)).data ?? []);
    }
    return todayEvents(out, n);
  }
}

/// 하루 종일 먼저, 그다음 시작 시각순
int compareEvents(Event a, Event b) {
  final aa = a.allDay ?? false, ba = b.allDay ?? false;
  if (aa != ba) return aa ? -1 : 1;
  return (a.start?.millisecondsSinceEpoch ?? 0)
      .compareTo(b.start?.millisecondsSinceEpoch ?? 0);
}

/// 오늘(로컬) 일정만, 하루 종일 먼저. 하루 종일은 UTC 자정 저장이 흔해 날짜만 비교한다.
List<Event> todayEvents(List<Event> raw, DateTime nowLocal) {
  final day = DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day);
  final d0 = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final d1 = DateTime(nowLocal.year, nowLocal.month, nowLocal.day + 1);
  DateTime dateOnly(DateTime t) => DateTime.utc(t.year, t.month, t.day);
  bool isToday(Event e) {
    final s = e.start;
    if (s == null) return false;
    final end = e.end ?? s;
    if (e.allDay ?? false) {
      final sd = dateOnly(s);
      var ed = dateOnly(end);
      if (!ed.isAfter(sd)) ed = sd.add(const Duration(days: 1));
      return !sd.isAfter(day) && day.isBefore(ed);
    }
    final ms = s.millisecondsSinceEpoch, me = end.millisecondsSinceEpoch;
    return ms < d1.millisecondsSinceEpoch &&
        (me > d0.millisecondsSinceEpoch || ms >= d0.millisecondsSinceEpoch);
  }

  return raw.where(isToday).toList()..sort(compareEvents);
}
