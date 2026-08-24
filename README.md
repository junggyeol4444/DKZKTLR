# AKASHIC RECORDS — Universal Information Archive

전 우주의 기록을 보관한다는 설정의 **공개 아카이브 웹사이트**입니다.
가입한 사용자가 실제 역사 기록을 작성해 함께 쌓고, 열람한 만큼 접근 등급이 올라갑니다.

- 프론트엔드: HTML + CSS + JavaScript (프레임워크 없음, 빌드 없음)
- 백엔드: **Supabase** (Auth + PostgreSQL + Row Level Security)
- 지원 언어: 한국어 / English / 日本語

---

## 1. 프로젝트 소개

SCP 재단 문서 같은 기밀 자료실 분위기의 아카이브입니다.
검은 배경에 금색과 빨간색을 강조색으로 쓰고, 낡은 종이 질감의 카드로 기록을 보여줍니다.

기록은 **행성 → 대분류 → 중분류 → 기록 목록**의 4단계로 탐색하며,
각 기록에는 보안등급(LEVEL-1~5)이 있어 열람자의 등급이 낮으면 본문이 봉인됩니다.

이 저장소의 시드 기록 30건은 모두 **실제 역사적 사건**이며 출처를 명시했습니다.
창작된 사건·인물·수치는 포함하지 않습니다.

---

## 2. 사용 방법

### 가입
1. 첫 화면에서 **등록 신청**을 누릅니다.
2. 이메일 / 암호(8자 이상) / 표시 이름 / 언어를 입력하고 규약에 동의합니다.
3. 발송된 인증 메일의 링크를 눌러야 로그인할 수 있습니다.
4. 인증이 끝나면 `KEEPER-001` 형식의 열람자 코드가 발급되고 기본 등급은 **LEVEL-2 (Β)** 입니다.

### 탐색
- 행성 카드 → 대분류 → 중분류 → 기록 목록 순으로 들어갑니다.
- 기록 카드를 누르면 상세 모달이 열립니다. `ESC`, 배경 클릭, `✕` 로 닫습니다.
- 주소창의 해시가 위치를 그대로 담고 있어 새로고침·뒤로가기·링크 공유가 모두 동작합니다.

### 기록 작성
- 사이드바의 **기록 작성** 버튼으로 들어갑니다.
- 행성·카테고리·중분류를 고르고, 언어 탭(KO/EN/JA)별로 제목·요약·본문을 입력합니다. **한국어는 필수**입니다.
- 사건일, 태그(1~8개), **출처(필수)**, 보안등급(본인 등급 이하)을 채우고 등록합니다.
- 작성 제한: 이메일 인증 필수 / 하루 10건 / 연속 작성 60초 간격 / 제목·본문이 같은 기록 중복 등록 불가.

### 등급 상승
서로 다른 기록을 열람한 수에 따라 서버가 자동으로 올려 줍니다.

| 열람 수 | 등급 |
|---|---|
| 가입 시 | LEVEL-2 (Β) |
| 10건 | LEVEL-3 (Γ) |
| 30건 | LEVEL-4 (Δ) |
| 60건 | LEVEL-5 (Θ) |

---

## 3. 기능 목록

- 회원가입 / 로그인 / 이메일 인증 / 인증 메일 재발송 / 비밀번호 재설정 / 로그아웃
- 4단계 탐색과 상세 모달, 해시 라우팅(뒤로가기·새로고침·딥링크)
- 다국어 전환 (UI 문자열 + 기록 데이터 모두)
- 기록 작성 / 수정 / 삭제(소프트 삭제, 본인 기록만)
- 북마크 (계정 단위 저장 — 다른 기기·브라우저에서도 유지)
- 최근 조회 5건
- 열람 등급과 자동 등급 상승, 등급 미달 기록의 본문 봉인
- 정렬 5종, 20건 단위 페이지네이션
- 신고(5종 사유) 및 서로 다른 3명 신고 시 자동 숨김
- 내가 쓴 기록 목록(공개 / 숨김 / 삭제됨 상태 배지)
- 전문 검색 (PostgreSQL full-text search)
- 관리자 권한 (`profiles.is_admin`)
- 빈 상태 / 네트워크·권한·세션 오류 화면
- 모션 감소 대응 (`prefers-reduced-motion` + 수동 토글)

---

## 4. 기술 스택

