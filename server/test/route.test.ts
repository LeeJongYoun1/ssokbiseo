import { afterEach, expect, test, vi } from 'vitest';
import { memoryStore } from '../lib/counter.js';
import { makeRouteHandler } from '../api/route.js';
import { makeGeocodeHandler } from '../api/geocode.js';
const geocode = makeGeocodeHandler({ store: memoryStore() });

process.env.SSOK_APP_KEY = 'k';
const H = { 'x-ssok-key': 'k' };
const rq = (path: string) => new Request(`http://x/api/${path}`, { headers: H });
const ROUTE = 'route?fromLat=37.5&fromLon=127&toLat=37.4&toLon=127.1';
const ok = (b: unknown) => new Response(JSON.stringify(b));
afterEach(() => vi.unstubAllGlobals());

function stub(car: unknown, transit: unknown) {
  const f = vi.fn(async (u: string) => {
    if (u.includes('kakaomobility')) { if (car === 'fail') throw new Error('x'); return ok(car); }
    return ok(transit);
  });
  vi.stubGlobal('fetch', f);
  return f;
}
const carOk = { routes: [{ result_code: 0, summary: { duration: 1500 } }] };
const trOk = { status: 'OK', routes: [{ properties: { totalTime: 2115 } }, { properties: { totalTime: 1800 } }] };

test('자동차: summary.duration(초) 1500 → carMin 25', async () => {
  stub(carOk, trOk);
  const j = await makeRouteHandler({ store: memoryStore() })(rq(ROUTE)).then((r) => r.json());
  expect(j).toEqual({ carMin: 25, transitMin: 30, transitBlocked: false });
});

test('대중교통 900건 넘으면 카카오를 부르지 않고 transitBlocked=true, transitMin=null', async () => {
  const f = stub(carOk, trOk);
  const store = memoryStore();
  for (let i = 0; i < 900; i++) await store.incr(`transit:${new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 10)}`);
  const j = await makeRouteHandler({ store })(rq(ROUTE)).then((r) => r.json());
  expect(j).toMatchObject({ carMin: 25, transitMin: null, transitBlocked: true });
  expect(f.mock.calls.some((c) => String(c[0]).includes('routing'))).toBe(false);
});

test('카운터 실패 시에도 죽지 않고 차단 처리', async () => {
  stub(carOk, trOk);
  const store = { incr: async () => { throw new Error('no redis'); }, expire: async () => 0 };
  const j = await makeRouteHandler({ store })(rq(ROUTE)).then((r) => r.json());
  expect(j).toMatchObject({ transitMin: null, transitBlocked: true });
});

test('자동차 실패해도 대중교통 결과는 돌려줌(부분 실패)', async () => {
  stub('fail', trOk);
  const j = await makeRouteHandler({ store: memoryStore() })(rq(ROUTE)).then((r) => r.json());
  expect(j).toEqual({ carMin: null, transitMin: 30, transitBlocked: false });
});

test('geocode: 주소 검색 결과 0건이면 키워드 검색으로 다시, 최대 5개', async () => {
  const docs = Array.from({ length: 7 }, (_, i) => ({ place_name: `p${i}`, road_address_name: '', address_name: `a${i}`, x: '127.1', y: '37.4' }));
  const f = vi.fn(async (u: string) => ok(u.includes('address.json') ? { documents: [] } : { documents: docs }));
  vi.stubGlobal('fetch', f);
  const j = await geocode(rq('geocode?q=카페')).then((r) => r.json());
  expect(f).toHaveBeenCalledTimes(2);
  expect(j.items).toHaveLength(5);
  expect(j.items[0]).toEqual({ name: 'p0', address: 'a0', lat: 37.4, lon: 127.1 });
});

test('좌표 범위 밖(lat 33~39, lon 124~132 아님)이면 400', async () => {
  stub(carOk, trOk);
  const r = await makeRouteHandler({ store: memoryStore() })(rq('route?fromLat=10&fromLon=127&toLat=37.4&toLon=127.1'));
  expect(r.status).toBe(400);
});

// --- 일일 상한 / 업스트림 오류 ---
import { makeWeatherHandler } from '../api/weather.js';
const today = () => new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 10);
async function filled(name: string, n: number) {
  const s = memoryStore();
  for (let i = 0; i < n; i++) await s.incr(`${name}:${today()}`);
  return s;
}
const brokenStore = { incr: async () => { throw new Error('no redis'); }, expire: async () => 0 };

test('geocode: 카카오 401이면 502', async () => {
  vi.stubGlobal('fetch', vi.fn(async () => new Response('{}', { status: 401 })));
  expect((await geocode(rq('geocode?q=카페'))).status).toBe(502);
});

test('geocode: 2000건 넘으면 429 limit, 카운터 장애면 통과', async () => {
  const f = vi.fn(async () => ok({ documents: [] }));
  vi.stubGlobal('fetch', f);
  const r = await makeGeocodeHandler({ store: await filled('geocode', 2000) })(rq('geocode?q=a'));
  expect([r.status, await r.json()]).toEqual([429, { error: 'limit' }]);
  expect(f).not.toHaveBeenCalled();
  expect((await makeGeocodeHandler({ store: brokenStore })(rq('geocode?q=a'))).status).toBe(200);
});

test('weather: 4000건 넘으면 429 limit, 카운터 장애면 통과', async () => {
  const f = vi.fn(async () => ok({}));
  vi.stubGlobal('fetch', f);
  const W = 'weather?lat=37.5&lon=127';
  const r = await makeWeatherHandler({ store: await filled('weather', 4000) })(rq(W));
  expect([r.status, await r.json()]).toEqual([429, { error: 'limit' }]);
  expect(f).not.toHaveBeenCalled();
  expect((await makeWeatherHandler({ store: brokenStore })(rq(W))).status).not.toBe(429);
});

test('route: 자동차 5000건 넘으면 carMin=null이고 대중교통은 계속', async () => {
  const f = stub(carOk, trOk);
  const store = await filled('car', 5000);
  const j = await makeRouteHandler({ store })(rq(ROUTE)).then((r) => r.json());
  expect(j).toEqual({ carMin: null, transitMin: 30, transitBlocked: false });
  expect(f.mock.calls.some((c) => String(c[0]).includes('kakaomobility'))).toBe(false);
});
