import { describe, expect, test, vi } from 'vitest';
import { supabaseStore } from '../lib/counter';

const res = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status });

describe('supabaseStore', () => {
  test('RPC로 키를 보내고 숫자를 돌려준다', async () => {
    const f = vi.fn(async () => res(3));
    const n = await supabaseStore('https://x.supabase.co/', 'svc', f as any).incr('weather:2026-11-07');
    expect(n).toBe(3);
    const [url, init] = f.mock.calls[0] as any;
    expect(url).toBe('https://x.supabase.co/rest/v1/rpc/incr_counter');
    expect(JSON.parse(init.body)).toEqual({ p_key: 'weather:2026-11-07' });
    expect(init.headers.apikey).toBe('svc');
  });
  test('HTTP 오류면 던진다', async () => {
    await expect(supabaseStore('https://x', 'k', (async () => res({}, 401)) as any).incr('a')).rejects.toThrow('401');
  });
  test('숫자가 아닌 응답이면 던진다', async () => {
    await expect(supabaseStore('https://x', 'k', (async () => res({ a: 1 })) as any).incr('a')).rejects.toThrow();
  });
});