| 영역 | 사용 기술 |
|---|---|
| 마크업·스타일 | HTML5, CSS(변수·Grid·Flexbox), 빌드 도구 없음 |
| 스크립트 | 순수 JavaScript (ES2020), 모듈 번들러 없음 |
| 인증 | Supabase Auth (이메일 + 비밀번호, 이메일 인증) |
| 데이터베이스 | Supabase PostgreSQL |
| 권한 | Row Level Security + 컬럼 단위 GRANT + 트리거 |
| 검색 | PostgreSQL `tsvector` / GIN 인덱스 |
| 클라이언트 SDK | `@supabase/supabase-js` v2 (CDN) |

### 파일 구조

```
akashic-records/
├── index.html      모든 화면의 마크업 (텍스트는 data-i18n 키로만)
├── style.css       색상·폰트·카드·모달·반응형·모션 감소
├── i18n.js         UI 문자열 사전 (ko / en / ja, 171개 키)
├── supabase.js     클라이언트 초기화 (anon 키만)
├── api.js          DB 질의 함수와 오류 정규화
├── app.js          해시 라우팅 · 렌더링 · 이벤트
├── sql/
│   ├── schema.sql  테이블 · 인덱스 · 함수 · 트리거 · 집계 뷰 · RPC
│   ├── rls.sql     RLS 정책
│   └── seed.sql    행성 5 / 대분류 9 / 중분류 39 / 기록 30건
└── README.md
```

---

## 5. Supabase 설정 절차

