import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'kst.dart';
import 'server_api.dart';
import 'youtube.dart';

class Settings {
  Place? home, work;
  List<String> topics, communities;
  String tone;
  String? moodToday, moodDate;
  List<YtChannel> channels;
  Settings({this.home, this.work, List<String>? topics, List<String>? communities, this.tone = 'friend', this.moodToday, this.moodDate, List<YtChannel>? channels})
      : topics = topics ?? ['경제', 'IT', '건강'],
        communities = communities ?? ['geeknews'],
        channels = channels ?? [];
}

class SettingsStore {
  static const _k = 'settings_json';
  final SharedPreferences _p;
  final DateTime Function() _now;
  SettingsStore(this._p, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  Settings load() {
    final raw = _p.getString(_k);
    if (raw == null) return Settings();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      Place? pl(String k) => j[k] == null ? null : Place.fromJson(Map<String, dynamic>.from(j[k] as Map));
      final fresh = j['moodDate'] == kstToday(_now());
      return Settings(
        home: pl('home'),
        work: pl('work'),
        topics: (j['topics'] as List?)?.cast<String>(),
        communities: (j['communities'] as List?)?.cast<String>(),
        tone: j['tone'] as String? ?? 'friend',
        moodToday: fresh ? j['moodToday'] as String? : null,
        moodDate: fresh ? j['moodDate'] as String? : null,
        channels: [
          for (final c in (j['channels'] as List? ?? const []))
            YtChannel.fromJson(Map<String, dynamic>.from(c as Map))
        ],
      );
    } catch (_) {
      return Settings(); // 깨진 저장값은 기본값으로
    }
  }

  Future<void> save(Settings s) => _p.setString(
      _k,
      jsonEncode({
        'home': s.home?.toJson(),
        'work': s.work?.toJson(),
        'topics': s.topics,
        'communities': s.communities,
        'tone': s.tone,
        'moodToday': s.moodToday,
        'moodDate': s.moodDate,
        'channels': [for (final c in s.channels) c.toJson()],
      }));
}
