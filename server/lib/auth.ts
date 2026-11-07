import { timingSafeEqual } from 'node:crypto';

function check(req: Request, header: string, envName: string): boolean {
  const expected = process.env[envName];
  const got = req.headers.get(header);
  if (!expected || !got) return false; // 환경변수 미설정이면 항상 거부
  const a = Buffer.from(got), b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

export const checkAppKey = (req: Request) => check(req, 'x-ssok-key', 'SSOK_APP_KEY');
export const checkRoutineKey = (req: Request) => check(req, 'x-ssok-routine-key', 'SSOK_ROUTINE_KEY');
