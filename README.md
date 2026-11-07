# 쏙비서

아침에 한 화면으로 날씨·일정·관심 뉴스·기분 조언·GeekNews·출근 시간을 보여 주는 안드로이드 앱. 쏙메모의 형제 앱.

- 설계: docs/superpowers/specs/2026-11-05-ssokbiseo-design.md
- 구현 계획: docs/superpowers/plans/2026-11-05-ssokbiseo.md

## 배포 준비

Vercel 환경변수(이름만; 값은 저장소에 넣지 않는다):

- `KMA_SERVICE_KEY` — 공공데이터포털 **Decoding** 키
- `KAKAO_REST_KEY`
- `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`
- `SSOK_APP_KEY` (앱 요청 헤더 `x-ssok-key`), `SSOK_ROUTINE_KEY` (루틴 요청 헤더 `x-ssok-routine-key`)
- `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` — 하루 호출 횟수 카운터용. 먼저 Supabase SQL Editor에서 `server/supabase/schema.sql`을 한 번 실행한다. 서비스 키(service_role)는 서버 밖으로 내지 않는다.

앱 빌드:

```
cd app
flutter build apk --release --dart-define=SSOK_SERVER=https://<앱주소>.vercel.app --dart-define=SSOK_APP_KEY=<앱 키>
```

`--dart-define` 없이 빌드하면 예시 모드(날씨·길찾기·뉴스를 가짜 값으로 보여 줌).
