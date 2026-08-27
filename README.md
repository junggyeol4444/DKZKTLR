# ◈ AKASHIC RECORDS

사람과 세계의 지식을 출처·시점·관계로 연결해 보존하는 **공동 지식 아카이브**입니다. 이름은 모든 사건과 생각의 흔적이 보존된다는 오래된 “아카식 레코드” 개념에서 가져왔지만, 초자연적 세계관이나 외계 문명 설정을 사실로 다루지 않습니다. 역사·과학·기술·예술·인물·장소·사상·개인의 경험까지 출처와 맥락을 갖춘 기록이라면 담을 수 있도록 재해석했습니다.

이 저장소는 이전의 `data.json + LocalStorage` 데모가 아닙니다. Supabase Auth, Postgres, RLS를 사용하는 다중 사용자 웹사이트이며 기록·북마크·열람 이력은 서버에서 동기화됩니다.

## 주요 기능

- 이메일 인증 기반 가입, 로그인, 로그아웃, 비밀번호 재설정
- 지식 영역 → 분류 → 기록으로 이어지는 해시 라우팅과 직접 링크
- 한국어·영어·일본어 UI 및 JSONB 기반 기록 번역
- 출처가 필수인 공유 기록 작성, 본인 기록 관리, 소프트 삭제 기반 데이터 모델
- 계정 단위 북마크와 최근 열람, 서로 다른 기록 열람에 따른 등급 상승
- 서버 RPC에서 열람 등급을 확인해 제한된 본문을 응답에서 제외
- 일 10건/60초 간격/동일 내용 중복 차단과 중복 신고 방지
- 신고 3건 누적 시 기록을 지우지 않고 검토 회의를 열며, 서로 다른 관리자 3명의 다수결로 유지/숨김 결정
- Postgres 전문 검색, DB 집계 뷰, 20개 단위 페이지 조회 기반 API
- ko/en/ja 기록 작성·수정, 소프트 삭제, 관련 기록 점수 추천
- 키보드 포커스, 모션 감소, 태블릿·모바일 내비게이션을 포함한 반응형 UI

## 기술 스택과 구조

빌드 도구와 프레임워크 없이 HTML/CSS/JavaScript로 구성됩니다. 브라우저에서는 Supabase JS v2 CDN을 사용합니다.

```text
├── index.html          접근 가능한 앱 셸
├── style.css           디자인 시스템과 반응형 UI
├── i18n.js             ko/en/ja UI 사전
├── supabase.js         공개 클라이언트 초기화
├── api.js              데이터 접근 계층
├── app.js              인증·라우팅·렌더링·이벤트
├── config.example.js   공개 설정 예시
└── sql/
    ├── schema.sql      스키마, 인덱스, 함수, 트리거, 안전한 조회 RPC
    ├── rls.sql         RLS 정책과 권한 부여
    ├── seed.sql        지식 분류와 출처가 있는 30개 초기 기록
    └── migrations/     기존 설치용 순차 마이그레이션
```

LocalStorage는 `akashic_lang`, `akashic_sort`, `akashic_motion`만 사용합니다. 계정, 기록, 북마크를 저장하지 않습니다.

## Supabase 설정

