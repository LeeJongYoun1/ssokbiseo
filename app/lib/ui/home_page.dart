import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/briefing.dart';
import '../data/briefing_repo.dart';
import '../data/calendar.dart';
import '../data/kst.dart';
import '../data/location.dart';
import '../data/server_api.dart';
import '../data/settings.dart';
import '../data/youtube.dart';
import 'cards/mood_card.dart';
import 'cards/news_card.dart';
import 'cards/route_card.dart';
import 'cards/schedule_card.dart';
import 'cards/shell.dart';
import 'cards/youtube_card.dart';
import 'cards/weather_card.dart';
import 'settings_page.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  final BriefingRepo briefingRepo;
  final ServerApi api;
  final SettingsStore store;
  final CalendarSource calendar;
  final LocationSource location;
  final bool demo;
  final YoutubeSource? youtube;
  final Future<bool> Function(String) openUrl;
  const HomePage({
    super.key,
    required this.briefingRepo,
    required this.api,
    required this.store,
    required this.calendar,
    required this.location,
    this.demo = false,
    this.youtube,
    this.openUrl = openExternal,
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
  late Future<ChannelVideos?>? _yt;
  late final YoutubeSource _ytSrc = widget.youtube ?? YoutubeSource(http.Client());
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
    final loc = _OnceLoc(widget.location); // 날씨·길찾기가 GPS 한 번만 쓰도록
    _weather = loadWeather(widget.api, _s.home, _s.work, loc.current());
    _weather!.ignore(); // 카드가 떼어진 뒤 늦게 실패해도 무시
    _route = hasPlace
        ? loadRoutes(widget.api, loc, _s.home, _s.work)
        : null;
    _cal = widget.calendar.today();
    _yt = _s.channels.isEmpty ? null : _ytSrc.newVideos(_s.channels, DateTime.now());
    _yt?.ignore();
  }

  Future<void> _refresh() async {
    setState(_load);
    // 실패해도 새로고침 표시는 끝나야 한다
    await Future.wait([
      for (final f in <Future?>[_br, _weather, _route, _cal, _yt])
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

  Future<void> _openSettings() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(api: widget.api, store: widget.store, youtube: _ytSrc),
      ),
    );
    if (changed == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        '쏙비서',
        style: TextStyle(fontFamily: 'JuaTitle', fontSize: 28),
      ),
      actions: [
        IconButton(
          tooltip: '설정',
          icon: const Icon(Icons.settings, size: 28),
          onPressed: _openSettings,
        ),
      ],
    ),
    body: Column(children: [
      if (widget.demo)
        Container(
          width: double.infinity,
          color: SsokColors.lemonLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text('예시 화면이에요. 날씨·길찾기·뉴스는 연결 전이라 예시로 보여요.'),
        ),
      Expanded(child: RefreshIndicator(
      onRefresh: _refresh,
      // ListView는 화면 밖 카드를 버렸다가 다시 만들어 FutureBuilder가 한 프레임 로딩(다른 높이)으로
      // 그려지고, 그 높이 변화로 스크롤이 되밀려 쓸어내려도 올라가지 않았다. 카드 8개라 한 번에 다 만든다.
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // 3버튼 내비 바 아래로 마지막 카드가 들어가지 않게
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.paddingOf(context).bottom),
        // stretch: Column은 카드를 내용 폭에 맞춰 가운데 둔다(ListView와 달리)
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WeatherCard(_weather, needPlaces: _s.home == null && _s.work == null),
          ScheduleCard(_cal, () => _allow(widget.calendar.request)),
          RouteCard(_route, () => _allow(widget.location.request)),
          MoodCard(_b, _stale, _s.moodToday, _s.tone, _pick),
          NewsCard(_b, _stale, _s.topics),
          TaxCard(_b, _stale, _s.taxSources),
          YoutubeCard(_yt, open: widget.openUrl),
          CommunityCard(_b, _stale, _s.communities),
        ]),
      ),
    )),
    ]),
  );
}

/// current()를 한 번만 부르고 결과를 나눠 쓴다
class _OnceLoc extends LocationSource {
  final LocationSource _l;
  _OnceLoc(this._l);
  Future<(double, double)?>? _cur;
  @override
  Future<(double, double)?> current() => _cur ??= _l.current();
  @override
  Future<bool> serviceOn() => _l.serviceOn();
  @override
  Future<bool> request() => _l.request();
}
