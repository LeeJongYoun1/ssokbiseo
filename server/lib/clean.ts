const NAMED: Record<string, string> = { quot: '"', amp: '&', lt: '<', gt: '>', apos: "'", nbsp: ' ' };

// 태그 제거 → 엔티티 해제(& 마지막 1회) → 공백 정리
export function cleanText(s: string): string {
  return s
    .replace(/<[^>]*>/g, '')
    .replace(/&(?:#(\d+)|#x([0-9a-f]+)|(\w+));/gi, (m, d, h, n) => {
      if (d || h) { try { return String.fromCodePoint(d ? Number(d) : parseInt(h, 16)); } catch { return m; } }
      return NAMED[n.toLowerCase()] ?? m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}
