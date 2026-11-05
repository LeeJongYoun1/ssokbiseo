import 'package:flutter/material.dart';

import '../data/briefing.dart';
import '../data/briefing_repo.dart';
import '../data/calendar.dart';
import '../data/kst.dart';
import '../data/location.dart';
import '../data/server_api.dart';
import '../data/settings.dart';
import 'cards/mood_card.dart';
import 'cards/news_card.dart';
import 'cards/route_card.dart';
import 'cards/schedule_card.dart';
import 'cards/weather_card.dart';

class HomePage extends StatefulWidget {
  final BriefingRepo briefingRepo;
  final ServerApi api;
  final SettingsStore store;
  final CalendarSource calendar;
  final LocationSource location;
  const HomePage({
    super.key,
    required this.briefingRepo,
    required this.api,
    required this.store,
    required this.calendar,
    required this.location,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Settings _s;
  late Future<BriefingResult> _br;
  late Future<Briefing?> _b;
  late Future<WeatherRows>? _weather;
  late Future<List<Event>?> _cal;
  late Future<List<Leg>?>? _route;
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 카드마다 자기 Future를 갖는다 — 하나가 실패해도 다른 카드는 그대로.
  void _load() {
    _s = widget.store.load();
    final hasPlace = _s.home != null || _s.work != null;
    _br = widget.briefingRepo.load();
    _b = _br.then<Briefing?>((r) {
      if (mounted) setState(() => _stale = r.stale);
      return r.briefing;
    });
    _weather = hasPlace ? loadWeather(widget.api, _s.home, _s.work) : null;
    _route = hasPlace ? loadRoutes(widget.api, widget.location, _s.home, _s.work) : null;
    _cal = widget.calendar.today();
  }

  Future<void> _refresh() async {
    setState(_load);
    // 실패해도 새로고침 표시는 끝나야 한다
    await Future.wait([
      for (final f in <Future?>[_br, _weather, _route, _cal])
        if (f != null) f.then((_) {}, onError: (_) {}),
    ]);
  }

  Future<void> _allow(Future<bool> Function() ask) async {
    await ask();
    if (mounted) setState(_load);
  }

  Future<void> _pick(String key) async {
    _s.moodToday = key;
    _s.moodDate = kstToday(DateTime.now());
    setState(() {});
    await widget.store.save(_s);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('쏙비서',
              style: TextStyle(fontFamily: 'JuaTitle', fontSize: 28)),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              WeatherCard(_weather),
              ScheduleCard(_cal, () => _allow(widget.calendar.request)),
              RouteCard(_route, () => _allow(widget.location.request)),
              MoodCard(_b, _stale, _s.moodToday, _s.tone, _pick),
              NewsCard(_b, _stale, _s.topics),
              GeekNewsCard(_b, _stale),
            ],
          ),
        ),
      );
}
