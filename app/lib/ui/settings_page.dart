import 'package:flutter/material.dart';

import '../data/briefing.dart';
import '../data/server_api.dart';
import '../data/settings.dart';
import 'cards/shell.dart';
import 'place_search_page.dart';

class SettingsPage extends StatefulWidget {
  final ServerApi api;
  final SettingsStore store;
  const SettingsPage({super.key, required this.api, required this.store});

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
