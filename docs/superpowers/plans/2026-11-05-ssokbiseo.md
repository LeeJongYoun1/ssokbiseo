# 쏙비서 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 아침에 한 화면으로 날씨·일정·관심 뉴스·기분 조언·GeekNews·출근 시간을 보여 주는 안드로이드 앱 "쏙비서"와, 그 뒤의 Vercel 중계 서버, 매일 아침 요약을 만드는 Claude 예약 작업을 만든다.

**Architecture:** 한 저장소에 세 부분. `server/`(Vercel 함수, API 키 보관·하루 호출 수 제한), `routine/`(Claude 클라우드 예약 작업 지시문과 결과 검증 스크립트, 결과는 `data/briefing.json`에 커밋), `app/`(Flutter 앱: 일정은 기기에서, 날씨·길찾기는 서버, 뉴스·조언·GeekNews는 briefing.json을 읽음).

**Tech Stack:** Flutter 3.47 / Dart 3.13 (`http`, `shared_preferences`, `device_calendar`, `geolocator`, `url_launcher`), Vercel Node 함수 TypeScript + vitest, Upstash Redis(Vercel 마켓플레이스 무료), 기상청 단기예보 API, 카카오 Local·카카오모빌리티 길찾기·카카오맵 대중교통 API, 네이버 검색 API, Claude 예약 작업(Haiku).

**Spec:** `docs/superpowers/specs/2026-11-05-ssokbiseo-design.md` (쏙메모 저장소에 임시로 있음 → Task 1에서 새 저장소 `docs/`로 옮김)

## Global Constraints

- 새 폴더 `C:\_vibe\ssok-biseo`, 새 GitHub 저장소 `LeeJongYoun1/ssokbiseo`(**공개** — 앱이 `data/briefing.json`을 인증 없이 읽기 때문). 이름·공개 여부는 Task 1 시작 전 사용자에게 확인한다.
- 앱 이름 "쏙비서", 패키지 `com.ssokmemo.biseo`(쏙메모 `com.ssokmemo.app`과 달라야 함).
- API 키(기상청·카카오·네이버)는 **앱과 저장소에 절대 넣지 않는다.** Vercel 환경변수에만. 커밋 전 `git grep -n -i -E "KakaoAK|X-Naver-Client|serviceKey="`로 값이 없는지 확인.
- `data/briefing.json`에는 개인정보(일정·위치·주소)를 넣지 않는다.
- 비용 0원: 카카오 대중교통은 하루(KST) **900건**에서 차단, 유료 결제 연결 안 함.
- 뉴스 요약 재료는 네이버 검색 API의 제목+미리보기만. 언론사 본문 수집 금지. GeekNews는 글 페이지의 작성자 소개 글만.
- 룩앤필: 쏙메모 `lib/ui/theme.dart`의 `SsokColors` 값 그대로(cream `#FFFBEA`, lemon `#FFD43B`, ink `#3B3220` 등), 큰 글씨, Jua 제목 글꼴.
- 날짜 경계는 언제나 **Asia/Seoul(KST)** 기준.
- 사용자에게 보이는 문구는 한국어, 짧고 쉽게.
- 서명 키: 쏙메모와 같은 `.jks`를 쓴다(`app/android/key.properties`, gitignore). 커밋 금지.

## Review Focus

1. briefing.json이 없거나 날짜가 오늘(KST)이 아니면 → 빈 화면이 아니라 마지막으로 받은 내용 + "어제 내용이에요" 표시 (Task 7 테스트)
2. 집·회사를 아직 등록하지 않음 → 날씨·걸리는 시간 칸에 "설정에서 집·회사를 등록해 주세요" 안내, 오류 아님 (Task 8 테스트)
3. 서버가 느리거나 죽음 → 각 칸이 따로 실패 문구를 보이고 나머지 칸은 정상, 5초 안에 화면이 다 그려짐 (Task 7 테스트)
4. 네이버 응답의 `<b>`, `&quot;` 같은 태그·엔티티 → 화면에 그대로 보이지 않음 (Task 4 테스트)
5. 일정·위치 권한 거부 → 해당 칸만 "권한을 허용하면 볼 수 있어요"와 허용 버튼, 앱은 계속 동작 (Task 8 테스트)

