import { checkRoutineKey } from '../lib/auth';
import { cleanText } from '../lib/clean';
import { kstDate } from '../lib/kst';
import { TOPICS } from '../lib/topics';

type Item = { title: string; description: string; link: string; pubDate: string };
const json = (b: unknown, status = 200) => Response.json(b, { status });

async function search(topic: string): Promise<Item[]> {
  const res = await fetch(`https://openapi.naver.com/v1/search/news.json?query=${encodeURIComponent(topic)}&display=10&sort=date`, {
    headers: {
      'X-Naver-Client-Id': process.env.NAVER_CLIENT_ID ?? '',
      'X-Naver-Client-Secret': process.env.NAVER_CLIENT_SECRET ?? '',
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
  if (results.every((r) => r.status === 'rejected')) return json({ error: 'naver upstream error' }, 502);
  const topics = Object.fromEntries(TOPICS.map((t, i) => {
    const r = results[i];
    return [t, r.status === 'fulfilled' ? r.value : []];
  }));
  return json({ date: kstDate(), topics });
}
