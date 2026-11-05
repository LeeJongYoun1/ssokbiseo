# 쏙비서 아침 브리핑 만들기 (예약 작업 지시문)

너는 매일 아침 `data/briefing.json`을 만드는 예약 작업 에이전트다. 이 저장소(`LeeJongYoun1/ssokbiseo`)에서 일한다.

## 설정 (처음 한 번만 사용자가 고침)

```
export SSOK_SERVER=https://<your-vercel-app>.vercel.app
```

- 작업을 시작하면 **맨 먼저 위 `export` 줄을 그대로 실행**한다(사용자가 `<your-vercel-app>`을 실제 주소로 한 번만 채운다). 이후 모든 `curl`은 `$SSOK_SERVER`를 쓴다. 값이 비어 있거나 `<`가 들어 있으면 실패로 보고 끝낸다.
- 비밀 키는 예약 작업 환경의 환경변수 `SSOK_ROUTINE_KEY`로 받는다. 이 파일·출력·커밋 어디에도 키 값을 쓰지 않는다.
- 모든 날짜·시각은 한국 시간(KST, Asia/Seoul) 기준이다. `TZ=Asia/Seoul date`로 확인한다.
- "오늘" = 지금 KST 날짜, "어제" = 그 전날. 요일도 KST 기준.

## 실패 규칙 (가장 중요)

- 1단계 `news-raw` 요청이 실패하거나, 검증이 3번 고쳐도 통과하지 못하면 **`data/briefing.json`을 덮어쓰지 않는다**(어제 파일 그대로 둔다). 커밋·푸시도 하지 않고, 어느 단계에서 왜 실패했는지 오류 요약을 남기고 끝낸다.
- GeekNews를 못 읽으면 `geeknews`를 `[]`로 두고 계속한다.
- 원자료에 없는 제목·링크를 만들지 않는다. 모르면 뺀다.
- 중간에 쓴 임시 파일은 `data/briefing.json`이 아닌 곳(예: `/tmp/briefing.json`)에 둔다. 검증을 통과한 뒤에만 복사한다.

## 순서

1. 뉴스 재료 받기
   ```
   curl -sS --fail -H "x-ssok-routine-key: $SSOK_ROUTINE_KEY" "$SSOK_SERVER/api/news-raw"
   ```
   결과는 `{ date, topics: { 주제: [{ title, description, link, pubDate }] } }`. 주제는 경제, 재테크, 세무, 부동산, 건강, IT, 정치, 사회, 국제, 과학, 스포츠, 연예 열두 가지.

2. 뉴스 요약: 각 기사의 **제목과 미리보기(description)만** 보고 **한 줄(40자 안팎)로 요약**한다. 기사 본문 페이지는 열지 않는다. 주제마다 최대 10개. 결과는 `{ "title": 제목, "summary": 한 줄 요약, "url": link }`. 제목의 `<b>` 같은 태그나 `&quot;` 같은 엔티티는 지운다. url은 `https://`로 시작하는 것만 쓴다.

3. GeekNews: 어제(KST) 글 목록 페이지에서 점수 순 상위 10개를 고른다. 주소는 먼저 실제로 열려는지 확인한다(예상: `https://news.hada.io/past?day=<어제 YYYY-MM-DD>`; 안 열리면 사이트에서 올바른 주소를 찾는다). 각 글의 GeekNews 글 페이지에서 **작성자 소개 글만** 읽고 2~3줄로 요약한다. 연결된 원문 사이트는 열지 않는다. 결과는 `{ "title", "points": 숫자, "summary", "url": 원문 링크(https), "discussUrl": "https://news.hada.io/topic?id=..." }`.

4. 조언 20개: 기분 5 × 말투 4. 각각 **2문장 이내**. 오늘 날짜와 요일을 은근히 반영하고, 20개 사이에 같은 말을 반복하지 않는다. 개인정보(일정·위치)는 쓰지 않는다.
   - 기분: `good` 좋음, `tired` 피곤, `worried` 걱정, `down` 우울, `eager` 의욕
   - 말투: `friend` 다정한 친구, `coach` 짧고 힘 있는 코치, `quote` 명언 인용, `action` 오늘 해 볼 작은 행동

5. 파일 만들기와 올리기
   - 아래 모양으로 JSON을 만든다. `date`는 오늘(KST) `YYYY-MM-DD`, `generatedAt`은 KST ISO 시각(예: `2026-11-06T05:31:00+09:00`).
     ```json
     { "date": "", "generatedAt": "", "news": { "경제": [] }, "advice": { "good": { "friend": "", "coach": "", "quote": "", "action": "" } }, "geeknews": [] }
     ```
   - `node routine/validate.mjs <파일>`을 실행한다. 오류가 나오면 경로(예: `news.경제[3].url`)를 보고 고쳐서 다시 실행한다. 최대 3번까지 시도한다.
   - 통과하면 `data/briefing.json`으로 복사한 뒤:
     ```
     git add data/briefing.json
     git diff --cached --quiet && echo "nothing to commit"   # 바뀐 게 없으면 커밋·푸시를 건너뛴다
     git commit -m "data: briefing YYYY-MM-DD"
     git push origin main
     ```
     `git push`가 실패하면 오류를 그대로 보고하고 끝낸다(재시도는 한 번까지만, 무한 반복 금지).
     (YYYY-MM-DD는 오늘 KST 날짜. `main` 푸시는 의도된 배포 방식이다. 앱이 main의 파일을 그대로 읽는다.)
   - 마지막에 한 줄로 결과를 알린다(뉴스 개수, GeekNews 개수, 커밋 해시).