---

## 공통 계약 (모든 Task가 따름)

**서버 엔드포인트** (모든 요청에 헤더 `x-ssok-key: <SSOK_APP_KEY>`; 틀리면 401)

| 경로 | 입력 | 출력(JSON) |
|---|---|---|
| `GET /api/weather` | `lat`, `lon` | `{ tempC: number, sky: "맑음"\|"구름많음"\|"흐림", rain: "없음"\|"비"\|"비/눈"\|"눈"\|"소나기", popMax: number, tmin: number\|null, tmax: number\|null }` |
| `GET /api/geocode` | `q` | `{ items: [{ name: string, address: string, lat: number, lon: number }] }` (최대 5개) |
| `GET /api/route` | `fromLat`,`fromLon`,`toLat`,`toLon` | `{ carMin: number\|null, transitMin: number\|null, transitBlocked: boolean }` |
| `GET /api/news-raw` | (없음, 헤더 `x-ssok-key` 대신 `x-ssok-routine-key`) | `{ date: "YYYY-MM-DD", topics: { [topic]: [{ title, description, link, pubDate }] } }` |

**briefing.json** (`data/briefing.json`)
```json
{
  "date": "2026-11-06",
  "generatedAt": "2026-11-06T05:31:00+09:00",
  "news": { "경제": [{ "title": "...", "summary": "...", "url": "https://..." }] },
  "advice": { "good": { "friend": "...", "coach": "...", "quote": "...", "action": "..." } },
  "community": { "geeknews": [Item], "ppomppu": [Item], "ruliweb": [Item], "82cook": [Item] }
  // Item = { "title": "...", "points": 42 또는 null, "summary": "...", "url": "https://...", "discussUrl": "https://..." 또는 null(GeekNews만 값) }
  // 앱은 옛 최상위 "geeknews"도 community.geeknews로 받아들인다
}
```
- 주제(`TOPICS`, 순서 고정): `경제, 재테크, 세무, 부동산, 건강, IT, 정치, 사회, 국제, 과학, 스포츠, 연예`
- 기분 키: `good`😊좋음, `tired`😴피곤, `worried`😟걱정, `down`😢우울, `eager`🔥의욕
- 말투 키: `friend` 다정한 친구, `coach` 짧고 힘 있는 코치, `quote` 명언 인용, `action` 오늘 해 볼 작은 행동
- 각 주제·커뮤니티는 0~10개, advice는 5×4 전부 채움.

---

### Task 1: 저장소 뼈대 + 서버 공통부(인증, KST 날짜, 하루 카운터)

