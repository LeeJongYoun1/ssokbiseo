import 'dart:convert';
import 'package:biseo/data/youtube.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const uc = 'UCabcdefghijklmnopqrstuv';
const feed = '''<?xml version="1.0"?><feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
<title>테스트 채널</title>
<entry><yt:videoId>a1</yt:videoId><title>A &amp; B &quot;x&quot;</title>
<link rel="alternate" href="https://www.youtube.com/watch?v=a1"/><published>2026-11-04T18:00:21+00:00</published></entry>
<entry><yt:videoId>s1</yt:videoId><title>쇼츠</title>
<link rel="alternate" href="https://www.youtube.com/shorts/s1"/><published>2026-11-01T18:00:21+00:00</published></entry></feed>''';

void main() {
  test('parseChannelInput', () {
    for (final s in ['https://www.youtube.com/channel/$uc', 'youtube.com/channel/$uc/videos', uc]) {
      expect(parseChannelInput(s), (ChannelRef.id, uc), reason: s);
    }
    for (final s in [
      'https://www.youtube.com/@name',
      'youtube.com/@name/videos',
      'https://m.youtube.com/@name',
      '@name',
      'name',
      'https://youtube.com/@name?si=abc',
      '  @name ',
      '채널명 https://youtube.com/@name?si=abc',
    ]) {
      expect(parseChannelInput(s), (ChannelRef.handle, 'name'), reason: s);
    }
    for (final s in ['@침착맨', '침착맨', 'https://www.youtube.com/@%EC%B9%A8%EC%B0%A9%EB%A7%A8?si=x']) {
      expect(parseChannelInput(s), (ChannelRef.handle, '침착맨'), reason: s);
    }
    for (final s in [
      'https://youtu.be/dQw4w9WgXcQ?si=abc',
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3',
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://youtube.com/shorts/dQw4w9WgXcQ?si=1',
      '영상 제목 https://youtu.be/dQw4w9WgXcQ',
    ]) {
      expect(parseChannelInput(s), (ChannelRef.video, 'dQw4w9WgXcQ'), reason: s);
    }
    expect(parseChannelInput('hello world'), null);
    expect(parseChannelInput('https://example.com/@x'), null);
    expect(parseChannelInput(''), null);
  });

  test('parseFeed', () {
    final v = parseFeed(feed);
    expect(v.length, 2);
    expect(v[0].title, 'A & B "x"');
    expect(v[0].id, 'a1');
    expect(v[1].url, 'https://www.youtube.com/shorts/s1');
    expect(v[0].published, DateTime.utc(2026, 11, 4, 18, 0, 21));
    expect(feedTitle(feed), '테스트 채널');
  });

  test('recentVideos 24h, newest first', () {
    final now = DateTime.utc(2026, 11, 5, 12);
    final v = parseFeed(feed);
    expect(recentVideos(v, now).map((x) => x.id), ['a1']);
    expect(recentVideos(v, now, window: const Duration(days: 10)).map((x) => x.id), ['a1', 's1']);
    expect(recentVideos(v, DateTime.utc(2026, 11, 6)), isEmpty);
  });

  test('channelIdFromHtml', () {
    expect(channelIdFromHtml('<link href="https://www.youtube.com/feeds/videos.xml?channel_id=$uc">'), uc);
    expect(channelIdFromHtml('{"externalId":"$uc"}'), uc);
    expect(channelIdFromHtml('"channelId":"$uc"'), uc);
    expect(channelIdFromHtml('<html/>'), null);
  });

  test('YoutubeSource resolve / newVideos', () async {
    final c = MockClient((r) async {
      if (r.url.path == '/watch' && r.url.queryParameters['v'] == 'dQw4w9WgXcQ') {
        return http.Response('"channelId":"$uc"', 200);
      }
      if (Uri.decodeComponent(r.url.path) == '/@침착맨') return http.Response('"externalId":"$uc"', 200);
      if (r.url.path == '/@name') return http.Response('"externalId":"$uc"', 200);
      if (r.url.queryParameters['channel_id'] == uc) return http.Response.bytes(utf8.encode(feed), 200);
      return http.Response('no', 404);
    });
    final s = YoutubeSource(c);
    expect((await s.resolve('@name'))!.id, uc);
    expect((await s.resolve('@name'))!.name, '테스트 채널');
    expect((await s.resolve('https://www.youtube.com/@%EC%B9%A8%EC%B0%A9%EB%A7%A8'))!.id, uc);
    expect((await s.resolve('침착맨'))!.id, uc);
    expect((await s.resolve('https://youtu.be/dQw4w9WgXcQ?si=a'))!.id, uc);
    expect(await s.resolve('@nope'), null);
    expect(await s.resolve('zzz'), null);
    final now = DateTime.utc(2026, 11, 5, 12);
    const bad = YtChannel('UCbbbbbbbbbbbbbbbbbbbbbb', 'bad');
    final r = await s.newVideos([const YtChannel(uc, 'ok'), bad], now);
    expect(r!.length, 1);
    expect(r[0].$2.single.id, 'a1');
    expect(await s.newVideos([bad], now), null);
  });
}
