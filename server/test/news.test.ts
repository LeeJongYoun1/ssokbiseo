import { afterEach, expect, test, vi } from 'vitest';
import { cleanText } from '../lib/clean.js';
import { TOPICS } from '../lib/topics.js';
import { GET } from '../api/news-raw.js';

process.env.SSOK_ROUTINE_KEY = 'r';
const rq = (key = 'r') => new Request('http://x/api/news-raw', { headers: { 'x-ssok-routine-key': key } });
const item = { title: '<b>삼성</b> &quot;반도체&quot;', originallink: 'https://orig/1', link: 'https://n.news.naver.com/a', description: 'd &amp; e', pubDate: 'Thu, 05 Nov 2026 06:00:00 +0900' };
afterEach(() => vi.unstubAllGlobals());

test('cleanText: 태그 제거, 엔티티 해제, 공백 정리', () => {
  expect(cleanText('<b>삼성</b> &quot;반도체&quot; 회복&amp;')).toBe('삼성 "반도체" 회복&');
  expect(cleanText(' a &lt;b&gt; &#39;x&#39; &apos;y&apos; &#65;&#x42;\n\n c ')).toBe("a <b> 'x' 'y' AB c");
});

test('주제 12개 모두 키로 있고, 각 display=10&sort=date로 호출', async () => {
  const f = vi.fn(async (_u: string, _o?: any) => new Response(JSON.stringify({ items: [item] })));
  vi.stubGlobal('fetch', f);
  const j = await GET(rq()).then((r) => r.json());
  expect(Object.keys(j.topics)).toEqual([...TOPICS]);
  expect(TOPICS).toHaveLength(12);
  expect(j.date).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  expect(f).toHaveBeenCalledTimes(12);
  const u = f.mock.calls[0][0];
  expect(u).toContain('display=10');
  expect(u).toContain('sort=date');
  expect(f.mock.calls[0][1].headers['X-Naver-Client-Id']).toBeDefined();
  expect(j.topics['경제'][0]).toEqual({ title: '삼성 "반도체"', description: 'd & e', link: 'https://n.news.naver.com/a', pubDate: item.pubDate });
});

test('네이버 뉴스 링크가 아니면 originallink', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response(JSON.stringify({ items: [{ ...item, link: 'https://other/x' }] }))));
  const j = await GET(rq()).then((r) => r.json());
  expect(j.topics['경제'][0].link).toBe('https://orig/1');
});

test('한 주제가 실패(throw/비정상 status)하면 그 주제만 빈 배열', async () => {
  vi.stubGlobal('fetch', vi.fn(async (u: string) => {
    if (u.includes(encodeURIComponent('경제'))) throw new Error('x');
    if (u.includes(encodeURIComponent('IT'))) return new Response('no', { status: 429 });
    return new Response(JSON.stringify({ items: [item] }));
  }));
  const r = await GET(rq());
  const j = await r.json();
  expect(r.status).toBe(200);
  expect(j.topics['경제']).toEqual([]);
  expect(j.topics['IT']).toEqual([]);
  expect(j.topics['정치']).toHaveLength(1);
});

test('전부 실패하면 502', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 401 })));
  expect((await GET(rq())).status).toBe(502);
});

test('routine 키가 틀리면 401', async () => {
  const f = vi.fn();
  vi.stubGlobal('fetch', f);
  expect((await GET(rq('bad'))).status).toBe(401);
  expect(f).not.toHaveBeenCalled();
});