**Files:**
- Create: `C:\_vibe\ssok-biseo\` (git init, `README.md`, `.gitignore`), `docs/`(spec·plan을 쏙메모에서 옮김)
- Create: `server/package.json`, `server/tsconfig.json`, `server/vercel.json`, `server/lib/auth.ts`, `server/lib/kst.ts`, `server/lib/counter.ts`
- Test: `server/test/common.test.ts`

**Interfaces:**
- Produces: `checkAppKey(req: Request): boolean`, `checkRoutineKey(req: Request): boolean`(환경변수 `SSOK_APP_KEY`, `SSOK_ROUTINE_KEY`), `kstDate(now?: Date): string`("YYYY-MM-DD"), `incrDaily(name: string, limit: number, now?: Date): Promise<{ count: number; allowed: boolean }>`(키 `${name}:${kstDate(now)}`, 만료 2일), `Store` 인터페이스(`incr(key)`, `expire(key, sec)`)로 Upstash를 감싸 테스트에서 메모리 구현 주입.

- [ ] **Step 1:** 사용자에게 저장소 이름 `ssokbiseo`·공개·패키지 `com.ssokmemo.biseo` 확인. 폴더 만들고 `git init -b main`, spec·plan 복사, `.gitignore`에 `node_modules/ .vercel/ .env* app/android/key.properties build/`.
- [ ] **Step 2: 실패하는 테스트**
```ts
test('kstDate는 UTC 15:00을 다음 날로', () => expect(kstDate(new Date('2026-11-05T15:00:00Z'))).toBe('2026-11-06'));
test('incrDaily는 limit 초과부터 allowed=false', async () => {
  const s = memoryStore(); for (let i = 0; i < 900; i++) await incrDaily('transit', 900, NOW, s);
  expect((await incrDaily('transit', 900, NOW, s)).allowed).toBe(false);
});
test('날짜가 바뀌면 카운터 새로 시작', ...);   // NOW와 NOW+1일 비교, count=1
test('x-ssok-key 틀리면 checkAppKey=false', ...);
```
- [ ] **Step 3:** `cd server && npx vitest run` → FAIL
- [ ] **Step 4:** 구현(`@upstash/redis`의 `Redis.fromEnv()`를 기본 Store로)
- [ ] **Step 5:** `npx vitest run` → PASS
- [ ] **Step 6:** 커밋 `chore: 저장소 뼈대, 서버 공통부`

### Task 2: 날씨 `/api/weather`

**Files:** Create `server/lib/grid.ts`, `server/api/weather.ts`; Test `server/test/weather.test.ts`

**Interfaces:**
- Consumes: `checkAppKey`, `kstDate`
- Produces: `toGrid(lat: number, lon: number): { nx: number; ny: number }`(기상청 LCC DFS 변환: RE 6371.00877, GRID 5.0, SLAT1 30, SLAT2 60, OLON 126, OLAT 38, XO 43, YO 136), `/api/weather` 계약대로.

- [ ] **Step 1: 실패하는 테스트**
```ts
expect(toGrid(37.5665, 126.9780)).toEqual({ nx: 60, ny: 127 });  // 서울시청
expect(toGrid(35.1796, 129.0756)).toEqual({ nx: 98, ny: 76 });   // 부산시청
test('초단기실황 T1H·PTY + 단기예보 SKY·POP·TMN·TMX를 계약 모양으로', ...); // fetch 목, 기상청 샘플 응답 고정
test('기상청이 오류 코드(resultCode!="00")면 502', ...);
```
- [ ] **Step 2:** FAIL 확인
- [ ] **Step 3:** 구현. 초단기실황 `getUltraSrtNcst`(현재 기온·강수형태), 단기예보 `getVilageFcst`(오늘 SKY 최빈값·POP 최대·TMN·TMX). base_time은 KST 기준 직전 발표 시각. 키 `KMA_SERVICE_KEY`.
- [ ] **Step 4:** PASS 확인, 커밋 `feat(server): 날씨`

### Task 3: 주소 찾기 `/api/geocode` + 걸리는 시간 `/api/route`

**Files:** Create `server/api/geocode.ts`, `server/api/route.ts`, `server/lib/kakao.ts`; Test `server/test/route.test.ts`

**Interfaces:**
- Consumes: `checkAppKey`, `incrDaily`
- Produces: 계약대로. `kakaoCarMinutes(from, to): Promise<number|null>`, `kakaoTransitMinutes(from, to): Promise<number|null>`

- [ ] **Step 1:** 카카오 디벨로퍼스 문서에서 **대중교통 경로 조회 API**(2026-07-21 신설)의 주소·파라미터·소요 시간 필드를 확인해 `server/lib/kakao.ts` 맨 위 주석에 문서 URL과 함께 적는다. 소요 시간 필드가 없으면 `kakaoTransitMinutes`는 항상 `null`(앱은 버튼만 보임 — spec 8장).
- [ ] **Step 2: 실패하는 테스트**
```ts
test('자동차: summary.duration(초) 1500 → carMin 25', ...);
test('대중교통 900건 넘으면 카카오를 부르지 않고 transitBlocked=true, transitMin=null', ...);
test('자동차 실패해도 대중교통 결과는 돌려줌(부분 실패)', ...);
test('geocode: 주소 검색 결과 0건이면 키워드 검색으로 다시, 최대 5개', ...);
test('좌표 범위 밖(lat 33~39, lon 124~132 아님)이면 400', ...);
```
- [ ] **Step 3:** FAIL 확인
- [ ] **Step 4:** 구현. 자동차 `https://apis-navi.kakaomobility.com/v1/directions`(origin/destination은 `lon,lat`), geocode는 카카오 Local `search/address` → 없으면 `search/keyword`. 헤더 `Authorization: KakaoAK ${KAKAO_REST_KEY}`. 대중교통 호출 전 `incrDaily('transit', 900)`.
- [ ] **Step 5:** PASS, 커밋 `feat(server): 주소 찾기, 걸리는 시간`

