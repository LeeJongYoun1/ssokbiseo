import { checkAppKey } from '../lib/auth.js';
import { underCap, type Store } from '../lib/counter.js';
import { kakaoSearch } from '../lib/kakao.js';

export function makeGeocodeHandler(o: { store?: Store; now?: () => Date } = {}) {
  return async (req: Request): Promise<Response> => {
  if (!checkAppKey(req)) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const q = new URL(req.url).searchParams.get('q')?.trim();
  if (!q) return Response.json({ error: 'bad q' }, { status: 400 });
  if (!(await underCap('geocode', 2000, o.now?.(), o.store))) return Response.json({ error: 'limit' }, { status: 429 });
  try {
    return Response.json({ items: await kakaoSearch(q) });
  } catch {
    return Response.json({ error: 'kakao upstream error' }, { status: 502 });
  }
}
}

export const GET = makeGeocodeHandler();
