import { checkAppKey } from '../lib/auth';
import { toGrid } from '../lib/grid';
import { kstDate, kstHM } from '../lib/kst';

const BASE = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/';
const SKY: Record<string, string> = { '1': '맑음', '3': '구름많음', '4': '흐림' };
const PTY: Record<string, string> = { '0': '없음', '1': '비', '2': '비/눈', '3': '눈', '4': '소나기', '5': '비', '6': '비/눈', '7': '눈' };
const ymd = (d: Date) => kstDate(d).replace(/-/g, '');
const json = (b: unknown, status = 200) => Response.json(b, { status });

async function kma(op: string, date: string, time: string, nx: number, ny: number) {
  const q = new URLSearchParams({
    serviceKey: process.env.KMA_SERVICE_KEY ?? '', pageNo: '1', numOfRows: '1000', dataType: 'JSON',
    base_date: date, base_time: time, nx: String(nx), ny: String(ny),
  });
  const r = await fetch(`${BASE}${op}?${q}`);
  const j = await r.json();
  if (j?.response?.header?.resultCode !== '00') throw new Error('kma error');
  return (j.response.body?.items?.item ?? []) as Record<string, string>[];
}

export async function GET(req: Request): Promise<Response> {
  if (!checkAppKey(req)) return json({ error: 'unauthorized' }, 401);
  const p = new URL(req.url).searchParams;
  const lat = Number(p.get('lat')), lon = Number(p.get('lon'));
  if (!p.get('lat') || !p.get('lon') || !Number.isFinite(lat) || !Number.isFinite(lon)
    || Math.abs(lat) > 90 || Math.abs(lon) > 180) return json({ error: 'bad lat/lon' }, 400);
  const { nx, ny } = toGrid(lat, lon);
  const now = new Date();

  // 초단기실황: 매시 정각 기준, ~40분 뒤 제공
  const n = new Date(now.getTime() - 40 * 60_000);
  const nTime = String(kstHM(n).h).padStart(2, '0') + '00';
  // 단기예보: 02,05,...,23시 발표, ~10분 뒤 제공. 02:10 전이면 전날 23시
  const f = new Date(now.getTime() - 10 * 60_000);
  const fh = kstHM(f).h;
  const bh = [23, 20, 17, 14, 11, 8, 5, 2].find((h) => h <= fh);
  const fDate = bh === undefined ? ymd(new Date(f.getTime() - 86400_000)) : ymd(f);
  const fTime = String(bh ?? 23).padStart(2, '0') + '00';

  try {
    const [nc, fc] = await Promise.all([
      kma('getUltraSrtNcst', ymd(n), nTime, nx, ny),
      kma('getVilageFcst', fDate, fTime, nx, ny),
    ]);
    const cur = (c: string) => nc.find((i) => i.category === c)?.obsrValue;
    const today = ymd(now);
    const td = fc.filter((i) => i.fcstDate === today);
    const vals = (c: string) => td.filter((i) => i.category === c).map((i) => i.fcstValue);
    const num = (c: string) => { const v = vals(c)[0]; return v === undefined ? null : Number(v); };
    const cnt: Record<string, number> = {};
    for (const v of vals('SKY')) cnt[v] = (cnt[v] ?? 0) + 1;
    const sky = Object.entries(cnt).sort((a, b) => b[1] - a[1])[0]?.[0];
    const tempC = Number(cur('T1H'));
    if (!Number.isFinite(tempC)) throw new Error('no temp');
    return json({
      tempC,
      sky: SKY[sky ?? ''] ?? '맑음', // 예보 SKY 없으면 맑음으로 대체
      rain: PTY[cur('PTY') ?? '0'] ?? '없음',
      popMax: Math.max(0, ...vals('POP').map(Number)),
      tmin: num('TMN'),
      tmax: num('TMX'),
    });
  } catch {
    return json({ error: 'kma upstream error' }, 502);
  }
}
