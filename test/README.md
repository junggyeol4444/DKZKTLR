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
| `suite-ui.js` | 16 | 페이지네이션 · 언어 탭 · 폼 상한 · 신고 UI · 세션 만료 · 드로어 · 회귀 2건 |
| `suite-related.js` | 6 | `related_ids` 에 삭제·숨김 항목이 섞였을 때의 참조 무결성 |

합계 70개 검사.

명세서 7.2 의 시나리오 20개 중 다음은 여기서 다루지 않습니다.
실제 Supabase 프로젝트가 있어야 확인됩니다.

- 인증 메일과 재설정 메일의 실제 수신, 그 링크를 눌러 돌아오는 왕복
- 배포 도메인과 Auth 리디렉션 설정

## 이 하네스가 잡은 결함

1. `[hidden]` 이 `.screen` / `#app` / `.modal` 의 `display:flex` 에 덮여 모든 화면이 겹쳐 렌더링됨
2. 신고 3건 누적 시 상태를 바꾸는 트리거가 기록 소유자 검사에 막혀 숨김 처리가 동작하지 않음
3. 공유 링크로 곧바로 연 탭에서 모달을 닫으면 `history.back()` 이 사이트 밖으로 나감

셋 다 명세만 읽어서는 드러나지 않고, 실제로 화면을 조작해야 나오는 종류입니다.
