import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'briefing.dart';
import 'kst.dart';

const briefingUrl =
    'https://raw.githubusercontent.com/LeeJongYoun1/ssokbiseo/main/data/briefing.json';
const _kSaved = 'briefing_json';

class BriefingResult {
  final Briefing? briefing;
  final bool stale;
  const BriefingResult(this.briefing, this.stale);
}

class BriefingRepo {
  final http.Client _c;
  final SharedPreferences _p;
  final DateTime Function() _now;
  final Duration timeout;
  BriefingRepo(this._c, this._p,
      {DateTime Function()? now, this.timeout = const Duration(seconds: 5)})
      : _now = now ?? DateTime.now;

  Briefing? _parse(String? raw) {
    if (raw == null) return null;
    try {
      return Briefing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<BriefingResult> load() async {
    Briefing? b;
    try {
      final r = await _c.get(Uri.parse(briefingUrl)).timeout(timeout);
      if (r.statusCode == 200) {
        final raw = utf8.decode(r.bodyBytes);
        b = _parse(raw);
        if (b != null) await _p.setString(_kSaved, raw); // 정상 파싱될 때만 저장
      }
    } catch (_) {}
    b ??= _parse(_p.getString(_kSaved));
    return BriefingResult(b, b != null && b.date != kstToday(_now()));
  }
}
