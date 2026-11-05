import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const kMaxChannels = 20;
const _ua = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';

class YtChannel {
  final String id, name;
  const YtChannel(this.id, this.name);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory YtChannel.fromJson(Map<String, dynamic> j) => YtChannel(j['id'] as String, j['name'] as String);
}

class YtVideo {
  final String id, title, url;
  final DateTime published;
  const YtVideo(this.id, this.title, this.url, this.published);
}

typedef ChannelVideos = List<(YtChannel, List<YtVideo>)>;

enum ChannelRef { id, handle, video }

/// 입력(주소·영상 주소·@이름·이름, 앞뒤 글이 붙어도 됨)을 (종류, 값)으로. 핸들은 @ 없이 디코딩된 값.
(ChannelRef, String)? parseChannelInput(String raw) {
  final s = raw.trim();
  final url = RegExp(r'(?<![\w.\-/@])((?:https?://)?(?:(?:www|m|music)\.)?(?:youtube\.com|youtu\.be)/\S*)')
      .firstMatch(s)
      ?.group(1);
  if (url == null) {
    if (RegExp(r'^UC[\w-]{22}$').hasMatch(s)) return (ChannelRef.id, s);
    final h = RegExp(r'^@?([^\s/?#@]+)$').firstMatch(s)?.group(1);
    return h == null ? null : (ChannelRef.handle, _decode(h));
  }
  String? m(String p) => RegExp(p).firstMatch(url)?.group(1);
  final id = m(r'/channel/(UC[\w-]{22})');
  if (id != null) return (ChannelRef.id, id);
  final h = m(r'/@([^/?#\s]+)');
  if (h != null) return (ChannelRef.handle, _decode(h));
  final v = m(r'youtu\.be/([\w-]{11})') ??
      m(r'[?&]v=([\w-]{11})') ??
      m(r'/(?:shorts|live|embed)/([\w-]{11})');
  return v == null ? null : (ChannelRef.video, v);
}

String _decode(String h) {
  try {
    return Uri.decodeComponent(h);
  } catch (_) {
    return h;
  }
}

String? channelIdFromHtml(String html) =>
    RegExp(r'videos\.xml\?channel_id=(UC[\w-]{22})').firstMatch(html)?.group(1) ??
    RegExp(r'"externalId":"(UC[\w-]{22})"').firstMatch(html)?.group(1) ??
    RegExp(r'"channelId":"(UC[\w-]{22})"').firstMatch(html)?.group(1); // 영상 페이지

String? feedTitle(String xml) {
  try {
    return XmlDocument.parse(xml).rootElement.getElement('title')?.innerText.trim();
  } catch (_) {
    return null;
  }
}

List<YtVideo> parseFeed(String xml) {
  final out = <YtVideo>[];
  for (final e in XmlDocument.parse(xml).findAllElements('entry')) {
    final id = e.getElement('yt:videoId')?.innerText.trim();
    final title = e.getElement('title')?.innerText.trim();
    final pub = DateTime.tryParse(e.getElement('published')?.innerText.trim() ?? '');
    final url = e.findElements('link').map((l) => l.getAttribute('href')).firstWhere(
        (h) => h != null, orElse: () => null);
    if (id == null || title == null || pub == null) continue;
    out.add(YtVideo(id, title, url ?? 'https://www.youtube.com/watch?v=$id', pub));
  }
  return out;
}

List<YtVideo> recentVideos(List<YtVideo> v, DateTime now,
        {Duration window = const Duration(hours: 24)}) =>
    v.where((x) => !x.published.isBefore(now.subtract(window))).toList()
      ..sort((a, b) => b.published.compareTo(a.published));

class YoutubeSource {
  final http.Client _c;
  YoutubeSource(this._c);

  // 채널·영상 페이지는 ~1MB라 모바일 데이터에서 5초로는 모자라다.
  Future<String> _get(String url, {int secs = 15}) async {
    final r = await _c
        .get(Uri.parse(url), headers: {'User-Agent': _ua}).timeout(Duration(seconds: secs));
    if (r.statusCode != 200) throw http.ClientException('${r.statusCode}');
    return utf8.decode(r.bodyBytes, allowMalformed: true);
  }

  Future<String> _feed(String id, {int secs = 15}) =>
      _get('https://www.youtube.com/feeds/videos.xml?channel_id=$id', secs: secs);

  /// 못 찾으면 null
  Future<YtChannel?> resolve(String input) async {
    try {
      final ref = parseChannelInput(input);
      if (ref == null) return null;
      final String? id = switch (ref.$1) {
        ChannelRef.id => ref.$2,
        ChannelRef.handle =>
          channelIdFromHtml(await _get('https://www.youtube.com/@${Uri.encodeComponent(ref.$2)}')),
        ChannelRef.video => channelIdFromHtml(await _get('https://www.youtube.com/watch?v=${ref.$2}')),
      };
      if (id == null) return null;
      final name = feedTitle(await _feed(id));
      return name == null || name.isEmpty ? null : YtChannel(id, name);
    } catch (_) {
      return null;
    }
  }

  /// 새 영상이 있는 채널만. 전부 실패하면 null.
  Future<ChannelVideos?> newVideos(List<YtChannel> channels, DateTime now) async {
    final rs = await Future.wait(channels.map((ch) async {
      try {
        return (ch, recentVideos(parseFeed(await _feed(ch.id, secs: 5)), now));
      } catch (_) {
        return null;
      }
    }));
    final ok = rs.whereType<(YtChannel, List<YtVideo>)>().toList();
    if (ok.isEmpty && channels.isNotEmpty) return null;
    return ok.where((r) => r.$2.isNotEmpty).toList();
  }
}
