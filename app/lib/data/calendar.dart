import 'package:device_calendar/device_calendar.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
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
  Future<bool> request() async {
    final t = Stopwatch()..start();
    final ok = (await _p.requestPermissions()).data ?? false;
    // shortcut: 거부가 영구인지 알 방법이 없어, 창 없이 즉시 false면 영구 거부로 보고 설정을 연다
    if (!ok && t.elapsedMilliseconds < 300) await Geolocator.openAppSettings();
    return ok;
  }

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
    // 실패를 빈 목록으로 삼키면 "일정 없음"으로 보이므로 던져서 카드가 오류를 알리게 한다
    final calRes = await _p.retrieveCalendars();
    if (!calRes.isSuccess) throw StateError('캘린더 목록 실패');
    final out = <Event>[];
    for (final c in calRes.data ?? <Calendar>[]) {
      final r = await _p.retrieveEvents(c.id, p);
      if (!r.isSuccess) throw StateError('일정 읽기 실패');
      out.addAll(r.data ?? []);
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