### Task 4: 뉴스 원자료 `/api/news-raw`

**Files:** Create `server/api/news-raw.ts`, `server/lib/topics.ts`, `server/lib/clean.ts`; Test `server/test/news.test.ts`

**Interfaces:**
- Produces: `TOPICS: readonly string[]`(공통 계약 순서), `cleanText(s: string): string`, `/api/news-raw` 계약대로(`checkRoutineKey`).

- [ ] **Step 1: 실패하는 테스트**
```ts
expect(cleanText('<b>삼성</b> &quot;반도체&quot; 회복&amp;')).toBe('삼성 "반도체" 회복&');
test('주제 12개 모두 키로 있고, 각 display=10&sort=date로 호출', ...);
test('한 주제가 실패하면 그 주제만 빈 배열', ...);
test('routine 키가 틀리면 401', ...);
```
- [ ] **Step 2:** FAIL → **Step 3:** 구현(`https://openapi.naver.com/v1/search/news.json`, 헤더 `X-Naver-Client-Id/Secret` ← `NAVER_CLIENT_ID/SECRET`, `link`는 네이버 뉴스 링크 우선 없으면 `originallink`) → **Step 4:** PASS, 커밋 `feat(server): 뉴스 원자료`

### Task 5: briefing 계약 + 예약 작업 지시문

**Files:** Create `routine/schema.mjs`(검증 함수), `routine/validate.mjs`(CLI), `routine/prompt.md`, `data/briefing.json`(예시), Test `routine/validate.test.mjs`(node --test)

**Interfaces:**
- Produces: `validateBriefing(obj): string[]`(오류 목록, 비면 통과). `node routine/validate.mjs data/briefing.json` → 통과 시 exit 0.

- [ ] **Step 1: 실패하는 테스트**
```js
assert.deepEqual(validateBriefing(sample), []);
assert.ok(validateBriefing({...sample, advice: {}}).some(e => e.includes('advice.good')));
assert.ok(validateBriefing({...sample, news: {경제: Array(11).fill(item)}}).length > 0); // 10개 초과
assert.ok(validateBriefing({...sample, date: '2026/11/06'}).length > 0);
// url은 https:// 로 시작해야 함
```
- [ ] **Step 2:** FAIL → **Step 3:** 구현 + 예시 `data/briefing.json`(모든 키 채운 샘플)
- [ ] **Step 4:** `routine/prompt.md` 작성. 지시 순서:
  1. `curl -H "x-ssok-routine-key: $SSOK_ROUTINE_KEY" https://<vercel>/api/news-raw` (키는 예약 작업 환경 설정의 비밀값, 지시문에 쓰지 않음)
  2. 각 기사: 제목+미리보기만 보고 **한 줄(40자 안팎) 요약**. 본문 페이지는 열지 않는다.
  3. GeekNews: 어제(KST) 글 목록 페이지(작성 전 실제 주소 확인, 예상 `https://news.hada.io/past?day=<어제>`)에서 점수 순 상위 10개, 각 글 페이지의 작성자 소개 글만 읽고 2~3줄 요약.
  4. 기분 5 × 말투 4 = 20개 조언, 각 2문장 이내, 오늘 날짜·요일 반영, 같은 말 반복 금지.
  5. `data/briefing.json` 작성 → `node routine/validate.mjs data/briefing.json` 통과할 때까지 고침 → `git commit -m "data: briefing YYYY-MM-DD"` → `git push origin main`.
