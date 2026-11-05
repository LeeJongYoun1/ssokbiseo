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
    tz.TZDateTime at(DateTime d) =>
        tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, d.millisecondsSinceEpoch);
    final p = RetrieveEventsParams(
        startDate: at(DateTime(n.year, n.month, n.day)),
        endDate: at(DateTime(n.year, n.month, n.day, 23, 59, 59)));
    final cals = (await _p.retrieveCalendars()).data ?? [];
    final out = <Event>[];
    for (final c in cals) {
      out.addAll((await _p.retrieveEvents(c.id, p)).data ?? []);
    }
    out.sort(compareEvents);
    return out;
  }
}

/// 하루 종일 먼저, 그다음 시작 시각순
int compareEvents(Event a, Event b) {
  final aa = a.allDay ?? false, ba = b.allDay ?? false;
  if (aa != ba) return aa ? -1 : 1;
  return (a.start?.millisecondsSinceEpoch ?? 0)
      .compareTo(b.start?.millisecondsSinceEpoch ?? 0);
}
