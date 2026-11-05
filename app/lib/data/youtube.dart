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

/// 채널 id(UC…) 또는 핸들(@이름) 또는 null
String? parseChannelInput(String raw) {
  final s = raw.trim();
  final id = RegExp(r'/channel/(UC[\w-]{22})').firstMatch(s)?.group(1);
  if (id != null) return id;
  if (RegExp(r'^UC[\w-]{22}$').hasMatch(s)) return s;
  final isUrl = RegExp(r'^(https?://)?(www\.|m\.)?youtube\.com/').hasMatch(s);
  return isUrl
      ? RegExp(r'youtube\.com/(@[\w.\-]+)').firstMatch(s)?.group(1)
      : RegExp(r'^(@[\w.\-]+)$').firstMatch(s)?.group(1);
}

String? channelIdFromHtml(String html) =>
    RegExp(r'videos\.xml\?channel_id=(UC[\w-]{22})').firstMatch(html)?.group(1) ??
    RegExp(r'"externalId":"(UC[\w-]{22})"').firstMatch(html)?.group(1);

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

  Future<String> _get(String url) async {
    final r = await _c
        .get(Uri.parse(url), headers: {'User-Agent': _ua}).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw http.ClientException('${r.statusCode}');
    return utf8.decode(r.bodyBytes, allowMalformed: true);
  }

  Future<String> _feed(String id) => _get('https://www.youtube.com/feeds/videos.xml?channel_id=$id');

  /// 못 찾으면 null
  Future<YtChannel?> resolve(String input) async {
    try {
      var id = parseChannelInput(input);
      if (id == null) return null;
      if (id.startsWith('@')) {
        id = channelIdFromHtml(await _get('https://www.youtube.com/$id'));
        if (id == null) return null;
      }
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
        return (ch, recentVideos(parseFeed(await _feed(ch.id)), now));
      } catch (_) {
        return null;
      }
    }));
    final ok = rs.whereType<(YtChannel, List<YtVideo>)>().toList();
    if (ok.isEmpty && channels.isNotEmpty) return null;
    return ok.where((r) => r.$2.isNotEmpty).toList();
  }
}
