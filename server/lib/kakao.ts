// 카카오 REST 호출 모음. 헤더: Authorization: KakaoAK ${KAKAO_REST_KEY}
// 대중교통 경로 조회 (문서 확인 2026-11-05):
//   https://developers.kakao.com/docs/ko/kakaomap/rest-api#transit-info
//   GET https://dapi.kakao.com/v2/routing/publictraffic
//   params: start_x(경도) start_y(위도) end_x end_y (WGS84 기본)
//   소요 시간: routes[i].properties.totalTime (초, 경로마다 있음) → 가장 짧은 경로를 분으로.
//   status 가 OK 아니면 routes 없음.
// 자동차: https://apis-navi.kakaomobility.com/v1/directions → routes[0].summary.duration (초)
export type LL = { lat: number; lon: number };

const auth = () => ({ Authorization: `KakaoAK ${process.env.KAKAO_REST_KEY ?? ''}` });
const get = async (url: string) => (await fetch(url, { headers: auth() })).json();
const min = (sec: number) => Math.round(sec / 60);

export async function kakaoCarMinutes(from: LL, to: LL): Promise<number | null> {
  try {
    const q = new URLSearchParams({ origin: `${from.lon},${from.lat}`, destination: `${to.lon},${to.lat}` });
    const r = (await get(`https://apis-navi.kakaomobility.com/v1/directions?${q}`)).routes?.[0];
    const s = r?.summary?.duration;
    return r?.result_code === 0 && typeof s === 'number' ? min(s) : null;
  } catch { return null; }
}

export async function kakaoTransitMinutes(from: LL, to: LL): Promise<number | null> {
  try {
    const q = new URLSearchParams({
      start_x: String(from.lon), start_y: String(from.lat), end_x: String(to.lon), end_y: String(to.lat),
    });
    const j = await get(`https://dapi.kakao.com/v2/routing/publictraffic?${q}`);
    if (j.status !== 'OK') return null;
    const ts = (j.routes ?? []).map((r: any) => r?.properties?.totalTime).filter((t: unknown) => typeof t === 'number');
    return ts.length ? min(Math.min(...ts)) : null;
  } catch { return null; }
}

export async function kakaoSearch(q: string) {
  const enc = encodeURIComponent(q);
  let docs = (await get(`https://dapi.kakao.com/v2/local/search/address.json?query=${enc}`)).documents ?? [];
  if (!docs.length) docs = (await get(`https://dapi.kakao.com/v2/local/search/keyword.json?query=${enc}`)).documents ?? [];
  return docs.slice(0, 5).map((d: any) => ({
    name: String(d.place_name || d.address_name),
    address: String(d.road_address_name || d.address_name),
    lat: Number(d.y), lon: Number(d.x),
  }));
}
