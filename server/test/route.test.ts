import { afterEach, expect, test, vi } from 'vitest';
import { memoryStore } from '../lib/counter';
import { makeRouteHandler } from '../api/route';
import { GET as geocode } from '../api/geocode';

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
