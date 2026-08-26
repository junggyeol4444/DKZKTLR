# 로컬 검증 하네스

실제 Supabase 프로젝트 없이 이 저장소의 프론트엔드와 `sql/` 스키마를
**있는 그대로** 검증합니다. 배포 대상이 아니며 운영에 쓰지 않습니다.

## 무엇을 하는가

1. 임시 PostgreSQL 클러스터를 만들고 `sql/schema.sql` → `sql/rls.sql` → `sql/seed.sql` 을 적재합니다.
2. Supabase 호환 셔임(`shim.js`)이 그 데이터베이스 앞에 섭니다.
   - PostgREST 호환: `GET/POST/PATCH/DELETE /rest/v1/<테이블|뷰>`, `POST /rest/v1/rpc/<함수>`
   - GoTrue 호환: `signup` / `token` / `user` / `logout` / `recover` / `resend`
   - 요청마다 트랜잭션 안에서 `role = authenticated` 와 `request.jwt.claim.sub` 을 설정하므로,
     **RLS · 트리거 · 컬럼 단위 GRANT 가 실제와 같은 경로로 적용됩니다.**
3. 헤드리스 Chromium 이 `index.html` 을 열고, 사람이 하듯 화면을 조작합니다.
   `window.AKASHIC_CONFIG` 를 주입해 셔임을 가리키므로 `supabase.js` 는 손대지 않습니다.

셔임은 검증용입니다. JWT 서명을 확인하지 않고, 메일도 보내지 않습니다.
인증 메일의 링크 클릭은 `GET /test/confirm?email=...` 로 대신합니다.

## 준비

```bash
cd test
npm install          # pg, @supabase/supabase-js
```

추가로 필요한 것:

- `initdb` / `pg_ctl` / `psql` (PostgreSQL 13 이상)
- Node 18 이상, `playwright` 모듈, Chromium 실행 파일
- **root 가 아닌 사용자로 실행** — PostgreSQL 이 root 기동을 거부합니다.

## 실행

```bash
./run.sh                       # 네 스위트 전부
./run.sh core                  # 하나만 (core | lifecycle | ui | related)
./run.sh lifecycle ui
```

스위트마다 데이터베이스를 새로 만들어 시드 상태에서 시작합니다.
스크린샷은 `$SHOTS_DIR` (기본값은 작업 디렉터리 아래 `shots/`) 에 남습니다.

경로가 다르면 환경 변수로 지정합니다.

| 변수 | 뜻 | 기본값 |
|---|---|---|
| `AKASHIC_TEST_WORK` | 작업 디렉터리 | `$TMPDIR/akashic-test` |
| `PGBIN` | `initdb` / `pg_ctl` 이 있는 경로 | `initdb` 가 있는 디렉터리 |
| `PGSOCKET` / `PGPORT_TEST` | PostgreSQL 소켓 · 포트 | `$WORK/sock` · `5439` |
| `SHIM_PORT` | 셔임 포트 | `5555` |
| `CHROMIUM` | Chromium 실행 파일 | `/opt/pw-browsers/chromium` |
| `PLAYWRIGHT` | playwright 모듈 경로 | `playwright` |
| `SHOTS_DIR` | 스크린샷 저장 위치 | `$WORK/shots` |

## 스위트

| 파일 | 검사 수 | 다루는 것 |
|---|---|---|
| `suite-core.js` | 30 | 가입 · 이메일 인증 · 로그인 · 4단계 탐색 · 검열 · 뒤로가기 · 북마크 · 작성 · 타인 기록 보호 · 신고 · 오류 화면 |
| `suite-lifecycle.js` | 18 | 등급 상승 · 관련 기록 · 검색 · 수정 · **시드 전량 삭제 후 재검증** |
| `suite-ui.js` | 27 | 페이지네이션 · 언어 탭 · 폼 상한 · 신고 UI · 세션 만료 · 드로어 · 등급 상승 배너 · 관리자 대기열 · 회귀 2건 |
| `suite-related.js` | 6 | `related_ids` 에 삭제·숨김 항목이 섞였을 때의 참조 무결성 |
| `suite-edge.js` | 13 | 비로그인 접근 · 가입 유효성 · 404/403/5xx 화면 · 모달 포커스와 Tab 트랩 · 모션 토글 · RESTRICTED 행성 |
| `suite-scale.js` | 7 | 코드 발급 자리수 경계 · 동시 작성 · 2만 건에서의 집계와 실행 계획 |
| `suite-style.js` | 15 | 실제로 그려진 색의 명암비 · 언어별 CJK 폰트 폴백 · 반응형 3단계 · 터치 영역 |
| `suite-hardening.js` | 15 | 저장된 마크업의 실행 여부 · 길이 경계 · 긴 문자열 레이아웃 · 애니메이션 규격 · 포커스 표시 · 키보드 이동 |
| `suite-session.js` | 9 | 토큰 자동 갱신과 갱신 실패 · 다중 탭 동기화 · 로그아웃 이후 · i18n 키 폴백 |
| `suite-race.js` | 10 | 느린 응답에서의 스켈레톤 · 화면 경합 · 이중 제출 · 두 탭 동시 수정 |