- [ ] **Step 5:** PASS, 커밋 `feat(routine): briefing 계약, 예약 작업 지시문`

### Task 6: Flutter 앱 뼈대 + 테마 + briefing 모델

**Files:** `flutter create --org com.ssokmemo --project-name biseo app` 후 Create `app/lib/ui/theme.dart`, `app/lib/data/briefing.dart`, `app/assets/fonts/Jua-Title.ttf`; Test `app/test/briefing_test.dart`

**Interfaces:**
- Produces: `ssokTheme()`, `SsokColors`(쏙메모에서 복사), `class Briefing { String date; Map<String, List<NewsItem>> news; Map<String, Map<String, String>> advice; List<GeekItem> geeknews; static Briefing fromJson(Map<String, dynamic>) }`, `NewsItem{title, summary, url}`, `GeekItem{title, points, summary, url, discussUrl}`, 상수 `kTopics`, `kMoods`(키·이모지·이름), `kTones`(키·이름) — 공통 계약 값 그대로.

- [ ] **Step 1:** applicationId `com.ssokmemo.biseo`, 앱 이름 "쏙비서". 제목 글꼴은 Jua에서 "쏙비서" 세 글자 부분집합(`pyftsubset Jua-Regular.ttf --text="쏙비서"`), OFL 라이선스를 `LicenseRegistry`에 등록.
- [ ] **Step 2: 실패하는 테스트**: 예시 `data/briefing.json`을 `test/fixtures/`에 복사해 `fromJson` 결과의 `news['경제']!.first.title`, `advice['tired']!['coach']`, `geeknews.length` 확인; 모르는 주제 키는 무시; `geeknews` 없으면 빈 목록.
- [ ] **Step 3:** FAIL → **Step 4:** 구현 → **Step 5:** `flutter test` PASS, 커밋 `feat(app): 뼈대, 테마, briefing 모델`

### Task 7: 앱 데이터 계층 (briefing 저장소, 서버 API, 설정)

**Files:** Create `app/lib/data/briefing_repo.dart`, `app/lib/data/server_api.dart`, `app/lib/data/settings.dart`, `app/lib/config.dart`; Test `app/test/data_test.dart`

**Interfaces:**
- Consumes: `Briefing`
- Produces:
  - `class BriefingRepo { BriefingRepo(http.Client, SharedPreferences, {DateTime Function() now}); Future<BriefingResult> load(); }`, `BriefingResult{ Briefing? briefing; bool stale; }` — URL `https://raw.githubusercontent.com/LeeJongYoun1/ssokbiseo/main/data/briefing.json`, 성공 시 원문을 prefs에 저장, 실패 시 저장본, `stale = briefing.date != 오늘(KST)`.
  - `class ServerApi { ServerApi(http.Client, {String base, String appKey}); Future<Weather> weather(double lat, double lon); Future<List<Place>> geocode(String q); Future<RouteTime> route(Place from, Place to); }` 모든 요청 타임아웃 **5초**, 실패는 `ServerException`.
  - `class Settings { Place? home; Place? work; List<String> topics /*기본 ['경제','IT','건강']*/; String tone /*기본 'friend'*/; String? moodToday; String? moodDate; }` + `SettingsStore.load()/save()`(SharedPreferences, JSON). `moodToday`는 `moodDate`가 오늘(KST)일 때만 유효.
  - `config.dart`: `const serverBase = String.fromEnvironment('SSOK_SERVER')`, `const appKey = String.fromEnvironment('SSOK_APP_KEY')` (빌드 시 `--dart-define`, 저장소에 값 없음).
