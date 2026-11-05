// 기상청 DFS 격자 변환 (Lambert Conformal Conic).
export function toGrid(lat: number, lon: number): { nx: number; ny: number } {
  const D = Math.PI / 180;
  const re = 6371.00877 / 5.0;
  const s1 = 30 * D, s2 = 60 * D, olon = 126 * D, olat = 38 * D;
  let sn = Math.log(Math.cos(s1) / Math.cos(s2)) /
    Math.log(Math.tan(Math.PI * 0.25 + s2 * 0.5) / Math.tan(Math.PI * 0.25 + s1 * 0.5));
  const sf = Math.pow(Math.tan(Math.PI * 0.25 + s1 * 0.5), sn) * Math.cos(s1) / sn;
  const ro = re * sf / Math.pow(Math.tan(Math.PI * 0.25 + olat * 0.5), sn);
  const ra = re * sf / Math.pow(Math.tan(Math.PI * 0.25 + lat * D * 0.5), sn);
  let theta = lon * D - olon;
  if (theta > Math.PI) theta -= 2 * Math.PI;
  if (theta < -Math.PI) theta += 2 * Math.PI;
  theta *= sn;
  return {
    nx: Math.floor(ra * Math.sin(theta) + 43 + 0.5),
    ny: Math.floor(ro - ra * Math.cos(theta) + 136 + 0.5),
  };
}
