// KST는 DST가 없어 UTC+9 고정.
export function kstDate(now: Date = new Date()): string {
  return new Date(now.getTime() + 9 * 3600_000).toISOString().slice(0, 10);
}

// KST 기준 시각(분 단위 계산용): 0~23, 0~59.
export function kstHM(now: Date = new Date()): { h: number; m: number } {
  const d = new Date(now.getTime() + 9 * 3600_000);
  return { h: d.getUTCHours(), m: d.getUTCMinutes() };
}