- [ ] **Step 1: 실패하는 테스트** (`MockClient`)
  - 네트워크 실패 + 저장본 있음 → 저장본, `stale` 날짜 비교대로
  - 네트워크 실패 + 저장본 없음 → `briefing == null`
  - 오늘 날짜 briefing → `stale == false`, 어제 → `true`
  - 서버가 6초 걸림 → `ServerException`(타임아웃)
  - 어제 고른 기분은 오늘 `moodToday == null`
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS, 커밋 `feat(app): 데이터 계층`

### Task 8: 홈 화면

**Files:** Create `app/lib/ui/home_page.dart`, `app/lib/ui/cards/*.dart`(weather, schedule, route, mood, news, geeknews), `app/lib/data/calendar.dart`, `app/lib/data/location.dart`; Test `app/test/home_test.dart`

**Interfaces:**
- Consumes: Task 7 전부
- Produces: `HomePage({required BriefingRepo, required ServerApi, required SettingsStore, required CalendarSource, required LocationSource})`. `abstract class CalendarSource { Future<List<Event>?> today(); }`(null = 권한 없음, `device_calendar` 구현), `abstract class LocationSource { Future<(double, double)?> current(); }`(null = 권한 없음, `geolocator` 저정밀).

카드 순서(위→아래): 날씨(집·회사) → 오늘 일정 → 걸리는 시간(현재 위치→집, →회사) → 기분 조언 → 관심 뉴스(설정한 주제별 접기 목록) → GeekNews. 각 카드는 자기 데이터를 따로 불러오고 실패해도 다른 카드에 영향 없음. 위로 당기면 새로고침.
- 기분: 이모지 버튼 5개 → 누르면 `advice[mood][settings.tone]` 표시, 오늘 날짜로 저장.
- 걸리는 시간: "🚗 25분 · 🚌 42분". `transitMin == null`이면 🚌 칸은 "카카오맵에서 보기" 버튼. 누르면 `kakaomap://route?sp={lat},{lon}&ep={lat},{lon}&by=CAR|PUBTRANS`, 앱 없으면 `https://map.kakao.com/link/to/{name},{lat},{lon}`.
- 뉴스·GeekNews 제목 누르면 아래 시트에 요약 + "원문 보기" 버튼(`url_launcher` 외부 브라우저). GeekNews는 "토론 보기"(discussUrl)도.
- `stale`이면 뉴스·조언·GeekNews 카드 위에 "어제 내용이에요".

- [ ] **Step 1: 실패하는 위젯 테스트** (가짜 소스 주입)
  - 집·회사 미등록 → 날씨·걸리는 시간 카드에 '설정에서 집·회사를 등록해 주세요'
  - 서버 실패 → 날씨 카드 '날씨를 불러오지 못했어요', 일정·뉴스 카드는 정상
  - `CalendarSource.today()`가 null → '권한을 허용하면 볼 수 있어요'와 '허용' 버튼
  - 위치 null → 걸리는 시간 카드에 같은 권한 안내
  - 😴 누르고 설정 tone='coach' → `advice['tired']['coach']` 문구 보임
  - `transitMin=null` → '카카오맵에서 보기'
  - stale=true → '어제 내용이에요'
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS, 커밋 `feat(app): 홈 화면`

### Task 9: 설정 화면

**Files:** Create `app/lib/ui/settings_page.dart`, `app/lib/ui/place_search_page.dart`; Modify `app/lib/ui/home_page.dart`(앱바 톱니 버튼); Test `app/test/settings_test.dart`

