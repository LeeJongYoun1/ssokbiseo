const kTopics = ['경제', '부동산', '건강', 'IT', '정치', '사회', '국제', '과학', '스포츠', '연예'];

typedef Mood = ({String key, String emoji, String label});
typedef Tone = ({String key, String label});

const List<Mood> kMoods = [
  (key: 'good', emoji: '😊', label: '좋음'),
  (key: 'tired', emoji: '😴', label: '피곤'),
  (key: 'worried', emoji: '😟', label: '걱정'),
  (key: 'down', emoji: '😢', label: '우울'),
  (key: 'eager', emoji: '🔥', label: '의욕'),
];

const List<Tone> kTones = [
  (key: 'friend', label: '다정한 친구'),
  (key: 'coach', label: '짧고 힘 있는 코치'),
  (key: 'quote', label: '명언 인용'),
  (key: 'action', label: '오늘 해 볼 작은 행동'),
];

class NewsItem {
  final String title, summary, url;
  const NewsItem(this.title, this.summary, this.url);
  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
      j['title'] as String? ?? '',
      j['summary'] as String? ?? '',
      j['url'] as String? ?? '');
}

class GeekItem {
  final String title, summary, url, discussUrl;
  final int points;
  const GeekItem(this.title, this.points, this.summary, this.url, this.discussUrl);
  factory GeekItem.fromJson(Map<String, dynamic> j) => GeekItem(
      j['title'] as String? ?? '',
      (j['points'] as num?)?.toInt() ?? 0,
      j['summary'] as String? ?? '',
      j['url'] as String? ?? '',
      j['discussUrl'] as String? ?? '');
}

class Briefing {
  final String date;
  final Map<String, List<NewsItem>> news;
  final Map<String, Map<String, String>> advice;
  final List<GeekItem> geeknews;
  const Briefing(this.date, this.news, this.advice, this.geeknews);

  static Briefing fromJson(Map<String, dynamic> j) {
    final rawNews = (j['news'] as Map?) ?? {};
    final rawAdvice = (j['advice'] as Map?) ?? {};
    return Briefing(
      j['date'] as String? ?? '',
      {
        for (final t in kTopics)
          if (rawNews[t] is List)
            t: [
              for (final e in rawNews[t] as List)
                NewsItem.fromJson(Map<String, dynamic>.from(e as Map))
            ]
      },
      {
        for (final e in rawAdvice.entries)
          e.key as String: {
            for (final t in (e.value as Map).entries)
              t.key as String: t.value as String
          }
      },
      [
        for (final e in (j['geeknews'] as List?) ?? const [])
          GeekItem.fromJson(Map<String, dynamic>.from(e as Map))
      ],
    );
  }
}