1. [Supabase](https://supabase.com/)에서 프로젝트를 만듭니다.
2. SQL Editor에서 다음 파일을 **순서대로** 실행합니다.
   1. `sql/schema.sql`
   2. `sql/rls.sql`
   3. `sql/seed.sql`
3. Authentication → Providers에서 Email을 활성화하고 이메일 확인을 켭니다.
4. Authentication → URL Configuration에 로컬 URL과 실제 배포 URL을 Redirect URL로 추가합니다.
5. `config.example.js`를 `config.js`로 복사하고 Project Settings → API의 Project URL과 **anon/public key**를 입력합니다.

이미 이전 버전을 설치했다면 전체 스키마를 다시 실행하지 말고 `sql/migrations/001_moderation_council.sql`을 한 번 실행합니다. 이 마이그레이션은 기존의 “신고 3건 즉시 숨김” 트리거를 제거하고 검토 회의 및 관리자 투표 테이블로 교체합니다.

그 다음 `sql/migrations/002_records_completion.sql`을 실행해 기록 필드 무결성 검사, 자기 신고 차단, 안전한 전문 검색·열람 RPC와 관련 기록 추천을 추가합니다. 마이그레이션 파일은 번호 순서대로 한 번씩 실행해야 합니다.

```js
window.AKASHIC_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
  supabaseAnonKey: 'YOUR_PUBLIC_ANON_KEY'
};
```

`config.js`는 Git에서 제외됩니다. anon 키는 RLS 적용을 전제로 브라우저에서 사용하는 공개 키이지만, 프로젝트별 배포 설정은 별도로 관리하는 편이 안전합니다. **service_role 키는 절대로 브라우저, 저장소, Vercel/Netlify 클라이언트 환경변수에 넣지 마세요.** 이 키는 RLS를 우회합니다.

### 보안 구조

- 모든 테이블은 RLS가 활성화되고 anon 접근은 거부됩니다.
- 기록의 작성자와 등급은 DB 트리거와 정책에서 다시 검사합니다.
- `profiles.level`, `profiles.is_admin`, `keeper_code`에는 클라이언트 UPDATE 권한이 없습니다.
- `get_record_for_reader()`는 사용자의 DB 등급을 확인하고, 부족하면 `content`를 `NULL`로 반환합니다.
- `records.content`와 검색용 `search_document`에는 authenticated SELECT 권한이 없습니다. 검색은 검색 벡터를 응답하지 않는 전용 RPC로만 처리됩니다.
- `record_views`에는 클라이언트 INSERT/UPDATE 권한이 없습니다. 실제 상세 조회 RPC가 성공한 경우에만 서버가 열람을 기록합니다.
- 삭제는 `deleted_at`을 사용하는 소프트 삭제이며, FK에는 하드 삭제 시 `ON DELETE CASCADE`가 적용됩니다.
- 실제 운영에서는 SQL Editor에서 관리자 프로필의 `is_admin`만 직접 지정하고 정기 백업 및 신고 검토 절차를 마련해야 합니다.

### 신고 및 검토 회의

1. 같은 사용자는 한 기록을 한 번만 신고할 수 있습니다.
2. 서로 다른 사용자 신고가 3건 모이면 기록 상태가 `under_review`로 바뀌고 검토 회의가 생성됩니다.
3. `under_review` 기록은 검색·목록·상세 화면에서 계속 공개되므로, 조직적인 신고만으로 사라지지 않습니다.
4. 관리자는 사이드바의 **검토 회의**에서 원문 출처, 신고 사유, 다른 관리자의 판단 근거를 확인합니다.
5. 기록 작성자를 제외한 서로 다른 관리자 3명이 각각 유지 또는 숨김에 투표합니다.
6. 세 번째 표가 등록되면 DB 트리거가 다수결을 계산합니다. 유지가 다수면 `published`, 숨김이 다수면 `hidden`으로 변경됩니다.
7. 검토 의견은 회의 기록에 남으며 같은 관리자는 같은 회의에 중복 투표할 수 없습니다.

## 로컬 실행

ES 모듈 빌드는 없지만 브라우저 보안 정책과 Auth 리디렉션을 위해 파일을 직접 열지 말고 HTTP 서버를 사용합니다.

```bash
cp config.example.js config.js
python3 -m http.server 4173
```

`http://localhost:4173`을 열고 이 주소를 Supabase Auth Redirect URL에 등록합니다. `config.js`가 없거나 값이 비어 있으면 앱이 비밀스럽게 실패하지 않고 설정 안내 화면을 표시합니다.

## 사용 방법

1. 첫 화면에서 언어를 선택하고 **기록자 등록**을 누릅니다.
2. 인증 메일의 링크를 연 뒤 로그인합니다.
3. 홈에서 지식 영역을 선택하거나 검색해 기록을 탐색합니다.
4. 기록 카드에서 상세 문서를 열고 북마크할 수 있습니다.
5. **새 기록**에서 지식 영역, 분류, 제목, 요약, 본문, 대상 시점, 태그, 출처 URL을 작성합니다.
6. 작성한 기록의 상세 화면에서 수정·삭제할 수 있으며 KO/EN/JA 탭으로 번역을 관리할 수 있습니다.
7. 개인의 경험도 기록할 수 있지만, 직접 경험인지 전언인지 밝히고 공개 가능한 자료만 사용해야 합니다. 사실 주장에는 검증 가능한 출처를 연결하세요.

## 개발 검증

빠른 정적 검사와 실제 PostgreSQL 통합 검사를 모두 제공합니다. 통합 검사는 임시 PostgreSQL 클러스터에 스키마·RLS·시드·마이그레이션을 실제 적재하고 권한 공격 시나리오를 실행합니다.

```bash
node tests/verify.mjs
node --check app.js
node --check api.js
test/run.sh
cd test && npm install && npx playwright install chromium && npm run browser
```

`test/run.sh`는 다음을 실제 DB 권한으로 검증합니다: 스키마 설치, 고등급 본문 직접 SELECT 차단, 검색 벡터 차단, `record_views` 직접 조작 차단, RPC 본문 검열과 실제 열람 기록, 이메일 인증 사용자 작성, 3번째 신고의 검토 회의 생성, 백만 번째 기록 코드와 천 번째 KEEPER 코드 경계. GitHub Actions는 PostgreSQL 15와 17에서 같은 검사를 실행합니다.

브라우저 검사는 Supabase SDK와 응답을 결정론적으로 대체한 뒤 배포되는 원본 HTML/CSS/JavaScript를 Chromium에서 실행합니다. 유효 세션의 경고 화면 자동 건너뛰기, 비로그인 로그인·가입·재설정 화면, 지식 영역 탐색, 전문 검색, 기록 상세 모달과 ESC, 신고 제출, 관리자 검토 회의, 다국어 기록 저장, 모바일 드로어, 가로 오버플로와 언어 전환을 실제 DOM 조작으로 확인합니다. 이메일 전달과 실제 토큰 갱신은 별도의 Supabase 스테이징 프로젝트에서 최종 확인해야 합니다.

## 다국어 확장

- UI: `i18n.js`에 언어 객체를 추가하고 `getLanguage()`의 지원 언어 배열과 선택 옵션을 확장합니다.
- 데이터: `title`, `summary`, `content`, 분류명은 `{ "ko": "…", "en": "…", "ja": "…" }` JSONB입니다.
- 폴백 순서는 선택 언어 → ko → en → `—`입니다.
- 날짜는 DB에 ISO 형식으로 저장하고 브라우저에서 선택 언어 로케일로 표시합니다.

## 배포

### Vercel

저장소를 Import하고 Framework Preset을 `Other`, Output Directory를 `.`로 둡니다. 배포 환경에서 생성한 `config.js`를 제공하거나 배포 전 공개 설정을 주입하는 스크립트를 사용합니다. 사용자 도메인을 연결한 뒤 그 HTTPS 주소를 Supabase Site URL과 Redirect URLs에 등록합니다.

### Netlify

저장소를 연결하고 Publish directory를 `.`로 지정합니다. 별도 Build command는 필요 없습니다. 사용자 도메인의 DNS/HTTPS 설정 후 동일하게 Supabase Auth URL을 갱신합니다.

## 초기 데이터와 출처

`sql/seed.sql`에는 화면이 비어 보이지 않도록 8개 지식 영역, 16개 분류, 30개 기록이 들어 있습니다. 각 기록은 NASA, ESA, UN, UNESCO, WHO, CERN, Nobel Prize, 박물관·국립공원 등 원문 기관 또는 대표 참고자료 URL을 `source`로 가집니다. 시드는 `is_seed = true`, 작성자는 `KEEPER-000`으로 구분됩니다. 시드를 제거할 때는 참조 데이터와 함께 트랜잭션으로 하드 삭제하거나 소프트 삭제 정책을 적용하세요.

시드의 짧은 본문은 완성된 백과사전 문서가 아니라 탐색 구조를 보여 주는 사실 카드입니다. 공개 운영 전에 편집 검토를 거쳐 추가 출처, 정확한 지역, 다국어 번역을 보강하는 것을 권장합니다.

## 브라우저 지원

Chrome, Edge, Firefox, Safari 최신 2개 주요 버전을 대상으로 합니다. `prefers-reduced-motion`을 지원하며 수동 설정도 제공합니다.

## 현재 확인이 필요한 운영 항목

- 실제 Supabase 프로젝트, SMTP, 이메일 템플릿 및 사용자 도메인은 저장소만으로 생성할 수 없습니다.
- 다계정 가입/메일 인증/신고 3인 처리/등급 상승은 연결된 프로젝트에서 통합 테스트해야 합니다.
- 관리자 검토 회의와 3인 투표는 구현되어 있습니다. 다만 운영자는 최소 3명의 독립적인 관리자 계정을 지정해야 하며, 이의제기·재심 정책은 별도로 정해야 합니다.
- 첨부 파일 저장, 기록 개정 이력, 관리자 활동 감사 로그와 사용자 이의제기·재심 워크플로는 후속 운영 기능입니다.
- 개인 경험을 공개하는 서비스이므로 정식 배포 전 이용약관, 개인정보 처리방침, 콘텐츠 라이선스, 삭제 요청 절차를 법률 검토해야 합니다.

## 라이선스

코드 라이선스는 운영자가 선택해 명시해야 합니다. 현재 외부 폰트는 Google Fonts를 통해 로드하며 Noto 계열은 SIL Open Font License, Special Elite와 Courier Prime의 배포 조건은 각 폰트 배포 페이지를 확인하세요. 사용자 작성 콘텐츠의 라이선스는 이용약관에서 별도로 정해야 합니다.
