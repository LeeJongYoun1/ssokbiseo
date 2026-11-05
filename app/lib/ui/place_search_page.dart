import 'package:flutter/material.dart';

import '../data/server_api.dart';

/// 주소를 검색해 후보 중 하나를 골라 Place로 pop한다.
class PlaceSearchPage extends StatefulWidget {
  final ServerApi api;
  final String title;
  const PlaceSearchPage({super.key, required this.api, required this.title});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final _c = TextEditingController();
  List<Place>? _items;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _c.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await widget.api.geocode(q);
      if (!mounted) return;
      setState(() {
        _items = r;
        _error = r.isEmpty ? '찾는 곳이 없어요. 동 이름이나 건물 이름으로 찾아보세요' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = null;
        _error = '주소를 찾지 못했어요. 잠시 뒤 다시 해 보세요';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(hintText: '동 이름이나 건물 이름'),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _search,
                child: const Text('찾기', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
          ),
        Expanded(
          child: ListView(
            children: [
              for (final p in _items ?? const <Place>[])
                ListTile(
                  title: Text(p.name, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(
                    p.address,
                    style: const TextStyle(fontSize: 15),
                  ),
                  onTap: () => Navigator.pop(context, p),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
