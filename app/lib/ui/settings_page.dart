import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/briefing.dart';
import '../data/server_api.dart';
import '../data/settings.dart';
import '../data/youtube.dart';
import 'channel_add_page.dart';
import 'cards/shell.dart';
import 'place_search_page.dart';

class SettingsPage extends StatefulWidget {
  final ServerApi api;
  final SettingsStore store;
  final YoutubeSource? youtube;
  const SettingsPage({super.key, required this.api, required this.store, this.youtube});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final Settings _s = widget.store.load(); // moodToday/moodDate는 그대로 보존된다

  Future<void> _pickPlace(String title, void Function(Place) set) async {
    final p = await Navigator.push<Place>(context,
        MaterialPageRoute(builder: (_) => PlaceSearchPage(api: widget.api, title: title)));
    if (p != null) setState(() => set(p));
  }

  late final YoutubeSource _yt = widget.youtube ?? YoutubeSource(http.Client());

  Future<void> _addChannel() async {
    final c = await Navigator.push<YtChannel>(context,
        MaterialPageRoute(builder: (_) => ChannelAddPage(youtube: _yt, existing: _s.channels)));
    if (c != null) setState(() => _s.channels = [..._s.channels, c]);
  }

  Future<void> _save() async {
    await widget.store.save(_s);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _place(String label, Place? p, void Function(Place) set) => ListTile(
        title: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        subtitle: Text(p?.name ?? '눌러서 주소 찾기', style: const TextStyle(fontSize: 17)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickPlace(label, set),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('설정')),
        body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          CardShell('장소', [
            _place('집', _s.home, (p) => _s.home = p),
            _place('회사', _s.work, (p) => _s.work = p),
          ]),
          CardShell('볼 뉴스 주제', [
            for (final t in kTopics)
              CheckboxListTile(
                title: Text(t, style: const TextStyle(fontSize: 17)),
                value: _s.topics.contains(t),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _s.topics = [for (final k in kTopics) if (k == t || _s.topics.contains(k)) k];
                  } else if (_s.topics.length > 1) {
                    _s.topics = [..._s.topics]..remove(t);
                  } // 마지막 하나는 끌 수 없다
                }),
              ),
          ]),
          CardShell('유튜브 채널', [
            for (final c in _s.channels)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.name, style: const TextStyle(fontSize: 17)),
                trailing: IconButton(
                  tooltip: '${c.name} 삭제',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _s.channels = [..._s.channels]..remove(c)),
                ),
              ),
            if (_s.channels.length < kMaxChannels)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add),
                title: const Text('채널 추가', style: TextStyle(fontSize: 17)),
                onTap: _addChannel,
              )
            else
              bodyText('채널은 $kMaxChannels개까지 넣을 수 있어요'),
          ]),
          CardShell('조언 말투', [
            RadioGroup<String>(
              groupValue: _s.tone,
              onChanged: (v) => setState(() => _s.tone = v ?? _s.tone),
              child: Column(children: [
                for (final t in kTones)
                  RadioListTile<String>(
                    value: t.key,
                    title: Text(t.label, style: const TextStyle(fontSize: 17)),
                  ),
              ]),
            ),
          ]),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
                onPressed: _save,
                child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('저장', style: TextStyle(fontSize: 19)))),
          ),
        ),
      );
}
