typedef Community = ({String key, String label, String pointsLabel});

/// 홈 커뮤니티 카드 순서이자 설정 목록. pointsLabel: '점'은 숫자 뒤, 나머지는 숫자 앞에 붙는다.
const List<Community> kCommunities = [
  (key: 'geeknews', label: 'GeekNews', pointsLabel: '점'),
  (key: 'ppomppu', label: '뽐뿌', pointsLabel: '추천'),
  (key: 'ruliweb', label: '루리웹', pointsLabel: '추천'),
  (key: '82cook', label: '82cook', pointsLabel: '조회'),
];

/// 홈 세무 소식 카드 순서이자 설정 목록.
const List<Community> kTaxSources = [
  (key: 'sejungilbo', label: '세정일보', pointsLabel: ''),
  (key: 'nts_press', label: '국세청 보도자료', pointsLabel: '조회'),
  (key: 'nts_notice', label: '국세청 공지사항', pointsLabel: '조회'),
];

const kTopics = ['경제', '재테크', '세무', '부동산', '건강', 'IT', '정치', '사회', '국제', '과학', '스포츠', '연예'];

typedef Mood = ({String key, String label});
typedef Tone = ({String key, String label});

const List<Mood> kMoods = [
  (key: 'good', label: '좋음'),
  (key: 'tired', label: '피곤'),
  (key: 'worried', label: '걱정'),
  (key: 'down', label: '우울'),
  (key: 'eager', label: '의욕'),
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

class CommunityItem {
  final String title, summary, url;
  final int? points;
  final String? discussUrl;
  const CommunityItem(this.title, this.points, this.summary, this.url, [this.discussUrl]);
  factory CommunityItem.fromJson(Map<String, dynamic> j) => CommunityItem(
      j['title'] as String? ?? '',
      (j['points'] as num?)?.toInt(),
      j['summary'] as String? ?? '',
      j['url'] as String? ?? '',
      j['discussUrl'] as String?);
}

class Briefing {
  final String date;
  final Map<String, List<NewsItem>> news;
  final Map<String, Map<String, String>> advice;
  final Map<String, List<CommunityItem>> community;
  final Map<String, List<CommunityItem>> tax;
  const Briefing(this.date, this.news, this.advice, this.community, [this.tax = const {}]);

  List<CommunityItem> get geeknews => community['geeknews'] ?? const [];

  static Briefing fromJson(Map<String, dynamic> j) {
    final rawNews = (j['news'] as Map?) ?? {};
    // 옛 파일: 최상위 geeknews만 있으면 community.geeknews로 본다.
    final rawCom = (j['community'] as Map?) ?? {'geeknews': j['geeknews']};
    final rawTax = (j['tax'] as Map?) ?? {};
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
      {
        for (final c in kCommunities)
          if (rawCom[c.key] is List)
            c.key: [
              for (final e in rawCom[c.key] as List)
                CommunityItem.fromJson(Map<String, dynamic>.from(e as Map))
            ]
      },
      {
        for (final c in kTaxSources)
          if (rawTax[c.key] is List)
            c.key: [
              for (final e in rawTax[c.key] as List)
                CommunityItem.fromJson(Map<String, dynamic>.from(e as Map))
            ]
      },
    );
  }
}
