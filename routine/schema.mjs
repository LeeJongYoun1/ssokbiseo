export const TOPICS = ['경제', '재테크', '세무', '부동산', '건강', 'IT', '정치', '사회', '국제', '과학', '스포츠', '연예'];
export const COMMUNITIES = ['geeknews', 'ppomppu', 'ruliweb', '82cook'];
export const MOODS = ['good', 'tired', 'worried', 'down', 'eager'];
export const TONES = ['friend', 'coach', 'quote', 'action'];

const str = (v) => typeof v === 'string' && v.trim() !== '';
const https = (v) => str(v) && v.startsWith('https://');
const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);

export function validateBriefing(b) {
  const errs = [];
  if (!isObj(b)) return ['briefing: 객체가 아닙니다'];

  if (typeof b.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(b.date) || isNaN(Date.parse(b.date)))
    errs.push('date: YYYY-MM-DD 형식이어야 합니다');
  if (typeof b.generatedAt !== 'string' || isNaN(Date.parse(b.generatedAt)))
    errs.push('generatedAt: ISO 시각 문자열이어야 합니다');

  if (!isObj(b.news)) errs.push('news: 객체가 아닙니다');
  else for (const [topic, arr] of Object.entries(b.news)) {
    if (!TOPICS.includes(topic)) { errs.push(`news.${topic}: 알 수 없는 주제`); continue; }
    if (!Array.isArray(arr) || arr.length > 10) { errs.push(`news.${topic}: 0~10개 배열이어야 합니다`); continue; }
    arr.forEach((it, i) => {
      const p = `news.${topic}[${i}]`;
      if (!isObj(it)) return errs.push(`${p}: 객체가 아닙니다`);
      if (!str(it.title)) errs.push(`${p}.title: 비어 있습니다`);
      if (!str(it.summary)) errs.push(`${p}.summary: 비어 있습니다`);
      if (!https(it.url)) errs.push(`${p}.url: https:// 로 시작해야 합니다`);
    });
  }

  if (!isObj(b.advice)) errs.push('advice: 객체가 아닙니다');
  for (const m of MOODS) {
    const a = isObj(b.advice) ? b.advice[m] : undefined;
    if (!isObj(a)) { errs.push(`advice.${m}: 없습니다`); continue; }
    for (const t of TONES) if (!str(a[t])) errs.push(`advice.${m}.${t}: 비어 있습니다`);
  }

  if (!isObj(b.community)) errs.push('community: 객체가 아닙니다');
  else for (const [key, arr] of Object.entries(b.community)) {
    if (!COMMUNITIES.includes(key)) { errs.push(`community.${key}: 알 수 없는 커뮤니티`); continue; }
    if (!Array.isArray(arr) || arr.length > 10) { errs.push(`community.${key}: 0~10개 배열이어야 합니다`); continue; }
    arr.forEach((g, i) => {
      const p = `community.${key}[${i}]`;
      if (!isObj(g)) return errs.push(`${p}: 객체가 아닙니다`);
      if (!str(g.title)) errs.push(`${p}.title: 비어 있습니다`);
      if (g.points !== null && (typeof g.points !== 'number' || !Number.isFinite(g.points))) errs.push(`${p}.points: 숫자 또는 null이어야 합니다`);
      if (!str(g.summary)) errs.push(`${p}.summary: 비어 있습니다`);
      if (!https(g.url)) errs.push(`${p}.url: https:// 로 시작해야 합니다`);
      if (g.discussUrl !== null && !https(g.discussUrl)) errs.push(`${p}.discussUrl: null 또는 https:// 로 시작해야 합니다`);
    });
  }
  return errs;
}
