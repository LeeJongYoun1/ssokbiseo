// KST는 DST가 없어 UTC+9 고정.
export function kstDate(now: Date = new Date()): string {
  return new Date(now.getTime() + 9 * 3600_000).toISOString().slice(0, 10);
}