`suite-hardening.js` 에는 등급을 스스로 올리려는 시도가 포함됩니다.
`record_views` 의 행 수로 등급이 정해지므로, 열람하지 않은 기록의 id 를 넣을 수 있으면
`profiles.level` 을 막아 둔 것이 무의미해집니다.

합계 150개 검사.

명세서 7.2 의 시나리오 20개 중 다음은 여기서 다루지 않습니다.
실제 Supabase 프로젝트가 있어야 확인됩니다.

- 인증 메일과 재설정 메일의 실제 수신, 그 링크를 눌러 돌아오는 왕복
- 배포 도메인과 Auth 리디렉션 설정

## 이 하네스가 잡은 결함

1. `[hidden]` 이 `.screen` / `#app` / `.modal` 의 `display:flex` 에 덮여 모든 화면이 겹쳐 렌더링됨
2. 신고 3건 누적 시 상태를 바꾸는 트리거가 기록 소유자 검사에 막혀 숨김 처리가 동작하지 않음
3. 공유 링크로 곧바로 연 탭에서 모달을 닫으면 `history.back()` 이 사이트 밖으로 나감
4. `supabase-js` 가 HTTP 상태를 오류 객체가 아니라 응답에 담아, 403 과 5xx 가 모두 "알 수 없는 오류" 로 떨어짐
5. `.modal-box` 에 `tabindex` 가 없어 모달을 열어도 포커스가 밖에 남고, 그 탓에 Tab 트랩도 동작하지 않음
6. 기록 화면으로 이동할 때 목록을 다시 그려, 방금 누른 카드가 사라져 포커스를 되돌릴 곳이 없어짐
7. `lpad` 가 인자가 더 길면 잘라내는 탓에, 한 행성의 기록이 9,999 건을 넘거나 가입자가 999 명을 넘으면
   코드가 앞선 것과 겹쳐 이후 작성과 가입이 모두 실패함
8. breadcrumb 라벨이 명세가 금지한 `--faint` 로 그려져 명암비 2.6:1 (기준 4.5:1)
9. 느린 응답이 뒤늦게 도착해 이미 바뀐 화면을 덮어써, 주소와 화면이 어긋남
10. 열람 기록에 아무 기록 id 나 넣을 수 있어, 열지 않은 기록으로 열람 등급을 최고까지 올릴 수 있었음
11. 언어를 바꿔도 사이드바는 이전 언어로 남음 (사이드바에는 `data-i18n` 이 없다)
12. 모달을 여는 중에는 ESC 가 먹지 않고, 화면을 떠난 뒤에 모달이 뒤늦게 열림
13. 서버 오류 7종에 문구가 없어 "알 수 없는 오류" 로 표시
14. `run.sh` 가 psql 오류 형식을 잘못 찾아, SQL 적재 실패를 성공으로 보고

셔임에도 같은 성격의 결함이 있었습니다. `select=` 를 무시하고 항상 모든 컬럼을 읽어,
컬럼 단위로 회수한 권한 때문에 실제로는 되는 조회가 셔임에서만 막혔습니다.
그 탓에 위 10번의 공격 경로가 재현되지 않아 검사가 통과할 뻔했습니다.

`suite-style.js` 는 규칙을 문서로 확인하지 않고 **브라우저가 실제로 계산한 색**을 읽어
WCAG 명암비를 직접 산출합니다. `aria-hidden` 인 장식 문자는 기준 대상에서 제외합니다.

셋 다 명세만 읽어서는 드러나지 않고, 실제로 화면을 조작해야 나오는 종류입니다.
