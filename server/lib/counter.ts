import { Redis } from '@upstash/redis';
import { kstDate } from './kst';

export interface Store {
  incr(key: string): Promise<number>;
  expire(key: string, sec: number): Promise<unknown>;
}

let redis: Store | undefined;
export function defaultStore(): Store {
  return (redis ??= Redis.fromEnv()); // 지연 생성: 테스트에서 네트워크·환경변수 불필요
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