**Interfaces:**
- Consumes: `ServerApi.geocode`, `SettingsStore`
- Produces: `SettingsPage({required ServerApi, required SettingsStore})`, 저장 후 `Navigator.pop(context, true)` → 홈이 새로고침.

항목: 집 / 회사(누르면 주소 검색 → 후보 목록 → 고르기), 볼 뉴스 주제(체크 12개, 최소 1개), 조언 말투(라디오 4개).
- [ ] **Step 1: 실패하는 위젯 테스트**: 주소 '판교역' 검색 → 후보 탭 → 저장값 `work.name`; 주제를 모두 끄려 하면 마지막 하나는 꺼지지 않음; 말투 '명언 인용' 선택 → `tone=='quote'`; 검색 0건이면 '찾는 곳이 없어요. 동 이름이나 건물 이름으로 찾아보세요'
- [ ] **Step 2:** FAIL → **Step 3:** 구현 → **Step 4:** PASS, 커밋 `feat(app): 설정 화면`

### Task 10: 안드로이드 권한·서명·릴리스 빌드

**Files:** Modify `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/build.gradle.kts`; Create `app/android/key.properties`(gitignore, 쏙메모 키 경로)

- [ ] **Step 1:** 권한 `INTERNET`, `READ_CALENDAR`, `ACCESS_COARSE_LOCATION`. `<queries>`에 `kakaomap` 스킴과 https VIEW. 권한 요청은 해당 카드의 '허용' 버튼을 누를 때만(앱 시작 시 한꺼번에 묻지 않음).
- [ ] **Step 2:** 쏙메모 `android/app/build.gradle.kts`의 서명 블록·ARM 전용 분기를 그대로 옮김(키 없으면 release 빌드 실패).
- [ ] **Step 3:** `flutter test` 전체 PASS
- [ ] **Step 4:** `flutter build apk --release --dart-define=SSOK_SERVER=<vercel 주소> --dart-define=SSOK_APP_KEY=<값>` 성공. `git status`에 key.properties 없음 확인.
- [ ] **Step 5:** 커밋 `build(app): 권한, 서명, 릴리스 빌드`

### Task 11: 배포와 연결 확인 (사람 확인 필요한 단계 포함)

- [ ] **Step 1:** 사용자 확인 후 GitHub 저장소 생성(`gh repo create LeeJongYoun1/ssokbiseo --public --source . --push`).
- [ ] **Step 2:** 사용자가 키 발급: 공공데이터포털(기상청 단기예보), 카카오 디벨로퍼스(REST 키, 카카오맵·모빌리티 활성화), 네이버 개발자센터(검색). Vercel 프로젝트(`server/` 루트)에 `KMA_SERVICE_KEY, KAKAO_REST_KEY, NAVER_CLIENT_ID, NAVER_CLIENT_SECRET, SSOK_APP_KEY, SSOK_ROUTINE_KEY` + Upstash 연결. 키 값은 사용자가 직접 입력하고 채팅에 붙이지 않는다.
- [ ] **Step 3:** 배포 후 `curl -H "x-ssok-key: …" "<vercel>/api/weather?lat=37.5665&lon=126.978"` → 계약 모양 JSON. route·geocode·news-raw도 한 번씩.
- [ ] **Step 4:** `/schedule`로 Claude 예약 작업 생성: 매일 05:30 KST, 저장소 `ssokbiseo`, 모델 Haiku(선택 불가하면 사용자에게 알림), 지시문 `routine/prompt.md`, 비밀값 `SSOK_ROUTINE_KEY`. 한 번 수동 실행 → `data/briefing.json` 커밋과 validate 통과 확인.
- [ ] **Step 5:** 에뮬레이터에 릴리스 APK 설치, 홈 6칸 모두 표시 확인(일정은 에뮬레이터 캘린더에 일정 하나 추가).
- [ ] **Step 6:** README에 구조·키 목록(값 없이)·빌드 명령 정리, 커밋·푸시.
