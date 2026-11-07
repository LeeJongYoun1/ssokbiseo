import { checkRoutineKey } from '../lib/auth.js';
import { cleanText } from '../lib/clean.js';
import { kstDate } from '../lib/kst.js';
import { TOPICS } from '../lib/topics.js';

type Item = { title: string; description: string; link: string; pubDate: string };
const json = (b: unknown, status = 200) => Response.json(b, { status });

async function search(topic: string): Promise<Item[]> {
  // NAVER API HUB (옛 개발자센터 openapi.naver.com/v1/search/news.json 과는 키·주소·헤더가 다르다)
  const res = await fetch(`https://naverapihub.apigw.ntruss.com/search/v1/news?query=${encodeURIComponent(topic)}&display=10&sort=date`, {
    headers: {
      'X-NCP-APIGW-API-KEY-ID': process.env.NAVER_CLIENT_ID ?? '',
      'X-NCP-APIGW-API-KEY': process.env.NAVER_CLIENT_SECRET ?? '',
    },
  });
  if (!res.ok) throw new Error(`naver ${res.status}`);
  const j = await res.json();
  return (j.items ?? []).map((i: any) => ({
    title: cleanText(String(i.title ?? '')),
    description: cleanText(String(i.description ?? '')),
    link: String(i.link ?? '').startsWith('https://n.news.naver.com/') ? i.link : i.originallink || i.link || '',
    pubDate: String(i.pubDate ?? ''),
  }));
}

export async function GET(req: Request): Promise<Response> {
  if (!checkRoutineKey(req)) return json({ error: 'unauthorized' }, 401);
  const results = await Promise.allSettled(TOPICS.map(search));
  // 전부 실패 = 키/쿼터 문제 → 루틴이 눈치채도록 502
  if (results.every((r) => r.status === 'rejected')) {
    // 상태 코드만 노출(키 값은 없음): 401=ID/Secret 오류, 403=검색 API 미설정, 429=쿼터
    const why = [...new Set(results.map((r) => (r as PromiseRejectedResult).reason?.message ?? 'unknown'))];
    return json({ error: 'naver upstream error', why }, 502);
  }
  const topics = Object.fromEntries(TOPICS.map((t, i) => {
    const r = results[i];
    return [t, r.status === 'fulfilled' ? r.value : []];
  }));
  return json({ date: kstDate(), topics });
}