1. [supabase.com](https://supabase.com) 에서 프로젝트를 만듭니다.
2. **SQL Editor** 에서 아래 순서대로 실행합니다. 순서를 지켜야 합니다.
   1. `sql/schema.sql`
   2. `sql/rls.sql`
   3. `sql/seed.sql`
3. **Authentication → Providers → Email** 에서 `Confirm email` 을 켭니다.
4. **Authentication → URL Configuration**
   - `Site URL` : 배포 도메인 (로컬 테스트 중이면 `http://localhost:8080`)
   - `Redirect URLs` : 위 주소와 비밀번호 재설정용 `<도메인>/#/reset-confirm`
5. **Project Settings → API** 에서 `Project URL` 과 `anon public` 키를 복사해
   `supabase.js` 상단 두 상수에 넣습니다.

```js
const SUPABASE_URL      = 'https://xxxxxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOi...';
```

또는 `index.html` 의 스크립트 태그들보다 앞에서 다음을 정의해도 됩니다.

```html
<script>window.AKASHIC_CONFIG = { url: '...', anonKey: '...' };</script>
```

### ⚠ 키에 대한 주의

- 프론트엔드에는 **anon 키만** 넣습니다. anon 키는 공개되어도 되는 값이며,
  실제 접근 통제는 데이터베이스의 RLS가 수행합니다.
- **`service_role` 키는 절대 프론트엔드 코드나 저장소에 넣지 마세요.**
  이 키는 RLS를 우회하므로 노출되면 전체 데이터가 열립니다.

### 시스템 계정(KEEPER-000)에 대하여

`seed.sql` 은 시드 기록의 작성자로 쓸 시스템 계정을 `auth.users` 에 직접 만듭니다.
프로젝트 설정에 따라 이 삽입이 거부될 수 있는데, 그 경우에도 스크립트는 멈추지 않고
`author_id` 를 비운 채 진행하며 화면에는 `KEEPER-000` 으로 표시됩니다(기능상 문제 없음).
직접 지정하고 싶다면 계정을 하나 가입시킨 뒤 다음을 실행하세요.

```sql
update public.profiles
   set keeper_code = 'KEEPER-000', display_name = 'ARCHIVE SYSTEM',
       level = 5, is_admin = true
 where id = (select id from auth.users where email = '<그 계정의 이메일>');

update public.records set author_id = (select id from public.profiles where keeper_code = 'KEEPER-000')
 where is_seed;
```

### 관리자 지정

```sql
update public.profiles set is_admin = true
 where id = (select id from auth.users where email = '<관리자 이메일>');
```

관리자는 숨김 처리된 기록의 상태를 되돌리거나 기록을 삭제할 수 있습니다.

---

## 6. 로컬 실행 방법

빌드가 없으므로 정적 파일 서버 하나면 됩니다. `file://` 로 직접 열면
Auth 리디렉션과 세션 저장이 동작하지 않으니 반드시 HTTP로 띄우세요.

```bash
# Python
python3 -m http.server 8080

# 또는 Node
npx http-server -p 8080
```

브라우저에서 `http://localhost:8080` 을 엽니다.
Supabase 대시보드의 `Site URL` 과 `Redirect URLs` 에도 같은 주소를 등록해야
가입 인증 메일의 링크가 되돌아옵니다.

---

## 7. 배포 방법 및 도메인 연결

GitHub Pages 도 정적 호스팅이므로 동작하지만, Auth 리디렉션과 도메인 관리 편의를 고려해
**Vercel 또는 Netlify** 를 권장합니다.

### Vercel

1. 저장소를 연결합니다. 빌드 명령 없음, 출력 디렉터리는 저장소 루트입니다.
2. 배포 후 **Settings → Domains** 에서 구입한 도메인을 추가합니다.
3. 도메인 등록업체의 DNS에 Vercel이 알려주는 레코드를 추가합니다. HTTPS 인증서는 자동 발급됩니다.

### Netlify

1. 저장소를 연결합니다. Build command 비움, Publish directory 는 `.` 입니다.
2. **Domain settings** 에서 도메인을 추가하고 DNS를 연결합니다.

### 배포 후 반드시 할 것

Supabase **Authentication → URL Configuration** 의 `Site URL` 을 실제 도메인으로 바꾸고,
`Redirect URLs` 에 `https://<도메인>/` 과 `https://<도메인>/#/reset-confirm` 을 추가합니다.
이 작업을 하지 않으면 인증 메일의 링크가 localhost 로 돌아갑니다.

---

## 8. 지원 언어와 언어 추가 방법

기본 지원은 `ko` / `en` / `ja` 입니다. UI 문자열과 기록 데이터가 모두 다국어입니다.
값이 없으면 **요청 언어 → ko → en** 순으로 대체하고, 셋 다 없으면 `—` 를 표시합니다.

새 언어(예: 중국어 `zh`)를 추가하려면:

1. `i18n.js` 의 `LANGS` 배열에 `'zh'` 를 추가하고, `I18N` 에 `ko` 와 같은 키 집합을 가진 `zh` 객체를 넣습니다.
2. `index.html` 의 `tpl-langpicker` 템플릿에 버튼을 하나 추가합니다.
3. `style.css` 에 `body.lang-zh { --font-body: ...; --font-title: ...; }` 를 추가합니다.
4. DB의 언어 제약을 넓힙니다.

```sql
alter table public.profiles drop constraint profiles_lang_check;
alter table public.profiles add constraint profiles_lang_check check (lang in ('ko','en','ja','zh'));
```

5. 기록의 `title` / `summary` / `content` jsonb 에 `"zh"` 키를 넣으면 그대로 표시됩니다.
   전문 검색에도 넣으려면 `schema.sql` 의 `records_tsv()` 함수에 `zh` 항목을 추가하고
   `records` 의 `search_vector` 생성 컬럼을 다시 만드십시오.

---

## 9. 브라우저 호환성

Chrome / Edge / Firefox / Safari 각 최신 2개 버전을 대상으로 합니다.
ES2020 문법(옵셔널 체이닝, `??`)과 CSS 사용자 정의 속성, Grid, Flexbox를 사용합니다.
Internet Explorer는 지원하지 않습니다.

접근성:

- 모든 입력에 `label`(`for`/`id`) 연결, 포커스 표시 유지(`outline` 제거 안 함)
- 모달은 포커스 이동·복귀와 Tab 트랩 처리, `ESC` 로 닫힘
- 터치 영역 최소 44×44px
- `prefers-reduced-motion: reduce` 에서 깜빡임·노이즈·전환 효과 정지 (사이드바의 수동 토글도 제공)
- 색상 대비: 본문 `#c9c5ba` on `#1a1612` ≈ 10.4:1, 강조 `#d4af37` on `#0d0d0d` ≈ 9.2:1.
  `#8b0000` 은 테두리·배경 전용, 빨간 글씨는 `#ff6b6b`(≈7.0:1)만 사용합니다.

---

## 10. 데이터 출처 목록

시드 기록 30건의 출처는 각 기록의 `source` 필드에 그대로 들어 있습니다.
주요 출처는 다음과 같습니다.

**지구 (22건)**
- Musée du Louvre, Sb 8 (Code of Hammurabi stele); Martha T. Roth, *Law Collections from Mesopotamia and Asia Minor* (1997)
- 司馬遷, 『史記』 卷六 秦始皇本紀; *The Cambridge History of Ancient China* (1999)
- Pliny the Younger, *Epistulae* 6.16 / 6.20; Parco Archeologico di Pompei
- Ole J. Benedictow, *The Black Death 1346–1353* (2004); Bos et al., *Nature* 478 (2011)
- 『訓民正音』 解例本 (국보 제70호); 『世宗實錄』 卷113; UNESCO Memory of the World (1997)
- British Library, Gutenberg Bible digitisation project; Gutenberg-Museum Mainz
- Copernicus, *De revolutionibus orbium coelestium* (1543); Gingerich, *An Annotated Census* (2002)
- British Patent No. 913 (1769); Science Museum Group, Boulton & Watt archive
- Archives nationales de France; Simon Schama, *Citizens* (1989)
- Smithsonian Global Volcanism Program, Tambora (264040); Oppenheimer, *Progress in Physical Geography* 27 (2003)
- Beethoven-Haus Bonn; Barry Cooper, *Beethoven* (2000)
- Darwin, *On the Origin of Species* (1859); Darwin Correspondence Project
- Library of Congress, Wright Papers; Smithsonian National Air and Space Museum
- Christopher Clark, *The Sleepwalkers* (2012); Imperial War Museums
- Taubenberger & Morens, *Emerging Infectious Diseases* 12(1) (2006); US CDC
- US Department of Energy, *The Manhattan Project*; Richard Rhodes, *The Making of the Atomic Bomb* (1986)
- Watson & Crick, *Nature* 171, 737–738 (1953); Franklin & Gosling, *Nature* 171, 740–741 (1953)
- NASA, *Apollo 11 Mission Report* (MSC-00171); Apollo Lunar Surface Journal
- UCLA Kleinrock Internet History Center, IMP Log (1969-10-29); Internet Society
- IAEA INSAG-7 (1992); UNSCEAR 2008 Report Vol. II Annex D
- Berners-Lee, *Information Management: A Proposal* (CERN, 1989); CERN, *The birth of the web*
- Anne Frank House; *The Diary of Anne Frank: The Revised Critical Edition* (NIOD)

**화성 (4건)** — NASA SP-441 (Viking); NASA/JPL (MSL, Ingenuity, InSight);
Grotzinger et al., *Science* 343 (2014); Balaram et al., AIAA 2018-0023; Banerdt et al., *Nature Geoscience* 13 (2020)

**타이탄 (2건)** — ESA Cassini–Huygens; Lebreton et al., *Nature* 438 (2005); Stofan et al., *Nature* 445 (2007)

**외계행성 (2건)** — Torres et al., *ApJ* 800, 99 (2015); NASA Exoplanet Archive;
Anglada-Escudé et al., *Nature* 536 (2016); ESO Pale Red Dot

---

## 11. 라이선스

- **코드**: MIT License (`LICENSE` 참조)
- **폰트**: 이 프로젝트는 폰트 파일을 포함하지 않고 Google Fonts에서 불러옵니다.
  - Special Elite — SIL Open Font License 1.1
  - Courier Prime — SIL Open Font License 1.1
  - Noto Serif / Noto Serif KR / Noto Serif JP — SIL Open Font License 1.1
- **기록 내용**: 시드 기록의 서술은 이 저장소의 창작물이며 코드와 같은 라이선스를 따릅니다.
  다만 각 기록이 인용한 원 출처(논문·도서·기관 자료)의 권리는 해당 권리자에게 있습니다.

---

## 부록: 운영 시 확인할 것

- Supabase 무료 티어 한도(데이터베이스 용량, 월 활성 사용자, 대역폭)를 주기적으로 확인하세요.
  초과 시 서비스가 중단될 수 있습니다.
- Supabase 대시보드에서 정기 백업을 설정하세요.
- 신고가 누적되어 숨겨진 기록을 주기적으로 검토하세요.

```sql
-- 신고 누적으로 숨겨진 기록
select r.record_code, r.title ->> 'ko' as title, count(rp.*) as reports
  from public.records r join public.reports rp on rp.record_id = r.id
 where r.status = 'hidden'
 group by r.id order by reports desc;

-- 숨김 해제 (관리자 계정으로)
update public.records set status = 'published' where record_code = 'REC-...';
```

- 행성을 열람 제한 구역으로 바꾸려면:

```sql
update public.planets set status = 'RESTRICTED', required_level = 4 where id = 'EXOPLANET-PCB';
```

  이렇게 하면 해당 행성 카드에 자물쇠와 `CLEARANCE INSUFFICIENT` 오버레이가 표시되고,
  등급이 낮은 사용자에게는 그 행성의 기록 본문이 응답에서 제외됩니다.
