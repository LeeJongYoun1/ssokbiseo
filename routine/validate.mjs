import { readFileSync } from 'node:fs';
import { validateBriefing } from './schema.mjs';

let errs;
try {
  // 루틴은 한국 아침에 돌므로 KST 날짜와 비교한다
  const today = new Date(Date.now() + 9 * 3600e3).toISOString().slice(0, 10);
  errs = validateBriefing(JSON.parse(readFileSync(process.argv[2] ?? 'data/briefing.json', 'utf8')), today);
} catch (e) {
  errs = [`읽기/파싱 실패: ${e.message}`];
}
if (errs.length) { console.error(errs.join('\n')); process.exit(1); }
console.log('OK');
