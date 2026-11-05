import { checkAppKey } from '../lib/auth';
import { kakaoSearch } from '../lib/kakao';

export async function GET(req: Request): Promise<Response> {
  if (!checkAppKey(req)) return Response.json({ error: 'unauthorized' }, { status: 401 });
  const q = new URL(req.url).searchParams.get('q')?.trim();
  if (!q) return Response.json({ error: 'bad q' }, { status: 400 });
  try {
    return Response.json({ items: await kakaoSearch(q) });
  } catch {
    return Response.json({ error: 'kakao upstream error' }, { status: 502 });
  }
}
