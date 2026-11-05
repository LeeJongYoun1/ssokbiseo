import { readFileSync } from 'node:fs';
import { validateBriefing } from './schema.mjs';

let errs;
try {
  errs = validateBriefing(JSON.parse(readFileSync(process.argv[2] ?? 'data/briefing.json', 'utf8')));
} catch (e) {
  errs = [`읽기/파싱 실패: ${e.message}`];
}
if (errs.length) { console.error(errs.join('\n')); process.exit(1); }
console.log('OK');
