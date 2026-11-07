import { kstDate } from './kst.js';

export interface Store {
  incr(key: string): Promise<number>;
  expire(key: string, sec: number): Promise<unknown>;
}

// Supabase RPC(public.incr_counter, supabase/schema.sql)로 원자적으로 센다. 만료는 SQL 함수가 정리하므로 expire는 할 일이 없다.
export function supabaseStore(url: string, key: string, fetchFn: typeof fetch = fetch): Store {
  return {
    async incr(k) {
      const r = await fetchFn(`${url.replace(/\/$/, '')}/rest/v1/rpc/incr_counter`, {
        method: 'POST',
        headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_key: k }),
      });
      if (!r.ok) throw new Error(`supabase ${r.status}`);
      const n = await r.json();
      if (typeof n !== 'number') throw new Error('supabase: 숫자가 아닌 응답');
      return n;
    },
    async expire() {},
  };
}

let store: Store | undefined;
export function defaultStore(): Store {
  // 지연 생성: 테스트에서 네트워크·환경변수 불필요. 환경변수가 없으면 호출 때 오류가 나 fail open/closed 규칙을 탄다.
  return (store ??= supabaseStore(process.env.SUPABASE_URL ?? '', process.env.SUPABASE_SERVICE_KEY ?? ''));
}

export function memoryStore(): Store & { ttl: Map<string, number> } {
  const m = new Map<string, number>(), ttl = new Map<string, number>();
  return {
    ttl,
    async incr(k) { const n = (m.get(k) ?? 0) + 1; m.set(k, n); return n; },
    async expire(k, sec) { ttl.set(k, sec); },
  };
}

export async function incrDaily(
  name: string, limit: number, now: Date = new Date(), store: Store = defaultStore(),
): Promise<{ count: number; allowed: boolean }> {
  const key = `${name}:${kstDate(now)}`;
  const count = await store.incr(key);
  if (count === 1) await store.expire(key, 2 * 86400);
  return { count, allowed: count <= limit };
}

// 비용이 없는 호출용 상한: 카운터(DB) 장애면 열어 둔다(fail open). 유료 호출(대중교통)만 fail closed.
export async function underCap(name: string, limit: number, now?: Date, store?: Store): Promise<boolean> {
  try { return (await incrDaily(name, limit, now, store)).allowed; }
  catch (e) { console.error(`counter ${name} failed`, e); return true; }
}
