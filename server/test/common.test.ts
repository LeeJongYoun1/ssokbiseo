import { test, expect } from 'vitest';
import { kstDate } from '../lib/kst';
import { incrDaily, memoryStore } from '../lib/counter';
import { checkAppKey, checkRoutineKey } from '../lib/auth';

const NOW = new Date('2026-11-05T03:00:00Z');

test('kstDate는 UTC 15:00을 다음 날로', () => {
  expect(kstDate(new Date('2026-11-05T15:00:00Z'))).toBe('2026-11-06');
  expect(kstDate(new Date('2026-11-05T14:59:59Z'))).toBe('2026-11-05');
});

test('incrDaily는 limit 초과부터 allowed=false', async () => {
  const s = memoryStore();
  for (let i = 0; i < 900; i++) await incrDaily('transit', 900, NOW, s);
  expect((await incrDaily('transit', 900, NOW, s)).allowed).toBe(false);
});

test('limit 이하는 allowed=true, 첫 호출에만 expire 2일', async () => {
  const s = memoryStore();
  const r = await incrDaily('transit', 1, NOW, s);
  expect(r).toEqual({ count: 1, allowed: true });
  expect(s.ttl.get('transit:2026-11-05')).toBe(172800);
});

test('날짜가 바뀌면 카운터 새로 시작', async () => {
  const s = memoryStore();
  await incrDaily('transit', 900, NOW, s);
  await incrDaily('transit', 900, NOW, s);
  const next = await incrDaily('transit', 900, new Date(NOW.getTime() + 86400000), s);
  expect(next.count).toBe(1);
});

const req = (h: Record<string, string>) => new Request('http://x/api', { headers: h });

test('x-ssok-key 틀리면 checkAppKey=false', () => {
  process.env.SSOK_APP_KEY = 'secret';
  expect(checkAppKey(req({ 'x-ssok-key': 'nope' }))).toBe(false);
  expect(checkAppKey(req({}))).toBe(false);
  expect(checkAppKey(req({ 'x-ssok-key': 'secret' }))).toBe(true);
});

test('환경변수가 없으면 키가 비어도 거부', () => {
  delete process.env.SSOK_APP_KEY;
  delete process.env.SSOK_ROUTINE_KEY;
  expect(checkAppKey(req({}))).toBe(false);
  expect(checkRoutineKey(req({ 'x-ssok-routine-key': '' }))).toBe(false);
});

test('checkRoutineKey는 x-ssok-routine-key를 본다', () => {
  process.env.SSOK_ROUTINE_KEY = 'r';
  expect(checkRoutineKey(req({ 'x-ssok-routine-key': 'r' }))).toBe(true);
  expect(checkRoutineKey(req({ 'x-ssok-key': 'r' }))).toBe(false);
});
