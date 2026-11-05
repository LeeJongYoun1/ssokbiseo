import { describe, expect, test, vi, beforeEach, afterEach } from 'vitest';
import { toGrid } from '../lib/grid.js';
import { makeWeatherHandler } from '../api/weather.js';
import { memoryStore } from '../lib/counter.js';
const GET = makeWeatherHandler({ store: memoryStore() });

const ok = (item: unknown[]) => ({ response: { header: { resultCode: '00' }, body: { items: { item } } } });
const ncst = ok([
  { category: 'T1H', obsrValue: '12.3' },
  { category: 'PTY', obsrValue: '1' },
]);
const fcst = ok([
  { category: 'SKY', fcstDate: '20261105', fcstValue: '4' },
  { category: 'SKY', fcstDate: '20261105', fcstValue: '4' },
  { category: 'SKY', fcstDate: '20261105', fcstValue: '1' },
  { category: 'SKY', fcstDate: '20261106', fcstValue: '1' },
  { category: 'POP', fcstDate: '20261105', fcstValue: '30' },
  { category: 'POP', fcstDate: '20261105', fcstValue: '60' },
  { category: 'POP', fcstDate: '20261106', fcstValue: '90' },
  { category: 'TMN', fcstDate: '20261105', fcstValue: '5.0' },
  { category: 'TMX', fcstDate: '20261105', fcstValue: '14.0' },
]);

const req = (qs: string, key = 'k') =>
  new Request('http://x/api/weather?' + qs, { headers: { 'x-ssok-key': key } });
const mockFetch = (n: unknown, f: unknown) =>
  vi.stubGlobal('fetch', vi.fn(async (u: string) =>
    new Response(JSON.stringify(String(u).includes('getUltraSrtNcst') ? n : f))));

beforeEach(() => {
  process.env.SSOK_APP_KEY = 'k';
  process.env.KMA_SERVICE_KEY = 'svc';
  vi.useFakeTimers();
  vi.setSystemTime(new Date('2026-11-05T03:00:00Z')); // KST 12:00
});
afterEach(() => { vi.useRealTimers(); vi.unstubAllGlobals(); });

describe('toGrid', () => {
  test('서울·부산', () => {
    expect(toGrid(37.5665, 126.9780)).toEqual({ nx: 60, ny: 127 });
    expect(toGrid(35.1796, 129.0756)).toEqual({ nx: 98, ny: 76 });
  });
});

describe('/api/weather', () => {
  test('계약 모양으로 변환', async () => {
    mockFetch(ncst, fcst);
    const res = await GET(req('lat=37.5665&lon=126.978'));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ tempC: 12.3, sky: '흐림', rain: '비', popMax: 60, tmin: 5, tmax: 14 });
    const urls = (fetch as any).mock.calls.map((c: any[]) => String(c[0]));
    expect(urls[0]).toContain('nx=60');
    expect(urls.join()).toMatch(/base_time=1100/); // 12:00 → 단기예보 1100
  });
  test('TMN/TMX 없으면 null', async () => {
    mockFetch(ncst, ok([{ category: 'SKY', fcstDate: '20261105', fcstValue: '3' }]));
    const j = await (await GET(req('lat=37.5&lon=127'))).json();
    expect(j).toMatchObject({ sky: '구름많음', popMax: 0, tmin: null, tmax: null });
  });
  test('기상청 오류 코드면 502', async () => {
    mockFetch({ response: { header: { resultCode: '30' } } }, fcst);
    expect((await GET(req('lat=37.5&lon=127'))).status).toBe(502);
  });
  test('fetch 실패면 502', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new Error('net'); }));
    expect((await GET(req('lat=37.5&lon=127'))).status).toBe(502);
  });
  test('키 오류 401, 좌표 오류 400', async () => {
    expect((await GET(req('lat=37.5&lon=127', 'bad'))).status).toBe(401);
    expect((await GET(req('lat=abc&lon=127'))).status).toBe(400);
    expect((await GET(req('lat=37.5'))).status).toBe(400);
  });
});
