import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validateBriefing } from './schema.mjs';

const sample = JSON.parse(readFileSync(new URL('../data/briefing.json', import.meta.url), 'utf8'));
const item = { title: 't', summary: 's', url: 'https://a.b/c' };

test('sample passes', () => assert.deepEqual(validateBriefing(sample), []));
test('empty advice', () => assert.ok(validateBriefing({ ...sample, advice: {} }).some(e => e.includes('advice.good'))));
test('11 items', () => assert.ok(validateBriefing({ ...sample, news: { 경제: Array(11).fill(item) } }).length > 0));
test('bad date', () => assert.ok(validateBriefing({ ...sample, date: '2026/11/06' }).length > 0));
test('http url path', () => {
  const e = validateBriefing({ ...sample, news: { 경제: [item, item, item, { ...item, url: 'http://x' }] } });
  assert.ok(e.some(m => m.includes('news.경제[3].url')));
});
test('unknown topic', () => assert.ok(validateBriefing({ ...sample, news: { 먹방: [] } }).some(e => e.includes('먹방'))));
test('geeknews bad', () => {
  const e = validateBriefing({ ...sample, geeknews: [{ title: 'a', points: '3', summary: 's', url: 'https://a', discussUrl: 'x' }] });
  assert.ok(e.some(m => m.includes('geeknews[0].points')) && e.some(m => m.includes('geeknews[0].discussUrl')));
});
test('not object', () => assert.ok(validateBriefing(null).length > 0));
