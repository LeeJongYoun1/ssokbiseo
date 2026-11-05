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
    expect(await res.json()).toEqual({ tempC: 12.3, sky: '흐림', rain: '비', popMax: 60, tmin: 5, tmax: 14, hourly: [] });
    const urls = (fetch as any).mock.calls.map((c: any[]) => String(c[0]));
    expect(urls[0]).toContain('nx=60');
    expect(urls.join()).toMatch(/base_time=1100/); // 12:00 → 단기예보 1100
  });
  test('hourly: 3시간 간격 6칸, 자정 넘으면 다음 날짜, 빠진 칸은 건너뜀', async () => {
    vi.setSystemTime(new Date('2026-11-05T01:20:00Z')); // KST 10:20
    const row = (d: string, t: string, tmp: string, pty = '0') => [
      { category: 'TMP', fcstDate: d, fcstTime: t, fcstValue: tmp },
      { category: 'SKY', fcstDate: d, fcstTime: t, fcstValue: '3' },
      { category: 'PTY', fcstDate: d, fcstTime: t, fcstValue: pty },
      { category: 'POP', fcstDate: d, fcstTime: t, fcstValue: '30' },
    ];
    mockFetch(ncst, ok([
      ...row('20261105', '1200', '15'), ...row('20261105', '1500', '14', '3'),
      ...row('20261105', '1800', '11', '4'), /* 21시 없음 */
      ...row('20261106', '0000', '7'), ...row('20261106', '0300', '6'),
    ]));
    const j = await (await GET(req('lat=37.5&lon=127'))).json();
    expect(j.hourly.map((h: any) => h.hour)).toEqual([12, 15, 18, 0, 3]);
    expect(j.hourly[0]).toEqual({ hour: 12, tempC: 15, sky: '구름많음', rain: '없음', pop: 30 });
    expect(j.hourly[1].rain).toBe('눈');
    expect(j.hourly[2].rain).toBe('소나기');
    expect(j.hourly[3].tempC).toBe(7); // 다음 날 0시
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
