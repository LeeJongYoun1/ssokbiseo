import { checkAppKey } from '../lib/auth.js';
import { defaultStore, incrDaily, underCap, type Store } from '../lib/counter.js';
import { kakaoCarMinutes, kakaoTransitMinutes } from '../lib/kakao.js';

const json = (b: unknown, status = 200) => Response.json(b, { status });
const inKr = (lat: number, lon: number) => lat >= 33 && lat <= 39 && lon >= 124 && lon <= 132;

export function makeRouteHandler(o: { store?: Store; now?: () => Date } = {}) {
  return async (req: Request): Promise<Response> => {
    if (!checkAppKey(req)) return json({ error: 'unauthorized' }, 401);
    const p = new URL(req.url).searchParams;
    const [fa, fo, ta, to] = ['fromLat', 'fromLon', 'toLat', 'toLon'].map((k) => (p.get(k) ? Number(p.get(k)) : NaN));
    if (![fa, fo, ta, to].every(Number.isFinite) || !inKr(fa, fo) || !inKr(ta, to)) return json({ error: 'bad coords' }, 400);
    const from = { lat: fa, lon: fo }, dest = { lat: ta, lon: to };

    // 카운터(DB) 실패도 "차단"으로 취급 — 유료 호출 방지
    let blocked = true;
    try { blocked = !(await incrDaily('transit', 900, o.now?.() ?? new Date(), o.store ?? defaultStore())).allowed; } catch (e) { console.error('counter transit failed', e); }

    const [carMin, transitMin] = await Promise.all([
      (await underCap('car', 5000, o.now?.(), o.store)) ? kakaoCarMinutes(from, dest) : null,
      blocked ? null : kakaoTransitMinutes(from, dest),
    ]);
    return json({ carMin, transitMin, transitBlocked: blocked });
  };
}

export const GET = makeRouteHandler();
