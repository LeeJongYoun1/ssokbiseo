import 'package:flutter/material.dart';

import '../data/youtube.dart';

/// 채널 주소를 받아 YtChannel로 pop한다.
class ChannelAddPage extends StatefulWidget {
  final YoutubeSource youtube;
  final List<YtChannel> existing;
  const ChannelAddPage({super.key, required this.youtube, required this.existing});

  @override
  State<ChannelAddPage> createState() => _ChannelAddPageState();
}

class _ChannelAddPageState extends State<ChannelAddPage> {
  final _c = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_c.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ch = await widget.youtube.resolve(_c.text);
    if (!mounted) return;
    if (ch == null) {
      setState(() {
        _busy = false;
        _error = '채널을 찾지 못했어요. 주소를 다시 확인해 주세요';
      });
    } else if (widget.existing.any((e) => e.id == ch.id)) {
      setState(() {
        _busy = false;
        _error = '이미 등록한 채널이에요';
      });
    } else {
      Navigator.pop(context, ch);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('채널 추가')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(hintText: '채널 주소나 @이름을 붙여 넣어 주세요'),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _add,
                child: const Text('추가', style: TextStyle(fontSize: 18)),
              ),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(fontSize: 17, height: 1.4)),
              ),
          ]),
        ),
      );
}
