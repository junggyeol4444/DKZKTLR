-- ============================================================
--  AKASHIC RECORDS  /  sql/seed.sql
--  초기 시드 데이터 (0.7 / 5.5)
--  실행 순서: schema.sql -> rls.sql -> seed.sql
--
--  ※ 이 시드의 기록은 모두 실제 역사적 사건이며 source 를 채웠습니다. (5.3)
--  ※ 시드 기록은 is_seed = true 로 표시됩니다.
--     나중에  delete from public.records where is_seed;  로 일괄 삭제해도
--     bookmarks / record_views / reports 는 FK CASCADE 로 함께 정리되고,
--     related_ids 는 조회 시 존재 여부를 다시 확인하므로 화면이 깨지지 않습니다. (4.9)
-- ============================================================

-- ------------------------------------------------------------
-- 0. 시스템 계정 KEEPER-000
--    Supabase SQL Editor(postgres)에서 auth.users 에 직접 넣습니다.
--    권한 문제로 실패하면 예외를 무시하고 넘어가며,
--    이 경우 시드 기록의 author_id 는 NULL 이 되고 화면에는
--    v_records 뷰가 'KEEPER-000' 으로 표기합니다. (기능상 문제 없음)
-- ------------------------------------------------------------
do $$
declare
  v_sys uuid := '00000000-0000-4000-a000-000000000000';
begin
  begin
    insert into auth.users (
      instance_id, id, aud, role, email,
      encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_sys, 'authenticated', 'authenticated',
      'keeper000@akashic.invalid',
      crypt(gen_random_uuid()::text, gen_salt('bf')),   -- 로그인 불가용 임의 값
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"display_name":"ARCHIVE SYSTEM","lang":"ko"}'::jsonb,
      now(), now()
    )
    on conflict (id) do nothing;
  exception when others then
    raise notice 'auth.users 시스템 계정 생성 생략: %', sqlerrm;
  end;

  -- 트리거가 만든 프로필을 시스템 계정으로 확정
  update public.profiles
     set keeper_code = 'KEEPER-000',
         display_name = 'ARCHIVE SYSTEM',
         level = 5,
         is_admin = true
   where id = v_sys;

  -- 시스템 계정이 소비한 순번을 되돌려 실제 가입자가 KEEPER-001 부터 받도록
  perform setval('public.keeper_code_seq', 1, false);
end $$;

-- ------------------------------------------------------------
-- 1. 행성 5 (5.5)
-- ------------------------------------------------------------
insert into public.planets (id, name, location, status, required_level, sort_order) values
('TERRA-001',
 '{"ko":"지구","en":"Earth","ja":"地球"}',
 '{"ko":"태양계 제3행성","en":"Third planet of the Solar System","ja":"太陽系第3惑星"}',
 'ACTIVE', 1, 1),
('TERRA-002',
 '{"ko":"화성","en":"Mars","ja":"火星"}',
 '{"ko":"태양계 제4행성","en":"Fourth planet of the Solar System","ja":"太陽系第4惑星"}',
 'ACTIVE', 1, 2),
('MOON-TITAN',
 '{"ko":"타이탄","en":"Titan","ja":"タイタン"}',
 '{"ko":"토성의 최대 위성","en":"Largest moon of Saturn","ja":"土星最大の衛星"}',
 'ACTIVE', 1, 3),
('EXOPLANET-442',
 '{"ko":"케플러-442b","en":"Kepler-442b","ja":"ケプラー442b"}',
 '{"ko":"거문고자리 방향, 약 1,200광년","en":"Toward Lyra, about 1,200 light-years","ja":"こと座方向、約1,200光年"}',
 'DORMANT', 1, 4),
('EXOPLANET-PCB',
 '{"ko":"프록시마 센타우리 b","en":"Proxima Centauri b","ja":"プロキシマ・ケンタウリb"}',
 '{"ko":"센타우루스자리, 약 4.24광년","en":"Centaurus, about 4.24 light-years","ja":"ケンタウルス座、約4.24光年"}',
 'DORMANT', 1, 5)
on conflict (id) do update
  set name = excluded.name, location = excluded.location,
      status = excluded.status, required_level = excluded.required_level,
      sort_order = excluded.sort_order;

-- ------------------------------------------------------------
-- 2. 대분류 9 (2.7)
-- ------------------------------------------------------------
insert into public.categories (id, name, description, sort_order) values
('NAT-001',
 '{"ko":"자연현상","en":"Natural Phenomena","ja":"自然現象"}',
 '{"ko":"화산·지진·기상·천체 충돌 등 자연이 남긴 기록","en":"Volcanism, seismicity, weather and impact events","ja":"火山・地震・気象・天体衝突などの記録"}', 1),
('CIV-002',
 '{"ko":"문명발달","en":"Civilization","ja":"文明発達"}',
 '{"ko":"국가와 제도, 도시와 사회 구조의 형성","en":"States, institutions, cities and social structures","ja":"国家・制度・都市・社会構造の形成"}', 2),
('WAR-003',
 '{"ko":"전쟁사","en":"Military History","ja":"戦争史"}',
 '{"ko":"무력 충돌과 군사 기술의 전개","en":"Armed conflict and the development of military technology","ja":"武力衝突と軍事技術の展開"}', 3),
('TECH-004',
 '{"ko":"기술발전","en":"Technology","ja":"技術発展"}',
 '{"ko":"도구·기계·과학 이론과 그 응용","en":"Tools, machines, scientific theory and their application","ja":"道具・機械・科学理論とその応用"}', 4),
('LIFE-005',
 '{"ko":"생명체","en":"Life","ja":"生命体"}',
 '{"ko":"생물의 진화, 유전, 생태와 멸종","en":"Evolution, genetics, ecology and extinction","ja":"進化・遺伝・生態・絶滅"}', 5),
('EVENT-006',
 '{"ko":"사건기록","en":"Events","ja":"事件記録"}',
 '{"ko":"재난·혁명·발견 등 특정 시점의 사건","en":"Disasters, revolutions, discoveries and other point events","ja":"災害・革命・発見などの出来事"}', 6),
('ART-007',
 '{"ko":"예술/문화","en":"Art & Culture","ja":"芸術・文化"}',
 '{"ko":"음악·미술·문학·건축이 남긴 흔적","en":"Music, visual art, literature and architecture","ja":"音楽・美術・文学・建築の痕跡"}', 7),
('LANG-008',
 '{"ko":"언어/소통","en":"Language & Communication","ja":"言語・伝達"}',
 '{"ko":"문자, 번역, 매체와 신호 체계","en":"Writing systems, translation, media and signal codes","ja":"文字・翻訳・媒体・信号体系"}', 8),
('PERSON-009',
 '{"ko":"개인 기록","en":"Personal Records","ja":"個人記録"}',
 '{"ko":"일기·서신·증언 등 개인이 남긴 1차 기록","en":"Diaries, letters and testimony left by individuals","ja":"日記・書簡・証言など個人が残した一次記録"}', 9)
on conflict (id) do update
  set name = excluded.name, description = excluded.description, sort_order = excluded.sort_order;

-- ------------------------------------------------------------
-- 3. 중분류 39 (카테고리당 4~6개 / 5.5)
--    planet_ids 가 빈 배열이면 전 행성 공용, 값이 있으면 해당 행성 전용
-- ------------------------------------------------------------
insert into public.subcategories (id, category_id, planet_ids, name, description, level, sort_order) values
-- NAT-001
('VOLCANO','NAT-001','{}',
 '{"ko":"화산 활동","en":"Volcanism","ja":"火山活動"}',
 '{"ko":"분화, 화쇄류, 화산재 기후 영향","en":"Eruptions, pyroclastic flows, ash and climate effects","ja":"噴火・火砕流・火山灰と気候影響"}',1,1),
('SEISMIC','NAT-001','{}',
 '{"ko":"지진 활동","en":"Seismicity","ja":"地震活動"}',
 '{"ko":"지진, 지각 변동, 행성 내부 구조 관측","en":"Quakes, tectonics and interior structure","ja":"地震・地殻変動・内部構造の観測"}',1,2),
('ATMOS','NAT-001','{}',
 '{"ko":"대기와 기상","en":"Atmosphere & Weather","ja":"大気と気象"}',
 '{"ko":"기후 변동, 폭풍, 대기 조성","en":"Climate shifts, storms and atmospheric composition","ja":"気候変動・嵐・大気組成"}',1,3),
('HYDRO','NAT-001','{}',
 '{"ko":"물과 액체 순환","en":"Hydrology","ja":"水と液体循環"}',
 '{"ko":"바다·호수·강, 지구 밖 액체 순환 포함","en":"Seas, lakes and rivers, including non-terrestrial liquid cycles","ja":"海・湖・川、地球外の液体循環を含む"}',1,4),
('IMPACT','NAT-001','{}',
 '{"ko":"천체 충돌","en":"Impact Events","ja":"天体衝突"}',
 '{"ko":"운석·소행성 충돌과 그 흔적","en":"Meteorite and asteroid impacts and their traces","ja":"隕石・小惑星の衝突とその痕跡"}',1,5),
-- CIV-002
('ANCIENT','CIV-002','{}',
 '{"ko":"고대 문명","en":"Ancient Civilizations","ja":"古代文明"}',
 '{"ko":"초기 국가, 법·제도의 성립","en":"Early states and the birth of law and institutions","ja":"初期国家、法と制度の成立"}',1,1),
('MEDIEVAL','CIV-002','{}',
 '{"ko":"중세 사회","en":"Medieval Societies","ja":"中世社会"}',
 '{"ko":"봉건 질서, 종교 조직, 교역망","en":"Feudal order, religious institutions and trade networks","ja":"封建秩序・宗教組織・交易網"}',1,2),
('MODERN-STATE','CIV-002','{}',
 '{"ko":"근대 국가","en":"Modern States","ja":"近代国家"}',
 '{"ko":"주권 국가, 헌법, 관료제의 형성","en":"Sovereign states, constitutions and bureaucracy","ja":"主権国家・憲法・官僚制の形成"}',1,3),
('URBAN','CIV-002','{}',
 '{"ko":"도시와 건축","en":"Cities & Architecture","ja":"都市と建築"}',
 '{"ko":"도시 계획, 대형 구조물, 기반 시설","en":"Urban planning, monumental structures, infrastructure","ja":"都市計画・大型構造物・インフラ"}',1,4),
-- WAR-003
('ANCIENT-WAR','WAR-003','{}',
 '{"ko":"고대 전쟁","en":"Ancient Warfare","ja":"古代戦争"}',
 '{"ko":"고대와 중세의 전투와 원정","en":"Battles and campaigns of antiquity and the middle ages","ja":"古代・中世の戦闘と遠征"}',1,1),
('WORLDWAR','WAR-003','{}',
 '{"ko":"세계 대전","en":"World Wars","ja":"世界大戦"}',
 '{"ko":"20세기 전면전과 그 파급","en":"Total war in the twentieth century and its consequences","ja":"20世紀の総力戦とその影響"}',1,2),
('COLDWAR','WAR-003','{}',
 '{"ko":"냉전","en":"Cold War","ja":"冷戦"}',
 '{"ko":"진영 대립, 억지 전략, 대리전","en":"Bloc rivalry, deterrence and proxy conflict","ja":"陣営対立・抑止戦略・代理戦争"}',2,3),
('WARTECH','WAR-003','{}',
 '{"ko":"군사 기술","en":"Military Technology","ja":"軍事技術"}',
 '{"ko":"무기 체계와 방어 기술의 발전","en":"Weapon systems and defensive technology","ja":"兵器体系と防御技術の発展"}',2,4),
-- TECH-004
('ENERGY','TECH-004','{}',
 '{"ko":"에너지 기술","en":"Energy Technology","ja":"エネルギー技術"}',
 '{"ko":"증기, 전기, 화석연료, 핵분열과 핵융합","en":"Steam, electricity, fossil fuel, fission and fusion","ja":"蒸気・電気・化石燃料・核分裂と核融合"}',1,1),
('INFO','TECH-004','{}',
 '{"ko":"정보 기술","en":"Information Technology","ja":"情報技術"}',
 '{"ko":"인쇄, 계산기, 네트워크와 웹","en":"Printing, computing, networks and the web","ja":"印刷・計算機・ネットワークとウェブ"}',1,2),
('TRANSPORT','TECH-004','{}',
 '{"ko":"운송 기술","en":"Transport","ja":"輸送技術"}',
 '{"ko":"육상·해상·항공 이동 수단","en":"Land, sea and air transport","ja":"陸上・海上・航空の移動手段"}',1,3),
('SCIENCE','TECH-004','{}',
 '{"ko":"과학 이론","en":"Scientific Theory","ja":"科学理論"}',
 '{"ko":"자연을 설명하는 이론 체계의 전환","en":"Shifts in the theoretical description of nature","ja":"自然を説明する理論体系の転換"}',1,4),
('SPACE','TECH-004','{}',
 '{"ko":"우주 기술","en":"Spaceflight","ja":"宇宙技術"}',
 '{"ko":"로켓, 유인 비행, 궤도 및 착륙 기술","en":"Rockets, crewed flight, orbital and landing technology","ja":"ロケット・有人飛行・軌道および着陸技術"}',1,5),
('MISSION','TECH-004','{TERRA-002,MOON-TITAN}',
 '{"ko":"탐사 미션","en":"Exploration Missions","ja":"探査ミッション"}',
 '{"ko":"무인 탐사선의 도달과 관측 (지구 외 천체 전용)","en":"Robotic missions and their observations (non-Earth bodies only)","ja":"無人探査機の到達と観測（地球以外の天体専用）"}',1,6),
-- LIFE-005
('EVOLUTION','LIFE-005','{}',
 '{"ko":"진화","en":"Evolution","ja":"進化"}',
 '{"ko":"종의 변화와 그 설명 이론","en":"Change in species and the theories explaining it","ja":"種の変化とその説明理論"}',1,1),
('GENETICS','LIFE-005','{}',
 '{"ko":"유전학","en":"Genetics","ja":"遺伝学"}',
 '{"ko":"유전 물질의 구조와 해독","en":"Structure and decoding of hereditary material","ja":"遺伝物質の構造と解読"}',1,2),
('ECOLOGY','LIFE-005','{}',
 '{"ko":"생태계","en":"Ecology","ja":"生態系"}',
 '{"ko":"생물과 환경의 상호작용","en":"Interaction between organisms and environment","ja":"生物と環境の相互作用"}',1,3),
('EXTINCT','LIFE-005','{}',
 '{"ko":"멸종","en":"Extinction","ja":"絶滅"}',
 '{"ko":"대량 절멸과 종의 소멸 기록","en":"Mass extinction and the loss of species","ja":"大量絶滅と種の消滅記録"}',2,4),
-- EVENT-006
('DISASTER','EVENT-006','{}',
 '{"ko":"재난과 질병","en":"Disaster & Disease","ja":"災害と疾病"}',
 '{"ko":"대유행, 기근, 광역 재난","en":"Pandemics, famine and wide-area disaster","ja":"大流行・飢饉・広域災害"}',1,1),
('POLITICS','EVENT-006','{}',
 '{"ko":"정치와 혁명","en":"Politics & Revolution","ja":"政治と革命"}',
 '{"ko":"체제 전환과 대규모 정치 사건","en":"Regime change and large-scale political events","ja":"体制転換と大規模政治事件"}',1,2),
('DISCOVERY','EVENT-006','{}',
 '{"ko":"탐험과 발견","en":"Exploration & Discovery","ja":"探検と発見"}',
 '{"ko":"미지 영역의 도달과 새로운 천체의 확인","en":"Reaching unknown regions and confirming new worlds","ja":"未知領域への到達と新天体の確認"}',1,3),
('ACCIDENT','EVENT-006','{}',
 '{"ko":"사고 기록","en":"Accidents","ja":"事故記録"}',
 '{"ko":"기술적 실패로 인한 대형 사고","en":"Major accidents caused by technical failure","ja":"技術的失敗による大事故"}',2,4),
-- ART-007
('MUSIC','ART-007','{}',
 '{"ko":"음악","en":"Music","ja":"音楽"}',
 '{"ko":"작곡, 초연, 음악 형식의 변화","en":"Composition, premieres and changes in musical form","ja":"作曲・初演・音楽形式の変化"}',1,1),
('VISUAL','ART-007','{}',
 '{"ko":"미술","en":"Visual Art","ja":"美術"}',
 '{"ko":"회화, 조각, 시각 표현의 전개","en":"Painting, sculpture and visual expression","ja":"絵画・彫刻・視覚表現の展開"}',1,2),
('LITERATURE','ART-007','{}',
 '{"ko":"문학","en":"Literature","ja":"文学"}',
 '{"ko":"서사, 시, 출판과 독서 문화","en":"Narrative, poetry, publishing and reading culture","ja":"物語・詩・出版と読書文化"}',1,3),
('ARCH','ART-007','{}',
 '{"ko":"건축과 조형","en":"Architecture & Form","ja":"建築と造形"}',
 '{"ko":"양식과 구조로 남은 조형 기록","en":"Records left as built form and structure","ja":"様式と構造として残る造形記録"}',1,4),
-- LANG-008
('WRITING','LANG-008','{}',
 '{"ko":"문자 체계","en":"Writing Systems","ja":"文字体系"}',
 '{"ko":"문자의 창제와 표기 규범","en":"Creation of scripts and orthographic norms","ja":"文字の創製と表記規範"}',1,1),
('TRANSLATION','LANG-008','{}',
 '{"ko":"번역과 해독","en":"Translation & Decipherment","ja":"翻訳と解読"}',
 '{"ko":"고대 문자의 해독과 언어 간 번역","en":"Decipherment of ancient scripts and translation","ja":"古代文字の解読と言語間翻訳"}',1,2),
('MEDIA','LANG-008','{}',
 '{"ko":"매체와 방송","en":"Media & Broadcast","ja":"媒体と放送"}',
 '{"ko":"신문, 라디오, 방송망의 형성","en":"Newspapers, radio and broadcast networks","ja":"新聞・ラジオ・放送網の形成"}',1,3),
('SIGNAL','LANG-008','{}',
 '{"ko":"신호와 부호","en":"Signals & Codes","ja":"信号と符号"}',
 '{"ko":"전신 부호, 암호, 기계 간 통신 규약","en":"Telegraph codes, ciphers and machine protocols","ja":"電信符号・暗号・機械間通信規約"}',1,4),
-- PERSON-009
('DIARY','PERSON-009','{}',
 '{"ko":"일기와 수기","en":"Diaries","ja":"日記と手記"}',
 '{"ko":"개인이 당대에 직접 남긴 기록","en":"Contemporaneous records written by individuals","ja":"個人が当時に直接残した記録"}',1,1),
('LETTER','PERSON-009','{}',
 '{"ko":"서신","en":"Letters","ja":"書簡"}',
 '{"ko":"주고받은 편지와 통신 기록","en":"Correspondence and exchanged letters","ja":"やり取りされた手紙と通信記録"}',1,2),
('TESTIMONY','PERSON-009','{}',
 '{"ko":"증언","en":"Testimony","ja":"証言"}',
 '{"ko":"목격자와 당사자의 진술 기록","en":"Statements by witnesses and participants","ja":"目撃者・当事者の供述記録"}',1,3),
('BIOGRAPHY','PERSON-009','{}',
 '{"ko":"생애 기록","en":"Biography","ja":"生涯記録"}',
 '{"ko":"한 인물의 생애를 정리한 기록","en":"Records summarising an individual life","ja":"一人の人物の生涯をまとめた記録"}',1,4)
on conflict (id) do update
  set category_id = excluded.category_id, planet_ids = excluded.planet_ids,
      name = excluded.name, description = excluded.description,
      level = excluded.level, sort_order = excluded.sort_order;

-- ------------------------------------------------------------
-- 4. 시드 기록 (5.5 배분표)
--    지구 22 / 화성 4 / 타이탄 2 / 케플러-442b 1 / 프록시마 b 1 = 30건
--    지구 시대 구성: 고대 3 / 중세 3 / 근대 6 / 현대 10
--    ※ 모든 기록에 source 를 채웠습니다. 근거 없는 서술은 넣지 않았습니다. (5.3)
-- ------------------------------------------------------------

-- [지구 / 고대 3, 중세 3, 근대 4] --------------------------------
insert into public.records
  (planet_id, category_id, subcategory_id, title, summary, content,
   event_date, tags, source, level, is_seed, author_id)
select d.planet_id, d.category_id, d.subcategory_id, d.title, d.summary, d.content,
       d.event_date, d.tags, d.source, d.level, true,
       (select id from public.profiles where keeper_code = 'KEEPER-000')
from (values

-- 1. 함무라비 법전 (고대)
('TERRA-001','CIV-002','ANCIENT',
 '{"ko":"함무라비 법전의 편찬","en":"The Code of Hammurabi","ja":"ハンムラビ法典の編纂"}'::jsonb,
 '{"ko":"바빌론 제1왕조의 왕 함무라비가 제정한 법 모음이다. 높이 2미터가 넘는 섬록암 비석에 쐐기문자로 새겨졌으며, 1901년부터 1902년 사이 이란 수사에서 발굴되어 현재 루브르 박물관이 소장하고 있다.","en":"A collection of laws issued under Hammurabi of the First Dynasty of Babylon. It was carved in cuneiform on a diorite stele over two metres tall, excavated at Susa in Iran in 1901-1902, and is now held by the Louvre Museum.","ja":"バビロン第1王朝の王ハンムラビが定めた法の集成。高さ2メートルを超える閃緑岩の石碑に楔形文字で刻まれ、1901年から1902年にかけてイランのスーサで発掘され、現在はルーヴル美術館が所蔵している。"}'::jsonb,
 '{"ko": "함무라비는 바빌론 제1왕조의 여섯 번째 왕으로, 메소포타미아 남부의 여러 도시국가를 하나의 지배 아래 통합했다. 통일된 영역을 다스리기 위해서는 도시마다 달랐던 관습을 하나의 기준으로 묶을 필요가 있었고, 법전은 그 필요에서 나온 문서로 이해된다.\n\n비석의 윗부분에는 함무라비가 태양신 샤마시 앞에 서 있는 부조가 새겨져 있고, 그 아래로 서문과 법조문, 맺음말이 이어진다. 법조문은 손상된 부분을 제외하고 약 280여 개 항목으로 정리되며, 재산, 상거래, 임대차, 혼인과 상속, 상해와 배상, 노동의 대가 등을 다룬다.\n\n조문은 대체로 조건과 결과를 짝지어 서술하는 형식을 취한다. 신분에 따라 같은 행위에 다른 처벌이 적용되는 항목이 여럿 있어, 당시 사회가 자유인과 예속민을 구분하고 있었다는 사실이 문서 자체에서 드러난다.\n\n비석은 후대에 엘람으로 옮겨진 것으로 보이며, 20세기 초 프랑스 조사단이 수사에서 발견했다. 이 법전은 메소포타미아에서 유일한 법 모음은 아니지만, 거의 온전한 형태로 전해지는 대규모 법 문서라는 점에서 고대 법 제도를 연구하는 기준 자료로 쓰인다.", "en": "Hammurabi was the sixth king of the First Dynasty of Babylon and brought a number of southern Mesopotamian city-states under a single authority. Governing that territory required a common standard in place of customs that differed from city to city, and the law collection is understood as a product of that need.\n\nThe upper part of the stele carries a relief showing Hammurabi before the sun god Shamash. Below it run a prologue, the legal provisions, and an epilogue. Setting aside damaged passages, the provisions are usually counted at around 280 items covering property, commerce, tenancy, marriage and inheritance, injury and compensation, and payment for labour.\n\nThe provisions are generally phrased as a condition followed by a consequence. Several items assign different penalties for the same act depending on the status of the parties, so the document itself records that the society distinguished free persons from dependants.\n\nThe stele appears to have been carried to Elam at a later date, and a French expedition found it at Susa in the early twentieth century. It is not the only law collection from Mesopotamia, but as a large legal text surviving in nearly complete form it serves as a reference source for the study of ancient legal institutions.", "ja": "ハンムラビはバビロン第1王朝の6代目の王であり、メソポタミア南部の複数の都市国家を一つの支配下に統合した。統一された領域を治めるには、都市ごとに異なっていた慣習を一つの基準にまとめる必要があり、法典はその必要から生まれた文書と理解されている。\n\n石碑の上部にはハンムラビが太陽神シャマシュの前に立つ浮彫が刻まれ、その下に序文、法条文、結びの文が続く。法条文は損傷部分を除いておよそ280項目に整理され、財産、商取引、賃貸借、婚姻と相続、傷害と賠償、労働の対価などを扱う。\n\n条文は概ね条件と結果を対にして述べる形式をとる。身分によって同じ行為に異なる刑罰が科される項目が複数あり、当時の社会が自由人と隷属民を区別していた事実が文書自体から読み取れる。\n\n石碑は後代にエラムへ運ばれたとみられ、20世紀初頭にフランス調査団がスーサで発見した。この法典はメソポタミア唯一の法集成ではないが、ほぼ完全な形で伝わる大規模な法文書として、古代の法制度を研究する基準資料となっている。"}'::jsonb,
 date '1754-01-01 BC',
 array['메소포타미아','바빌로니아','법','고대문명','쐐기문자']::text[],
 'Musée du Louvre, Sb 8 (Code of Hammurabi stele) / Martha T. Roth, Law Collections from Mesopotamia and Asia Minor, 2nd ed. (Scholars Press, 1997)',
 1),

-- 2. 진의 중국 통일 (고대)
('TERRA-001','CIV-002','ANCIENT',
 '{"ko":"진(秦)의 중국 통일과 시황제 칭호","en":"The Qin Unification of China","ja":"秦による中国統一と始皇帝の称号"}'::jsonb,
 '{"ko":"기원전 221년 진이 제(齊)를 마지막으로 병합하면서 전국시대가 끝났다. 진왕 정은 스스로 시황제라는 칭호를 정하고, 문자와 도량형, 화폐를 하나의 기준으로 통일하며 군현제를 시행했다.","en":"In 221 BCE the state of Qin absorbed Qi, the last of its rivals, ending the Warring States period. King Zheng of Qin adopted the title First Emperor and imposed single standards for script, weights and measures, and currency while installing a commandery-county administration.","ja":"紀元前221年、秦が最後に斉を併合し戦国時代が終わった。秦王政は自ら始皇帝の称号を定め、文字・度量衡・貨幣を単一の基準に統一し、郡県制を施行した。"}'::jsonb,
 '{"ko": "기원전 3세기 중반 중국 대륙은 여러 나라가 병립하며 오랜 기간 전쟁을 이어가고 있었다. 진은 서쪽 변방에서 출발했으나 법과 행정을 정비하고 군사력을 축적하면서 다른 나라들을 차례로 병합해 나갔다.\n\n기원전 221년 제를 병합해 통일이 완성되자, 진왕 정은 기존의 왕이라는 호칭이 자신의 위상에 맞지 않는다고 보고 삼황오제에서 글자를 따 황제라는 칭호를 새로 만들었다. 그리고 자신을 첫 번째 황제라는 뜻의 시황제로 칭했다.\n\n통일 이후의 정책은 서로 다른 지역을 하나의 행정 단위로 묶는 데 집중되었다. 봉건 제후를 두지 않고 전국을 군과 현으로 나누어 중앙에서 관리를 파견했으며, 나라마다 달랐던 문자를 소전으로 정비하고 도량형과 화폐, 수레바퀴의 폭을 하나로 맞추었다.\n\n통일 국가는 시황제 사후 오래 지속되지 못했으나, 이때 마련된 문자와 행정 구획의 기준은 이후 왕조들에 이어졌다. 이 시기의 사정은 전한 시대 사마천이 편찬한 사기의 진시황본기에 비교적 자세히 기록되어 있다.", "en": "In the mid third century BCE the Chinese mainland was divided among rival states locked in prolonged warfare. Qin began on the western frontier but reorganised its law and administration, built up military strength, and annexed its rivals one after another.\n\nWhen Qi was absorbed in 221 BCE and unification was complete, King Zheng judged that the existing title of king no longer matched his position. He formed a new title, huangdi, from characters associated with the legendary sovereigns, and styled himself First Emperor.\n\nPolicy after unification concentrated on binding distinct regions into a single administrative frame. Instead of enfeoffing lords, the realm was divided into commanderies and counties staffed by officials sent from the centre. Scripts that had varied by state were regularised, and weights, measures, coinage and axle widths were brought to common standards.\n\nThe unified state did not long survive the First Emperor, but the standards for writing and administrative division established in this period carried over into later dynasties. The events are recorded in relative detail in the Basic Annals of the First Emperor of Qin in the Shiji, compiled by Sima Qian in the Western Han.", "ja": "紀元前3世紀半ば、中国大陸は複数の国が並立し長期の戦争を続けていた。秦は西の辺境から出発したが、法と行政を整備し軍事力を蓄えながら他国を次々に併合していった。\n\n紀元前221年に斉を併合して統一が完成すると、秦王政は従来の王という称号が自らの地位に見合わないと考え、三皇五帝から字を取って皇帝という称号を新たに作った。そして自らを最初の皇帝を意味する始皇帝と称した。\n\n統一後の政策は異なる地域を一つの行政単位にまとめることに集中した。封建諸侯を置かず全土を郡と県に分けて中央から官吏を派遣し、国ごとに異なっていた文字を小篆に整え、度量衡・貨幣・車軸の幅を一つに揃えた。\n\n統一国家は始皇帝の死後長くは続かなかったが、この時期に定められた文字と行政区画の基準は後の王朝へ受け継がれた。当時の事情は前漢の司馬遷が編纂した『史記』秦始皇本紀に比較的詳しく記録されている。"}'::jsonb,
 date '0221-01-01 BC',
 array['진나라','시황제','전국시대','군현제','문자통일']::text[],
 '司馬遷, 『史記』 卷六 秦始皇本紀 / Michael Loewe and Edward L. Shaughnessy (eds.), The Cambridge History of Ancient China (Cambridge University Press, 1999)',
 1),

-- 3. 베수비오 분화 (고대)
('TERRA-001','NAT-001','VOLCANO',
 '{"ko":"베수비오 화산 분화와 폼페이 매몰","en":"The Eruption of Vesuvius and the Burial of Pompeii","ja":"ヴェスヴィオ火山の噴火とポンペイの埋没"}'::jsonb,
 '{"ko":"서기 79년 이탈리아 나폴리만의 베수비오 화산이 분화해 폼페이와 헤르쿨라네움을 비롯한 주변 도시를 매몰시켰다. 이 분화는 목격자인 소 플리니우스가 역사가 타키투스에게 보낸 두 통의 편지에 기록으로 남았다.","en":"In 79 CE Vesuvius, on the Bay of Naples, erupted and buried Pompeii, Herculaneum and other nearby towns. The event survives in written form through two letters that the eyewitness Pliny the Younger sent to the historian Tacitus.","ja":"西暦79年、イタリア・ナポリ湾のヴェスヴィオ火山が噴火し、ポンペイやヘルクラネウムなど周辺の都市を埋没させた。この噴火は目撃者である小プリニウスが歴史家タキトゥスに送った2通の書簡に記録として残った。"}'::jsonb,
 '{"ko": "베수비오는 나폴리만을 내려다보는 화산으로, 분화 이전 주변에는 폼페이와 헤르쿨라네움 등 여러 도시가 자리하고 있었다. 분화가 시작되기 전 이 지역에서는 지진이 관측되었다는 기록이 전한다.\n\n분화는 거대한 분연주가 솟아오르며 시작되었고, 폼페이 방향으로 부석과 화산재가 쏟아졌다. 이어 분연주가 무너지면서 발생한 화쇄류가 산비탈을 따라 빠르게 내려와 헤르쿨라네움과 폼페이를 차례로 덮쳤다. 도시는 두꺼운 화산 퇴적물 아래 묻혔다.\n\n당시 미세눔에 있던 소 플리니우스는 함대 사령관이자 자연사가였던 외삼촌 대 플리니우스가 구조와 관찰을 위해 배를 몰고 나갔다가 돌아오지 못한 경위를 편지에 적었다. 그는 분연주의 모양을 우산소나무에 빗대어 묘사했는데, 오늘날 이러한 형태의 분화를 플리니식 분화라고 부른다.\n\n분화 날짜는 오랫동안 8월 24일로 전해졌으나, 사본 계통에 따라 날짜 표기가 다르고 발굴 현장에서 가을에 대응하는 정황이 확인되면서 늦여름 이후로 보는 견해도 제시되어 있다. 매몰된 도시는 18세기 이후 본격적으로 발굴되었고, 화산재에 덮여 보존된 건물과 생활 흔적은 로마 시대 도시 생활을 확인할 수 있는 자료가 되었다.", "en": "Vesuvius overlooks the Bay of Naples, and before the eruption several towns including Pompeii and Herculaneum stood around it. Accounts report that earthquakes were felt in the district before the eruption began.\n\nThe eruption opened with a tall eruption column, and pumice and ash fell toward Pompeii. The column then collapsed, producing pyroclastic flows that swept down the slopes and struck Herculaneum and Pompeii in turn. The towns were buried under thick volcanic deposits.\n\nPliny the Younger, then at Misenum, wrote that his uncle Pliny the Elder, a fleet commander and natural historian, put out by ship to observe and to help, and did not return. He compared the shape of the column to an umbrella pine, and eruptions of this type are now called Plinian.\n\nThe date has long been given as 24 August, though manuscript traditions differ and excavation evidence consistent with autumn has led some researchers to place it later in the year. Systematic excavation began in the eighteenth century, and the buildings and traces of daily life preserved under ash have become primary material for the study of Roman urban life.", "ja": "ヴェスヴィオはナポリ湾を見下ろす火山で、噴火以前その周辺にはポンペイやヘルクラネウムなど複数の都市があった。噴火が始まる前、この地域では地震が観測されたという記録が伝わる。\n\n噴火は巨大な噴煙柱が立ち上がって始まり、ポンペイの方向へ軽石と火山灰が降り注いだ。続いて噴煙柱が崩壊して発生した火砕流が山腹を高速で下り、ヘルクラネウムとポンペイを順に襲った。都市は厚い火山堆積物の下に埋もれた。\n\n当時ミセヌムにいた小プリニウスは、艦隊司令官であり博物学者でもあった叔父の大プリニウスが救助と観察のため船を出して戻らなかった経緯を書簡に記した。彼は噴煙柱の形をカサマツにたとえて描写しており、今日この形の噴火をプリニー式噴火と呼ぶ。\n\n噴火の日付は長く8月24日と伝えられてきたが、写本系統によって日付表記が異なり、発掘現場で秋に対応する状況が確認されたことから、晩夏以降とみる見解も提示されている。埋没した都市は18世紀以降に本格的に発掘され、火山灰に覆われて保存された建物や生活の痕跡はローマ時代の都市生活を確認できる資料となった。"}'::jsonb,
 date '0079-08-24',
 array['베수비오','폼페이','화쇄류','로마','플리니우스']::text[],
 'Pliny the Younger, Epistulae 6.16 and 6.20 / Parco Archeologico di Pompei, official excavation documentation',
 1),

-- 4. 흑사병 (중세)
('TERRA-001','EVENT-006','DISASTER',
 '{"ko":"흑사병의 유럽 확산","en":"The Spread of the Black Death in Europe","ja":"黒死病のヨーロッパ拡散"}'::jsonb,
 '{"ko":"1347년 가을 시칠리아 메시나에 도착한 선박을 통해 유럽 본토로 들어온 역병이 1351년까지 대륙 전역으로 퍼졌다. 병원체는 20세기에 페스트균으로 확인되었고, 이후 중세 유해의 고대 DNA 분석으로도 검출되었다.","en":"A plague that entered mainland Europe through ships reaching Messina in Sicily in the autumn of 1347 spread across the continent by 1351. The pathogen was identified as Yersinia pestis in the twentieth century and has since been recovered from ancient DNA in medieval remains.","ja":"1347年秋にシチリア島メッシーナへ到着した船を通じてヨーロッパ本土に入った疫病は、1351年までに大陸全域へ広がった。病原体は20世紀にペスト菌と同定され、その後中世の遺骸の古代DNA解析でも検出された。"}'::jsonb,
 '{"ko": "14세기 중반 흑해 연안의 교역 거점에서 시작된 역병은 지중해 상선 항로를 따라 서쪽으로 이동했다. 1347년 10월 시칠리아 메시나에 들어온 선박이 유럽 본토 확산의 출발점으로 기록되어 있다.\n\n이후 몇 해 사이 역병은 이탈리아 반도와 이베리아 반도, 프랑스, 잉글랜드, 신성로마제국 지역, 스칸디나비아로 차례로 번졌다. 도시와 촌락에서 사망자가 급증했고, 상거래와 농업 노동이 동시에 중단되는 지역이 나타났다.\n\n사망 규모에 대한 추정은 연구자마다 차이가 크다. 유럽 인구의 상당 부분이 사라졌다는 데에는 대체로 견해가 모이지만, 구체적인 비율은 지역별 기록의 성격과 표본에 따라 다르게 산출된다. 이 문서에서는 특정 수치를 확정하지 않는다.\n\n인구 감소는 노동력의 상대적 희소성을 낳아 임금과 토지 보유 관계에 영향을 주었고, 여러 지역에서 기존의 예속 관계가 흔들리는 계기가 되었다. 병원체의 정체는 19세기 말 세균학 연구로 규명되었으며, 2011년에는 런던 이스트 스미스필드 집단 매장지의 유해에서 당시 균주의 유전체 초안이 복원되었다.", "en": "The epidemic that began at trading posts on the Black Sea in the mid fourteenth century moved west along Mediterranean shipping routes. Ships arriving at Messina in Sicily in October 1347 are recorded as the starting point of its spread into mainland Europe.\n\nOver the following years it moved through the Italian and Iberian peninsulas, France, England, the lands of the Holy Roman Empire, and Scandinavia. Deaths rose sharply in towns and villages, and in some districts commerce and agricultural labour halted at the same time.\n\nEstimates of mortality differ widely between researchers. There is broad agreement that a substantial share of the European population died, but specific proportions vary with the character of local records and the samples used. This document does not fix a single figure.\n\nThe fall in population made labour relatively scarce, which affected wages and landholding relations and unsettled existing bonds of dependence in several regions. The identity of the pathogen was established by bacteriological work at the end of the nineteenth century, and in 2011 a draft genome of the medieval strain was recovered from remains in the East Smithfield burial ground in London.", "ja": "14世紀半ば、黒海沿岸の交易拠点で始まった疫病は地中海の商船航路に沿って西へ移動した。1347年10月にシチリア島メッシーナへ入った船が、ヨーロッパ本土への拡散の出発点として記録されている。\n\nその後の数年で疫病はイタリア半島、イベリア半島、フランス、イングランド、神聖ローマ帝国域、スカンディナヴィアへと順に広がった。都市と村落で死者が急増し、商取引と農業労働が同時に停止する地域が現れた。\n\n死亡規模の推定は研究者によって大きく異なる。ヨーロッパ人口の相当部分が失われたという点ではおおむね見解が一致するが、具体的な割合は地域ごとの記録の性格と標本によって異なって算出される。本文書では特定の数値を確定しない。\n\n人口減少は労働力の相対的な希少化を生み、賃金と土地保有関係に影響を与え、複数の地域で従来の隷属関係が揺らぐ契機となった。病原体の正体は19世紀末の細菌学研究で解明され、2011年にはロンドンのイースト・スミスフィールド集団埋葬地の遺骸から当時の菌株のゲノム草案が復元された。"}'::jsonb,
 date '1347-10-01',
 array['흑사병','페스트','중세유럽','전염병','인구']::text[],
 'Ole J. Benedictow, The Black Death 1346-1353: The Complete History (Boydell Press, 2004) / Bos et al., "A draft genome of Yersinia pestis from victims of the Black Death", Nature 478, 506-510 (2011)',
 2),

-- 5. 훈민정음 (중세)
('TERRA-001','LANG-008','WRITING',
 '{"ko":"훈민정음의 창제와 반포","en":"The Creation and Promulgation of Hunminjeongeum","ja":"訓民正音の創製と頒布"}'::jsonb,
 '{"ko":"조선의 세종이 1443년 새 문자를 만들고 1446년 해설서인 훈민정음 해례본을 통해 반포했다. 초성 17자와 중성 11자로 이루어진 28자 체계이며, 해례본에는 글자를 만든 원리가 직접 설명되어 있다.","en":"King Sejong of Joseon created a new script in 1443 and promulgated it in 1446 through Hunminjeongeum Haerye, an explanatory volume. The system comprised 28 letters, 17 initial consonants and 11 medial vowels, and the Haerye states the principles by which the letters were formed.","ja":"朝鮮の世宗が1443年に新しい文字を作り、1446年に解説書である訓民正音解例本を通じて頒布した。初声17字と中声11字からなる28字の体系で、解例本には字を作った原理が直接説明されている。"}'::jsonb,
 '{"ko": "조선에서는 한문이 공식 문자로 쓰였고, 우리말을 적기 위해 한자의 음과 뜻을 빌리는 차자 표기가 사용되었다. 그러나 이러한 방식은 배우기 어렵고 말과 글이 어긋나는 문제가 있었다.\n\n세종은 1443년 새로운 문자를 완성했고, 1446년 집현전 학자들이 참여한 해설서 훈민정음을 간행했다. 이 책의 서문에는 나라의 말이 중국과 달라 문자로 서로 통하지 않으므로 백성이 뜻을 펴지 못한다는 문제의식이 명시되어 있다.\n\n해례본은 자음 글자가 발음 기관의 모양을 본떠 만들어졌고, 모음 글자가 하늘과 땅과 사람을 뜻하는 세 요소의 결합으로 구성된다는 제자 원리를 설명한다. 문자의 창제 원리가 문헌으로 남아 있는 사례는 드물어, 이 점이 자료로서의 가치를 높인다.\n\n반포 시점은 문헌에 음력 9월로 기록되어 있으며, 오늘날 한국에서는 이를 양력으로 환산한 10월 9일을 한글날로 기념한다. 해례본은 20세기에 발견되어 현재 간송미술문화재단이 소장하고 있고, 1997년 유네스코 세계기록유산으로 등재되었다.", "en": "Joseon used literary Chinese as its official written language, and Korean was recorded through borrowed readings of Chinese characters. That method was difficult to learn and left a gap between speech and writing.\n\nSejong completed the new script in 1443, and in 1446 an explanatory volume, Hunminjeongeum, was issued with the participation of scholars of the Hall of Worthies. Its preface states the problem directly: the language of the country differs from that of China and does not correspond to those characters, so ordinary people cannot express what they mean.\n\nThe Haerye explains that consonant letters were shaped after the articulatory organs and that vowel letters combine three elements standing for heaven, earth and the human being. Documented accounts of the design principles of a writing system are rare, which adds to the value of the text as a source.\n\nThe promulgation is recorded in the ninth lunar month, and Korea today marks the converted solar date of 9 October as Hangul Day. The Haerye copy was found in the twentieth century, is held by the Kansong Art and Culture Foundation, and was inscribed on the UNESCO Memory of the World Register in 1997.", "ja": "朝鮮では漢文が公式の文字として用いられ、自国語を書き表すために漢字の音と意味を借りる借字表記が使われていた。しかしこの方式は習得が難しく、話し言葉と書き言葉が食い違う問題があった。\n\n世宗は1443年に新しい文字を完成させ、1446年に集賢殿の学者が参加した解説書『訓民正音』を刊行した。この書の序文には、国の言葉が中国と異なり文字で互いに通じないため民が意を述べられない、という問題意識が明示されている。\n\n解例本は、子音字が発音器官の形をかたどって作られ、母音字が天・地・人を意味する三要素の組み合わせで構成されるという制字原理を説明する。文字の創製原理が文献として残る例は稀であり、この点が資料としての価値を高めている。\n\n頒布の時期は文献に陰暦9月と記録され、今日の韓国ではこれを陽暦に換算した10月9日をハングルの日として記念している。解例本は20世紀に発見され、現在は澗松美術文化財団が所蔵し、1997年にユネスコ世界の記憶に登録された。"}'::jsonb,
 date '1446-10-09',
 array['훈민정음','한글','세종','문자','조선']::text[],
 '『訓民正音』 解例本 (간송미술문화재단 소장, 국보 제70호) / 『世宗實錄』 卷113, 세종 28년 9월조 / UNESCO Memory of the World Register, Hunminjeongeum Manuscript (1997)',
 1),

-- 6. 구텐베르크 42행 성서 (중세)
('TERRA-001','TECH-004','INFO',
 '{"ko":"구텐베르크의 금속활자 인쇄와 42행 성서","en":"Gutenberg, Movable Metal Type and the 42-Line Bible","ja":"グーテンベルクの金属活字印刷と42行聖書"}'::jsonb,
 '{"ko":"요하네스 구텐베르크가 마인츠에서 금속활자 조판과 압축식 인쇄기를 결합한 인쇄 방식을 실용화했다. 그 결과물인 42행 성서는 1450년대 중반에 인쇄되었으며, 유럽에서 서적의 생산 방식을 바꾸어 놓았다.","en":"Johannes Gutenberg brought together movable metal type and a screw press at Mainz to make printing practicable. The resulting 42-line Bible was printed in the mid 1450s and changed how books were produced in Europe.","ja":"ヨハネス・グーテンベルクがマインツで金属活字の組版と圧搾式印刷機を結び付けた印刷方式を実用化した。その成果である42行聖書は1450年代半ばに印刷され、ヨーロッパにおける書物の生産方式を変えた。"}'::jsonb,
 '{"ko": "인쇄 이전 유럽의 책은 필사로 만들어졌고, 한 권을 만드는 데 오랜 시간과 큰 비용이 들었다. 목판 인쇄가 있었으나 판 하나를 한 면에만 쓸 수 있어 대량 생산에는 한계가 있었다.\n\n구텐베르크는 낱글자를 금속으로 주조해 반복 사용하는 활자, 활자를 고정하는 조판 방식, 유성 잉크, 압축식 인쇄기를 하나의 공정으로 결합했다. 이 조합은 같은 판을 여러 장 찍고 판을 해체해 다시 짜는 일을 가능하게 했다.\n\n42행 성서는 각 단이 대체로 42행으로 짜여 붙은 이름으로, 라틴어 불가타 성서를 두 권으로 나누어 인쇄했다. 인쇄 부수는 정확히 알려져 있지 않으나 종이본과 양피지본이 함께 제작되었고, 완본과 낙질을 합쳐 오늘날 수십 부가 여러 기관에 전한다.\n\n인쇄술은 마인츠에서 유럽 각지로 빠르게 퍼졌고, 15세기 후반에 인쇄된 초기 간행물은 인큐내뷸러라는 이름으로 따로 분류된다. 서적의 복제 비용이 낮아지면서 문헌의 유통 범위와 속도가 이전과 달라졌다.", "en": "Before printing, books in Europe were copied by hand, which made each volume slow and expensive to produce. Woodblock printing existed, but a block served only one page, which limited output.\n\nGutenberg combined cast metal type that could be reused, a method of setting and locking that type, oil-based ink, and a screw press into a single process. The combination allowed many impressions from one forme and the breaking up and resetting of type afterwards.\n\nThe 42-line Bible takes its name from the columns of roughly 42 lines and presents the Latin Vulgate in two volumes. The size of the print run is not known with certainty, but copies were produced on both paper and vellum, and several dozen complete copies and fragments survive in institutions today.\n\nPrinting spread quickly from Mainz across Europe, and works printed before 1501 are classified separately as incunabula. As the cost of reproducing a book fell, the range and speed at which texts circulated changed.", "ja": "印刷以前のヨーロッパの書物は写本で作られ、一冊を作るのに長い時間と大きな費用がかかった。木版印刷はあったが、一枚の版を一面にしか使えず大量生産には限界があった。\n\nグーテンベルクは、一字ずつ金属で鋳造して繰り返し使う活字、活字を固定する組版方式、油性インク、圧搾式印刷機を一つの工程に結合した。この組み合わせにより、同じ版から多数の刷りを取り、版を解いて組み直すことが可能になった。\n\n42行聖書は各段がおおむね42行で組まれていることから付いた名で、ラテン語ウルガタ聖書を2巻に分けて印刷したものである。印刷部数は正確には知られていないが、紙本と羊皮紙本が併せて制作され、完本と零本を合わせて今日数十部が各機関に伝わる。\n\n印刷術はマインツからヨーロッパ各地へ急速に広まり、15世紀中に印刷された初期刊行物はインキュナブラという名で別に分類される。書物の複製費用が下がったことで、文献が流通する範囲と速度は以前と異なるものになった。"}'::jsonb,
 date '1455-01-01',
 array['구텐베르크','인쇄술','활자','성서','마인츠']::text[],
 'British Library, Gutenberg Bible digitisation project / Gutenberg-Museum Mainz, collection documentation',
 1),

-- 7. 코페르니쿠스 (근대)
('TERRA-001','TECH-004','SCIENCE',
 '{"ko":"코페르니쿠스 『천구의 회전에 관하여』 출간","en":"Publication of De revolutionibus orbium coelestium","ja":"コペルニクス『天球の回転について』の刊行"}'::jsonb,
 '{"ko":"1543년 뉘른베르크에서 니콜라우스 코페르니쿠스의 천문학 저작이 출간되었다. 이 책은 지구가 태양 둘레를 도는 행성 가운데 하나라는 체계를 수학적으로 제시했으며, 저자는 출간과 같은 해에 사망했다.","en":"The astronomical work of Nicolaus Copernicus was published at Nuremberg in 1543. It set out, in mathematical form, a system in which the Earth is one of the planets moving around the Sun, and its author died in the same year.","ja":"1543年、ニュルンベルクでニコラウス・コペルニクスの天文学書が刊行された。この書は地球が太陽の周りを回る惑星の一つであるという体系を数学的に示し、著者は刊行と同じ年に没した。"}'::jsonb,
 '{"ko": "16세기 초 유럽 천문학은 지구를 중심에 두고 천체의 운동을 원과 주전원의 조합으로 설명하는 프톨레마이오스 체계를 기준으로 삼고 있었다. 이 체계는 관측을 상당히 잘 재현했으나 계산 구조가 복잡했다.\n\n폴란드 바르미아의 성직자이자 천문학자였던 코페르니쿠스는 태양을 중심에 두는 배치가 행성 운동을 더 간결하게 설명한다고 보았다. 그는 이 착상을 오랫동안 다듬어 여섯 권으로 이루어진 저작으로 정리했다.\n\n책은 1543년 뉘른베르크에서 인쇄되었다. 인쇄 과정을 관리한 신학자 안드레아스 오시안더는 저자의 동의 없이 익명의 서문을 덧붙여 이 체계가 계산을 위한 가설일 뿐이라고 적었는데, 이 서문의 존재는 이후 책의 수용 과정에 영향을 주었다.\n\n체계 자체는 여전히 원운동을 전제하고 있었기 때문에 관측과의 오차가 완전히 해소되지는 않았다. 이후 케플러의 타원 궤도와 갈릴레이의 망원경 관측이 더해지면서 태양 중심 배치가 자리를 잡았다. 로마 교회는 1616년 이 책을 수정 조건부로 금서 목록에 올렸다.", "en": "European astronomy in the early sixteenth century worked from the Ptolemaic system, which placed the Earth at the centre and described celestial motion through combinations of circles and epicycles. The system reproduced observations reasonably well but was computationally intricate.\n\nCopernicus, a cleric and astronomer in Warmia in Poland, held that placing the Sun at the centre described planetary motion more economically. He developed the idea over many years into a work in six books.\n\nThe book was printed at Nuremberg in 1543. Andreas Osiander, the theologian who oversaw the printing, added an unsigned preface without the consent of the author stating that the system was only a hypothesis for calculation, and the presence of that preface affected how the book was received.\n\nBecause the system still assumed circular motion, discrepancies with observation were not fully removed. The heliocentric arrangement became established only after the elliptical orbits of Kepler and the telescopic observations of Galileo. The Roman Church placed the book on the index of prohibited books in 1616, pending correction.", "ja": "16世紀初頭のヨーロッパ天文学は、地球を中心に置き天体の運動を円と周転円の組み合わせで説明するプトレマイオス体系を基準としていた。この体系は観測をかなりよく再現したが、計算の構造が複雑だった。\n\nポーランド・ヴァルミアの聖職者であり天文学者でもあったコペルニクスは、太陽を中心に置く配置のほうが惑星の運動をより簡潔に説明すると考えた。彼はこの着想を長年かけて練り上げ、六巻からなる著作にまとめた。\n\n書物は1543年にニュルンベルクで印刷された。印刷を監督した神学者アンドレアス・オジアンダーは著者の同意なく匿名の序文を付し、この体系は計算のための仮説にすぎないと記した。この序文の存在は、その後の書物の受容に影響を与えた。\n\n体系自体は依然として円運動を前提としていたため、観測との誤差が完全に解消されたわけではない。のちにケプラーの楕円軌道とガリレイの望遠鏡観測が加わって太陽中心の配置が定着した。ローマ教会は1616年、この書を修正を条件として禁書目録に載せた。"}'::jsonb,
 date '1543-01-01',
 array['코페르니쿠스','천문학','지동설','과학혁명','뉘른베르크']::text[],
 'Nicolaus Copernicus, De revolutionibus orbium coelestium (Nuremberg, 1543) / Owen Gingerich, An Annotated Census of Copernicus'' De Revolutionibus (Brill, 2002)',
 2),

-- 8. 와트 분리 응축기 (근대)
('TERRA-001','TECH-004','ENERGY',
 '{"ko":"제임스 와트의 분리 응축기 특허","en":"James Watt and the Separate Condenser Patent","ja":"ジェームズ・ワットの分離凝縮器特許"}'::jsonb,
 '{"ko":"1769년 1월 5일 제임스 와트가 증기기관의 연료 소비를 줄이는 방법으로 영국 특허 제913호를 받았다. 실린더와 분리된 응축기를 두어 실린더를 뜨겁게 유지하는 방식으로, 기존 기관의 열 손실을 크게 줄였다.","en":"On 5 January 1769 James Watt was granted British patent No. 913 for a method of reducing the consumption of steam and fuel in fire engines. By condensing steam in a vessel separate from the cylinder, the cylinder could be kept hot and heat losses were greatly reduced.","ja":"1769年1月5日、ジェームズ・ワットは蒸気機関の燃料消費を減らす方法として英国特許第913号を取得した。シリンダーと分離した凝縮器を設けてシリンダーを高温に保つ方式で、従来機関の熱損失を大きく減らした。"}'::jsonb,
 '{"ko": "18세기 초부터 광산의 배수에 뉴커먼식 대기압 기관이 쓰이고 있었다. 이 기관은 실린더 안에 물을 뿌려 증기를 응축시켰기 때문에, 행정마다 실린더가 식었다가 다시 데워지는 과정에서 많은 연료가 소모되었다.\n\n글래스고 대학에서 기기 제작을 맡고 있던 와트는 뉴커먼 기관 모형을 수리하다가 이 손실의 구조를 파악했다. 그는 증기를 실린더 밖의 별도 용기에서 응축시키면 실린더를 계속 뜨거운 상태로 둘 수 있다는 해법에 이르렀다.\n\n1769년 특허는 이 분리 응축기를 핵심으로 하며, 실린더를 증기 재킷으로 감싸는 방법 등도 포함했다. 자금과 제작 역량의 문제로 상업적 보급은 곧바로 이루어지지 않았고, 1775년 매슈 볼턴과 동업 관계를 맺은 뒤에야 본격적인 제작과 판매가 진행되었다.\n\n이후 와트는 회전 운동을 얻는 기구와 원심 조속기, 복동식 구조 등을 추가해 기관을 공장 동력으로 확장했다. 분리 응축기 특허는 의회 결의를 통해 1800년까지 존속했다.", "en": "From the early eighteenth century Newcomen atmospheric engines were used to drain mines. Because they condensed steam by injecting water into the cylinder, the cylinder cooled and had to be reheated on every stroke, which consumed a great deal of fuel.\n\nWatt, who made instruments for the University of Glasgow, identified the structure of this loss while repairing a model Newcomen engine. He arrived at the solution of condensing the steam in a separate vessel outside the cylinder so that the cylinder could be kept hot.\n\nThe 1769 patent centred on this separate condenser and also covered such measures as surrounding the cylinder with a steam jacket. Limits of capital and manufacturing capacity delayed commercial use, and production and sales advanced only after Watt entered partnership with Matthew Boulton in 1775.\n\nWatt later added mechanisms for rotative motion, the centrifugal governor and double acting arrangements, extending the engine to factory power. The separate condenser patent was continued by an act of Parliament until 1800.", "ja": "18世紀初頭から鉱山の排水にニューコメン式大気圧機関が用いられていた。この機関はシリンダー内に水を噴射して蒸気を凝縮させたため、行程ごとにシリンダーが冷えて再び温められる過程で多くの燃料を消費した。\n\nグラスゴー大学で器具製作を担当していたワットは、ニューコメン機関の模型を修理する中でこの損失の構造を把握した。彼は、蒸気をシリンダーの外の別容器で凝縮させればシリンダーを高温のまま保てるという解法に至った。\n\n1769年の特許はこの分離凝縮器を中核とし、シリンダーを蒸気ジャケットで包む方法なども含んでいた。資金と製作能力の問題から商業的普及はすぐには進まず、1775年にマシュー・ボールトンと共同事業の関係を結んだのちに本格的な製作と販売が進んだ。\n\nその後ワットは回転運動を得る機構、遠心調速機、複動式構造などを加え、機関を工場動力へ拡張した。分離凝縮器の特許は議会の決議によって1800年まで存続した。"}'::jsonb,
 date '1769-01-05',
 array['증기기관','와트','산업혁명','특허','에너지']::text[],
 'British Patent No. 913 (5 January 1769), James Watt / Science Museum Group Collection, Watt separate condenser and Boulton & Watt archive',
 1),

-- 9. 바스티유 습격 (근대)
('TERRA-001','EVENT-006','POLITICS',
 '{"ko":"바스티유 습격","en":"The Storming of the Bastille","ja":"バスティーユ襲撃"}'::jsonb,
 '{"ko":"1789년 7월 14일 파리 시민과 이탈한 병사들이 왕립 요새이자 감옥이던 바스티유를 공격해 점령했다. 당시 수감자는 일곱 명뿐이었으나, 이 사건은 프랑스 혁명의 전개를 상징하는 장면으로 남았다.","en":"On 14 July 1789 Parisians and defecting soldiers attacked and took the Bastille, a royal fortress and prison. Only seven prisoners were held there at the time, yet the event became the emblematic scene of the French Revolution.","ja":"1789年7月14日、パリ市民と離反した兵士が王立要塞であり監獄でもあったバスティーユを攻撃し占領した。当時の収監者は7人に過ぎなかったが、この事件はフランス革命を象徴する場面として残った。"}'::jsonb,
 '{"ko": "1789년 프랑스는 재정 위기와 곡물 가격 상승 속에서 삼부회를 소집했고, 제3신분 대표들이 국민의회를 선언하면서 정치적 긴장이 높아졌다. 7월 초 국왕이 파리 주변에 군대를 집결시키고 재무총감 네케르를 해임하자 시내의 불안이 커졌다.\n\n7월 14일 아침 군중은 앵발리드에서 소총을 확보한 뒤 화약을 구하기 위해 바스티유로 향했다. 요새 사령관 베르나르 르네 드 로네와의 협상이 결렬되고 총격이 시작되면서 전투가 벌어졌고, 이탈한 프랑스 근위대와 대포가 가담하면서 요새는 오후에 함락되었다.\n\n점령 과정에서 사상자가 발생했고 드 로네는 시청으로 끌려가던 중 살해되었다. 바스티유는 절대왕정의 자의적 구금을 상징하는 건물로 인식되고 있었기 때문에, 요새의 함락은 실제 수감 인원과 무관하게 큰 정치적 반향을 낳았다.\n\n요새는 곧 해체되었고, 이 사건 이후 국민의회는 봉건적 특권 폐지와 인간과 시민의 권리 선언으로 나아갔다. 7월 14일은 이후 프랑스의 국경일로 지정되었다.", "en": "In 1789 France convoked the Estates General amid a fiscal crisis and rising grain prices, and tension grew when representatives of the Third Estate declared a National Assembly. Unrest in the city increased in early July when the king concentrated troops around Paris and dismissed the finance minister Necker.\n\nOn the morning of 14 July a crowd seized muskets at the Invalides and moved to the Bastille in search of powder. Negotiations with the governor, Bernard-René de Launay, broke down, firing began, and the fortress fell in the afternoon after defecting French Guards and cannon joined the attack.\n\nThere were casualties during the assault, and de Launay was killed while being taken to the city hall. The Bastille was widely regarded as a symbol of arbitrary imprisonment under absolute monarchy, so its fall carried political weight regardless of how few prisoners it held.\n\nThe fortress was demolished soon afterwards, and the Assembly moved on to abolish feudal privileges and to adopt the Declaration of the Rights of Man and of the Citizen. 14 July was later established as the national day of France.", "ja": "1789年のフランスは財政危機と穀物価格の上昇のなかで三部会を招集し、第三身分の代表が国民議会を宣言したことで政治的緊張が高まった。7月初め、国王がパリ周辺に軍を集結させ財務総監ネッケルを罷免すると、市内の不安は増大した。\n\n7月14日の朝、群衆はアンヴァリッドで小銃を確保したのち、火薬を求めてバスティーユへ向かった。要塞司令官ベルナール・ルネ・ド・ローネーとの交渉が決裂して銃撃が始まり戦闘となり、離反したフランス衛兵と大砲が加わって要塞は午後に陥落した。\n\n占拠の過程で死傷者が出て、ド・ローネーは市庁舎へ連行される途中で殺害された。バスティーユは絶対王政の恣意的な拘禁を象徴する建物と受け止められていたため、要塞の陥落は実際の収監人数と関わりなく大きな政治的反響を生んだ。\n\n要塞はまもなく解体され、この事件ののち国民議会は封建的特権の廃止と人間および市民の権利の宣言へ進んだ。7月14日はのちにフランスの国民の祝日と定められた。"}'::jsonb,
 date '1789-07-14',
 array['프랑스혁명','바스티유','파리','국민의회','1789']::text[],
 'Archives nationales de France, série T and série AE / Simon Schama, Citizens: A Chronicle of the French Revolution (Knopf, 1989)',
 2),

-- 10. 탐보라 분화 (근대)
('TERRA-001','NAT-001','VOLCANO',
 '{"ko":"탐보라 화산 분화와 여름 없는 해","en":"The Tambora Eruption and the Year Without a Summer","ja":"タンボラ火山の噴火と夏のない年"}'::jsonb,
 '{"ko":"1815년 4월 인도네시아 숨바와섬의 탐보라 화산이 분화했다. 성층권까지 올라간 화산 기체와 미세 입자가 지구 규모의 냉각을 일으켜, 이듬해인 1816년 북반구 여러 지역에서 여름 없는 해로 불리는 이상 저온과 흉작이 나타났다.","en":"Mount Tambora on Sumbawa in Indonesia erupted in April 1815. Volcanic gases and fine particles carried into the stratosphere cooled the planet, and in 1816 many regions of the northern hemisphere recorded the abnormal cold and crop failures known as the Year Without a Summer.","ja":"1815年4月、インドネシア・スンバワ島のタンボラ火山が噴火した。成層圏まで達した火山ガスと微粒子が地球規模の寒冷化を引き起こし、翌1816年には北半球の各地で夏のない年と呼ばれる異常低温と凶作が生じた。"}'::jsonb,
 '{"ko": "탐보라는 인도네시아 소순다 열도의 숨바와섬에 있는 성층화산이다. 1815년 4월 5일 분화가 시작되었고 4월 10일에 절정에 이르렀다. 이 분화는 화산폭발지수 7로 분류되며, 역사 시대에 관측된 분화 가운데 최대 규모로 꼽힌다.\n\n분화로 산 정상부가 붕괴해 대형 칼데라가 형성되었다. 화쇄류와 화산재 낙하, 이어진 기근으로 인근 지역에서 큰 인명 피해가 발생했으며, 사망자 추정치는 자료에 따라 차이가 크다.\n\n분화가 성층권으로 올려보낸 이산화황은 황산 에어로졸을 형성해 태양 복사를 반사했다. 그 결과 이듬해 북반구 평균 기온이 내려갔고, 뉴잉글랜드와 캐나다 동부에서는 여름철에 서리와 강설이 기록되었으며 서유럽에서는 장기간의 저온과 강우로 수확이 크게 줄었다.\n\n1816년의 기근과 이동은 여러 사회적 결과를 낳았고, 같은 해 제네바 호숫가에서 악천후로 실내에 머물던 문인들의 모임이 문학 작품의 배경이 된 사례도 알려져 있다. 이 분화는 대규모 화산 활동이 단기 기후에 미치는 영향을 보여주는 사례로 연구되어 왔다.", "en": "Tambora is a stratovolcano on Sumbawa in the Lesser Sunda Islands of Indonesia. The eruption began on 5 April 1815 and reached its climax on 10 April. It is classified at volcanic explosivity index 7 and is counted among the largest eruptions observed in the historical period.\n\nThe summit collapsed during the eruption, forming a large caldera. Pyroclastic flows, ashfall and the famine that followed caused heavy loss of life in the surrounding region, and mortality estimates differ considerably between sources.\n\nSulphur dioxide injected into the stratosphere formed sulphate aerosols that reflected solar radiation. Average temperatures in the northern hemisphere fell the following year: frost and snow were recorded in summer in New England and eastern Canada, while prolonged cold and rain sharply reduced harvests in western Europe.\n\nThe famine and migration of 1816 had several social consequences, and it is also recorded that a gathering of writers kept indoors by the poor weather beside Lake Geneva that year produced work of lasting note. The eruption has been studied as a case showing how large volcanic events affect short-term climate.", "ja": "タンボラはインドネシア・小スンダ列島のスンバワ島にある成層火山である。1815年4月5日に噴火が始まり、4月10日に最盛期に達した。この噴火は火山爆発指数7に分類され、歴史時代に観測された噴火のうち最大規模に数えられる。\n\n噴火により山頂部が崩壊して大型のカルデラが形成された。火砕流と火山灰の降下、続く飢饉によって周辺地域で大きな人的被害が生じ、死者の推定値は資料によって差が大きい。\n\n噴火が成層圏へ送り込んだ二酸化硫黄は硫酸エアロゾルを形成して太陽放射を反射した。その結果、翌年の北半球の平均気温が下がり、ニューイングランドやカナダ東部では夏に霜と降雪が記録され、西ヨーロッパでは長期の低温と降雨で収穫が大きく減った。\n\n1816年の飢饉と移動はさまざまな社会的帰結をもたらし、同じ年にジュネーヴ湖畔で悪天候のため屋内にとどまった文人たちの集まりが文学作品の背景となった事例も知られている。この噴火は、大規模な火山活動が短期の気候に及ぼす影響を示す事例として研究されてきた。"}'::jsonb,
 date '1815-04-10',
 array['탐보라','화산','기후','1816','여름없는해']::text[],
 'Smithsonian Institution, Global Volcanism Program, Tambora (264040) / Clive Oppenheimer, "Climatic, environmental and human consequences of the largest known historic eruption: Tambora volcano (Indonesia) 1815", Progress in Physical Geography 27(2), 230-259 (2003)',
 2)

) as d(planet_id, category_id, subcategory_id, title, summary, content,
       event_date, tags, source, level)
where not exists (select 1 from public.records
                   where is_seed and title ->> 'ko' = '함무라비 법전의 편찬');

-- [지구 / 근대 2, 현대 10] ---------------------------------------
insert into public.records
  (planet_id, category_id, subcategory_id, title, summary, content,
   event_date, tags, source, level, is_seed, author_id)
select d.planet_id, d.category_id, d.subcategory_id, d.title, d.summary, d.content,
       d.event_date, d.tags, d.source, d.level, true,
       (select id from public.profiles where keeper_code = 'KEEPER-000')
from (values

-- 11. 베토벤 교향곡 제9번 초연 (근대)
('TERRA-001','ART-007','MUSIC',
 '{"ko":"베토벤 교향곡 제9번 초연","en":"Premiere of Beethoven''s Ninth Symphony","ja":"ベートーヴェン交響曲第9番の初演"}'::jsonb,
 '{"ko":"1824년 5월 7일 빈의 케른트너토어 극장에서 루트비히 판 베토벤의 교향곡 제9번이 처음 연주되었다. 마지막 악장에 실러의 시를 가사로 한 성악을 도입해, 교향곡에 합창을 결합한 초기 사례가 되었다.","en":"The Ninth Symphony of Ludwig van Beethoven was first performed at the Theater am Kärntnertor in Vienna on 7 May 1824. Its final movement introduces voices setting a poem by Schiller, an early instance of a choral finale within a symphony.","ja":"1824年5月7日、ウィーンのケルントナートーア劇場でルートヴィヒ・ヴァン・ベートーヴェンの交響曲第9番が初演された。終楽章にシラーの詩を歌詞とする声楽を導入し、交響曲に合唱を結合した初期の例となった。"}'::jsonb,
 '{"ko": "베토벤은 1810년대 후반부터 청력을 거의 잃은 상태에서 작곡을 이어가고 있었다. 교향곡 제9번은 여러 해에 걸쳐 구상과 작업이 진행되었고, 실러의 시 환희에 부쳐를 가사로 쓰려는 생각은 그보다 훨씬 이전부터 있었던 것으로 전해진다.\n\n초연은 1824년 5월 7일 빈 케른트너토어 극장에서 이루어졌다. 실제 지휘는 미하엘 움라우프가 맡았고, 베토벤은 무대 위에서 악보를 보며 템포를 지시했다. 연주자들은 사전에 움라우프의 지시를 따르도록 안내받았다.\n\n연주가 끝난 뒤 객석의 반응을 듣지 못한 베토벤이 성악가의 안내로 돌아서서 청중을 보았다는 일화가 당대 기록으로 전한다. 이 장면은 이후 여러 전기에 인용되었다.\n\n네 개 악장 가운데 마지막 악장은 독창과 합창을 포함하며, 순수 기악 형식으로 여겨지던 교향곡의 범위를 넓혔다. 자필 악보는 2001년 유네스코 세계기록유산에 등재되었고, 이 작품의 선율은 이후 여러 공적 상징으로 사용되었다.", "en": "Beethoven had continued composing from the late 1810s with almost no hearing. The Ninth Symphony was conceived and worked out over several years, and the intention to set the poem An die Freude by Schiller is reported to date from much earlier.\n\nThe premiere took place at the Theater am Kärntnertor in Vienna on 7 May 1824. Michael Umlauf conducted, while Beethoven stood on stage following the score and indicating tempi. The performers had been instructed in advance to follow Umlauf.\n\nContemporary accounts relate that Beethoven, unable to hear the response of the hall after the performance, was turned toward the audience by one of the singers. The scene has been quoted in many later biographies.\n\nThe last of the four movements includes soloists and chorus, extending the scope of a form that had been treated as purely instrumental. The autograph score was inscribed on the UNESCO Memory of the World Register in 2001, and the melody of the finale has since been adopted in various official settings.", "ja": "ベートーヴェンは1810年代後半からほとんど聴力を失った状態で作曲を続けていた。交響曲第9番は数年にわたって構想と作業が進められ、シラーの詩「歓喜に寄せて」を歌詞に用いる考えはそれよりずっと以前からあったと伝えられる。\n\n初演は1824年5月7日、ウィーンのケルントナートーア劇場で行われた。実際の指揮はミヒャエル・ウムラウフが担い、ベートーヴェンは舞台上で楽譜を追いながらテンポを示した。演奏者にはあらかじめウムラウフの指示に従うよう伝えられていた。\n\n演奏の後、客席の反応が聞こえなかったベートーヴェンが歌手に促されて振り返り聴衆を見た、という逸話が同時代の記録に伝わる。この場面はのちに多くの伝記で引用された。\n\n四つの楽章のうち最終楽章は独唱と合唱を含み、純粋な器楽形式とされてきた交響曲の範囲を広げた。自筆譜は2001年にユネスコ世界の記憶に登録され、この作品の旋律はその後さまざまな公的な場面で用いられている。"}'::jsonb,
 date '1824-05-07',
 array['베토벤','교향곡','빈','합창','초연']::text[],
 'Beethoven-Haus Bonn, digital archive (Symphony No. 9, op. 125) / Barry Cooper, Beethoven (Oxford University Press, 2000) / UNESCO Memory of the World Register, Ludwig van Beethoven, Symphony No. 9 autograph (2001)',
 1),

-- 12. 종의 기원 (근대)
('TERRA-001','LIFE-005','EVOLUTION',
 '{"ko":"다윈 『종의 기원』 출간","en":"Publication of On the Origin of Species","ja":"ダーウィン『種の起源』の刊行"}'::jsonb,
 '{"ko":"1859년 11월 24일 런던의 존 머리 출판사가 찰스 다윈의 종의 기원을 출간했다. 이 책은 자연선택을 통해 생물의 형질이 세대를 거치며 변화한다는 설명을 관찰 자료와 함께 제시했다.","en":"On 24 November 1859 the London publisher John Murray issued On the Origin of Species by Charles Darwin. The book set out, with supporting observation, an account of how the characteristics of organisms change across generations through natural selection.","ja":"1859年11月24日、ロンドンのジョン・マレー社がチャールズ・ダーウィンの『種の起源』を刊行した。本書は自然選択を通じて生物の形質が世代を経て変化するという説明を、観察資料とともに提示した。"}'::jsonb,
 '{"ko": "다윈은 1831년부터 1836년까지 측량선 비글호에 승선해 남아메리카 연안과 갈라파고스 제도 등을 조사했다. 항해에서 수집한 표본과 지질 관찰은 귀국 후 오랜 기간에 걸쳐 정리되었다.\n\n그는 사육 동식물의 인위 선택과 야생 개체군의 변이를 비교하면서, 생존과 번식에서 유리한 형질이 다음 세대에 더 많이 전달된다는 설명 틀을 다듬었다. 자료 축적을 이유로 발표를 미루던 중, 1858년 앨프리드 러셀 월리스가 유사한 착상을 담은 원고를 보내오면서 상황이 바뀌었다.\n\n두 사람의 글은 1858년 린네학회에서 함께 발표되었고, 다윈은 이듬해 요약본 성격의 단행본을 서둘러 완성했다. 초판은 1859년 11월 24일에 나왔으며 인쇄 부수는 1,250부였다.\n\n책은 발간 직후부터 자연과학계와 사회 전반에서 논쟁을 불러왔다. 유전의 구체적 메커니즘은 당시에 알려져 있지 않았고, 이 부분은 20세기 유전학이 정립된 뒤에야 이론과 결합되었다.", "en": "Darwin sailed on the survey ship Beagle from 1831 to 1836, examining the coasts of South America and the Galapagos Islands among other places. The specimens and geological observations gathered on the voyage were worked over for many years after his return.\n\nComparing artificial selection in domesticated plants and animals with variation in wild populations, he refined an account in which traits favourable to survival and reproduction are transmitted more widely to the next generation. He delayed publication while accumulating evidence until 1858, when Alfred Russel Wallace sent him a manuscript containing a similar idea.\n\nThe writings of both men were presented together at the Linnean Society in 1858, and Darwin completed a book he described as an abstract in the following year. The first edition appeared on 24 November 1859 in a print run of 1,250 copies.\n\nThe book provoked debate in the natural sciences and in wider society from the moment it appeared. The mechanism of inheritance was not known at the time, and that part was joined to the theory only after genetics was established in the twentieth century.", "ja": "ダーウィンは1831年から1836年まで測量船ビーグル号に乗り、南アメリカ沿岸やガラパゴス諸島などを調査した。航海で収集した標本と地質観察は、帰国後の長い期間をかけて整理された。\n\n彼は飼育動植物の人為選択と野生個体群の変異を比較しながら、生存と繁殖に有利な形質が次の世代へより多く伝わるという説明の枠組みを練り上げた。資料の蓄積を理由に発表を先延ばしにしていたが、1858年にアルフレッド・ラッセル・ウォレスが同様の着想を含む原稿を送ってきたことで状況が変わった。\n\n二人の論考は1858年にリンネ協会で併せて発表され、ダーウィンは翌年、要約という性格の単行本を急いで完成させた。初版は1859年11月24日に出され、印刷部数は1,250部であった。\n\n書物は刊行直後から自然科学界と社会全般で論争を呼んだ。遺伝の具体的な仕組みは当時知られておらず、この部分は20世紀に遺伝学が確立されたのちに理論と結び付けられた。"}'::jsonb,
 date '1859-11-24',
 array['다윈','진화','자연선택','생물학','비글호']::text[],
 'Charles Darwin, On the Origin of Species by Means of Natural Selection (John Murray, 1859) / Darwin Correspondence Project, University of Cambridge',
 2),

-- 13. 라이트 형제 (현대)
('TERRA-001','TECH-004','TRANSPORT',
 '{"ko":"라이트 형제의 첫 동력 비행","en":"The First Powered Flights of the Wright Brothers","ja":"ライト兄弟による初の動力飛行"}'::jsonb,
 '{"ko":"1903년 12월 17일 미국 노스캐롤라이나 키티호크 인근 킬데블힐스에서 라이트 형제가 플라이어로 네 차례 비행에 성공했다. 첫 비행은 오빌 라이트가 조종해 12초 동안 약 36미터를 날았다.","en":"On 17 December 1903 the Wright brothers made four flights with their Flyer at Kill Devil Hills near Kitty Hawk, North Carolina. The first, piloted by Orville Wright, lasted 12 seconds and covered about 36 metres.","ja":"1903年12月17日、アメリカ・ノースカロライナ州キティホーク近郊のキルデビルヒルズで、ライト兄弟がフライヤー号により4回の飛行に成功した。最初の飛行はオーヴィル・ライトの操縦で12秒間、約36メートルを飛んだ。"}'::jsonb,
 '{"ko": "윌버와 오빌 라이트는 오하이오주 데이턴에서 자전거 제작과 수리를 하며 비행 문제를 연구했다. 이들은 양력과 추진력만이 아니라 비행 중 자세를 제어하는 문제가 핵심이라고 보고, 날개를 비틀어 좌우 균형을 잡는 방식을 고안했다.\n\n1900년부터 키티호크 인근에서 글라이더 시험을 반복했고, 기존에 알려진 공기역학 계수가 실제와 맞지 않는다는 점을 확인한 뒤 직접 풍동을 만들어 날개 형상을 시험했다. 엔진과 프로펠러도 자체 설계로 제작했다.\n\n1903년 12월 17일 킬데블힐스에서 네 차례 비행이 이루어졌다. 첫 비행은 오빌이 조종해 12초간 약 36미터를 비행했고, 그날 마지막 비행은 윌버가 조종해 59초 동안 약 260미터를 날았다. 착륙 후 돌풍에 기체가 파손되어 그날의 시험은 종료되었다.\n\n형제는 이후 데이턴 인근에서 시험을 이어가며 실용적인 조종성과 지속 비행 능력을 확보했다. 1903년 플라이어 기체는 현재 스미스소니언 국립항공우주박물관에 전시되어 있다.", "en": "Wilbur and Orville Wright ran a bicycle shop in Dayton, Ohio, while studying the problem of flight. They judged that the central difficulty was not lift and thrust alone but control of attitude in the air, and devised a method of warping the wings to balance the machine laterally.\n\nFrom 1900 they tested gliders near Kitty Hawk, and after finding that published aerodynamic coefficients did not match their results they built a wind tunnel and tested wing shapes themselves. They also designed and built their own engine and propellers.\n\nFour flights were made at Kill Devil Hills on 17 December 1903. Orville piloted the first, of 12 seconds and about 36 metres, and Wilbur the last of that day, of 59 seconds and about 260 metres. A gust damaged the machine after landing and testing ended for the day.\n\nThe brothers continued trials near Dayton and achieved practical control and sustained flight. The 1903 Flyer is now displayed at the Smithsonian National Air and Space Museum.", "ja": "ウィルバーとオーヴィル・ライトはオハイオ州デイトンで自転車の製作と修理を営みながら飛行の問題を研究していた。二人は、揚力と推進力だけでなく飛行中の姿勢を制御する問題こそが核心だと考え、翼をねじって左右の釣り合いを取る方式を考案した。\n\n1900年からキティホーク近郊でグライダー試験を繰り返し、既知の空気力学係数が実際と合わないことを確認したのち、自ら風洞を作って翼形を試験した。エンジンとプロペラも自前の設計で製作した。\n\n1903年12月17日、キルデビルヒルズで4回の飛行が行われた。最初の飛行はオーヴィルの操縦で12秒間およそ36メートル、その日の最後の飛行はウィルバーの操縦で59秒間およそ260メートルを飛んだ。着陸後に突風で機体が損傷し、その日の試験は終了した。\n\n兄弟はその後デイトン近郊で試験を続け、実用的な操縦性と持続飛行の能力を確立した。1903年のフライヤー号は現在スミソニアン国立航空宇宙博物館に展示されている。"}'::jsonb,
 date '1903-12-17',
 array['라이트형제','비행','항공','키티호크','플라이어']::text[],
 'Library of Congress, Wilbur and Orville Wright Papers / Smithsonian National Air and Space Museum, 1903 Wright Flyer object record',
 1),

-- 14. 제1차 세계대전 (현대)
('TERRA-001','WAR-003','WORLDWAR',
 '{"ko":"제1차 세계대전의 발발","en":"The Outbreak of the First World War","ja":"第一次世界大戦の勃発"}'::jsonb,
 '{"ko":"1914년 6월 28일 사라예보에서 오스트리아-헝가리 황위 계승자가 피살된 뒤, 7월 28일 오스트리아-헝가리가 세르비아에 선전포고했다. 동맹 관계가 연쇄적으로 작동하면서 전쟁은 유럽 전역과 그 밖의 지역으로 확대되었다.","en":"After the heir to the Austro-Hungarian throne was assassinated at Sarajevo on 28 June 1914, Austria-Hungary declared war on Serbia on 28 July. Alliance commitments came into force in sequence and the war expanded across Europe and beyond.","ja":"1914年6月28日にサラエボでオーストリア＝ハンガリーの帝位継承者が暗殺された後、7月28日にオーストリア＝ハンガリーがセルビアに宣戦布告した。同盟関係が連鎖的に作動し、戦争はヨーロッパ全域とその外部へ拡大した。"}'::jsonb,
 '{"ko": "20세기 초 유럽은 동맹 체계와 군비 확장, 발칸 지역의 영토 분쟁이 겹친 상태에 있었다. 1914년 6월 28일 보스니아 사라예보를 방문한 오스트리아-헝가리 황위 계승자 프란츠 페르디난트 대공 부부가 가브릴로 프린치프에게 피살되었다.\n\n오스트리아-헝가리는 세르비아에 최후통첩을 보냈고 회신을 불충분하다고 판단해 7월 28일 선전포고했다. 러시아가 동원령을 내리자 독일이 러시아와 프랑스에 선전포고했고, 독일군이 벨기에를 통과하자 영국이 참전했다.\n\n서부 전선은 초기 기동전 이후 참호선이 고착되어 장기 소모전이 되었다. 기관총과 대구경 화포, 독가스, 항공기와 전차 등이 투입되면서 전투의 양상과 피해 규모가 이전 전쟁과 크게 달라졌다.\n\n전쟁은 1918년 11월 11일 휴전으로 멈추었고, 1919년 강화 조약들로 유럽의 국경과 제국 질서가 재편되었다. 대규모 인명 손실과 경제 파괴, 제국의 해체는 이후 20세기 국제 질서의 조건이 되었다.", "en": "Europe in the early twentieth century combined alliance systems, military expansion and territorial disputes in the Balkans. On 28 June 1914 Archduke Franz Ferdinand, heir to the Austro-Hungarian throne, and his wife were shot by Gavrilo Princip while visiting Sarajevo in Bosnia.\n\nAustria-Hungary sent an ultimatum to Serbia, judged the reply insufficient and declared war on 28 July. Russia ordered mobilisation, Germany declared war on Russia and France, and Britain entered the war when German forces moved through Belgium.\n\nAfter an initial war of movement the western front settled into fixed trench lines and a long war of attrition. Machine guns, heavy artillery, poison gas, aircraft and tanks changed the character of combat and the scale of losses from earlier wars.\n\nFighting stopped with the armistice of 11 November 1918, and the peace treaties of 1919 redrew borders and imperial arrangements in Europe. The loss of life, economic destruction and dissolution of empires set the conditions for the international order of the rest of the century.", "ja": "20世紀初頭のヨーロッパは、同盟体系、軍備拡張、バルカン地域の領土紛争が重なった状態にあった。1914年6月28日、ボスニアのサラエボを訪問していたオーストリア＝ハンガリーの帝位継承者フランツ・フェルディナント大公夫妻がガヴリロ・プリンツィプに射殺された。\n\nオーストリア＝ハンガリーはセルビアへ最後通牒を送り、その回答を不十分と判断して7月28日に宣戦布告した。ロシアが動員令を出すとドイツがロシアとフランスに宣戦し、ドイツ軍がベルギーを通過したことでイギリスが参戦した。\n\n西部戦線は初期の機動戦のあと塹壕線が固定され、長期の消耗戦となった。機関銃と大口径火砲、毒ガス、航空機や戦車が投入され、戦闘の様相と被害の規模は以前の戦争と大きく異なった。\n\n戦争は1918年11月11日の休戦で止まり、1919年の講和条約群によってヨーロッパの国境と帝国秩序が再編された。大規模な人的損失、経済の破壊、帝国の解体は、その後の20世紀の国際秩序の条件となった。"}'::jsonb,
 date '1914-07-28',
 array['제1차세계대전','사라예보','참호전','동맹','1914']::text[],
 'Christopher Clark, The Sleepwalkers: How Europe Went to War in 1914 (Allen Lane, 2012) / Imperial War Museums, First World War collections',
 3),

-- 15. 1918년 인플루엔자 (현대)
('TERRA-001','EVENT-006','DISASTER',
 '{"ko":"1918년 인플루엔자 대유행","en":"The 1918 Influenza Pandemic","ja":"1918年インフルエンザ大流行"}'::jsonb,
 '{"ko":"1918년 봄부터 1920년까지 H1N1형 인플루엔자가 세 차례의 유행 파동을 이루며 전 세계로 퍼졌다. 전시 보도 통제가 덜했던 스페인의 보도가 널리 알려지면서 스페인 독감이라는 이름이 붙었다.","en":"From the spring of 1918 to 1920 an H1N1 influenza virus spread worldwide in three waves. The name Spanish flu arose because reporting circulated freely in Spain, which was not subject to wartime press restrictions.","ja":"1918年春から1920年にかけて、H1N1型インフルエンザが3度の流行の波をなして世界中に広がった。戦時の報道統制が及ばなかったスペインの報道が広く知られたため、スペイン風邪という名が付いた。"}'::jsonb,
 '{"ko": "1918년 봄 미국의 군 기지 등에서 이례적인 인플루엔자 발생이 보고되었다. 제1차 세계대전 중 병력의 대규모 이동과 밀집 수용은 전파에 유리한 조건을 만들었다.\n\n유행은 세 차례의 파동으로 진행되었다. 1918년 가을의 두 번째 파동에서 중증 사례와 사망이 가장 많이 보고되었고, 청장년층에서 사망률이 높게 나타난 점이 이전 유행과 다른 특징으로 지적된다.\n\n당시에는 인플루엔자 바이러스가 분리되기 전이어서 원인 규명과 치료가 제한적이었다. 대응은 격리, 집회 제한, 마스크 착용 권고 등 비약물적 조치에 의존했다. 사망자 총수 추정치는 자료와 방법에 따라 큰 폭의 차이를 보이며, 이 문서에서는 특정 수치를 확정하지 않는다.\n\n1990년대 이후 보존된 조직 표본과 영구동토에 매장된 유해에서 바이러스 유전자 조각이 회수되어 H1N1형임이 확인되었다. 이 유행은 이후 각국의 감시 체계와 대유행 대비 계획을 마련하는 근거 사례로 다루어졌다.", "en": "Unusual outbreaks of influenza were reported at United States military camps and other sites in the spring of 1918. Large troop movements and crowded accommodation during the First World War created conditions favourable to transmission.\n\nThe pandemic proceeded in three waves. The second wave in the autumn of 1918 produced the greatest number of severe cases and deaths, and the high mortality recorded among young adults is noted as a feature distinguishing it from earlier epidemics.\n\nThe influenza virus had not yet been isolated, so identification and treatment were limited. Responses depended on non-pharmaceutical measures such as isolation, restrictions on gatherings and advice to wear masks. Estimates of total mortality vary widely with the sources and methods used, and this document does not fix a single figure.\n\nFrom the 1990s fragments of viral genetic material were recovered from preserved tissue samples and from remains buried in permafrost, confirming an H1N1 subtype. The pandemic has since been treated as a reference case in building surveillance systems and pandemic preparedness plans.", "ja": "1918年春、アメリカの軍施設などで異例のインフルエンザ発生が報告された。第一次世界大戦中の大規模な兵員移動と密集した収容は、伝播に有利な条件を作った。\n\n流行は三度の波として進行した。1918年秋の第二波で重症例と死亡が最も多く報告され、青壮年層で死亡率が高く現れた点が以前の流行と異なる特徴として指摘される。\n\n当時はインフルエンザウイルスが分離される前であり、原因の究明と治療は限られていた。対応は隔離、集会の制限、マスク着用の勧告といった非薬物的措置に依存した。死亡総数の推定値は資料と方法によって大きな幅があり、本文書では特定の数値を確定しない。\n\n1990年代以降、保存された組織標本や永久凍土に埋葬された遺骸からウイルスの遺伝子断片が回収され、H1N1型であることが確認された。この流行はその後、各国の監視体制と大流行への備えを整える根拠事例として扱われた。"}'::jsonb,
 date '1918-03-01',
 array['인플루엔자','대유행','H1N1','공중보건','1918']::text[],
 'Jeffery K. Taubenberger and David M. Morens, "1918 Influenza: the Mother of All Pandemics", Emerging Infectious Diseases 12(1), 15-22 (2006) / US Centers for Disease Control and Prevention, 1918 Pandemic (H1N1 virus)',
 2),

-- 16. 맨해튼 프로젝트 (현대)
('TERRA-001','TECH-004','ENERGY',
 '{"ko":"맨해튼 프로젝트: 핵분열 무기 개발","en":"The Manhattan Project: Development of Fission Weapons","ja":"マンハッタン計画：核分裂兵器の開発"}'::jsonb,
 '{"ko":"1942년 8월 13일 미 육군 공병대에 맨해튼 공병관구가 설치되면서 핵분열 무기 개발이 군 관리 아래 대규모 사업으로 전환되었다. 우라늄 농축과 플루토늄 생산, 무기 설계가 여러 시설에 나뉘어 동시에 진행되었다.","en":"The establishment of the Manhattan Engineer District within the US Army Corps of Engineers on 13 August 1942 turned fission weapon research into a large programme under military direction. Uranium enrichment, plutonium production and weapon design proceeded in parallel at separate sites.","ja":"1942年8月13日、アメリカ陸軍工兵隊にマンハッタン工兵管区が設置され、核分裂兵器の開発は軍の管理下で大規模事業へ転換した。ウラン濃縮、プルトニウム生産、兵器設計が複数の施設に分かれて並行して進められた。"}'::jsonb,
 '{"ko": "1938년 말 독일에서 핵분열 현상이 확인되고 이듬해 그 해석이 발표되면서, 연쇄 반응을 이용한 폭발적 에너지 방출 가능성이 물리학계에서 논의되었다. 미국에서는 1939년 아인슈타인이 서명한 서한이 대통령에게 전달되며 초기 검토가 시작되었다.\n\n1942년 8월 13일 육군 공병대에 맨해튼 공병관구가 설치되었고, 9월에 레슬리 그로브스 준장이 사업을 총괄하게 되었다. 로버트 오펜하이머가 뉴멕시코 로스앨러모스 연구소의 책임을 맡아 무기 설계를 담당했다.\n\n1942년 12월 2일 시카고 대학에서 엔리코 페르미 팀이 시카고 파일 1호로 제어된 핵분열 연쇄 반응을 처음 달성했다. 테네시 오크리지에서는 우라늄-235 농축이, 워싱턴주 핸퍼드에서는 원자로를 이용한 플루토늄 생산이 진행되었다.\n\n1945년 7월 16일 뉴멕시코 앨라모고도 부근에서 플루토늄 내폭형 장치의 트리니티 실험이 실시되었다. 같은 해 8월 히로시마와 나가사키에 핵무기가 사용되었으며, 이후 핵무기 보유와 통제 문제는 국제 정치의 중심 의제가 되었다.", "en": "After nuclear fission was observed in Germany at the end of 1938 and interpreted in print the following year, physicists discussed the possibility of an explosive release of energy through a chain reaction. In the United States a letter signed by Einstein was delivered to the president in 1939 and early study began.\n\nThe Manhattan Engineer District was established within the Army Corps of Engineers on 13 August 1942, and Brigadier General Leslie Groves took charge of the programme in September. Robert Oppenheimer directed the laboratory at Los Alamos in New Mexico, which was responsible for weapon design.\n\nOn 2 December 1942 a team under Enrico Fermi achieved the first controlled fission chain reaction with Chicago Pile-1 at the University of Chicago. Uranium-235 enrichment was carried out at Oak Ridge in Tennessee, and reactor production of plutonium at Hanford in Washington state.\n\nThe Trinity test of an implosion-type plutonium device took place near Alamogordo, New Mexico, on 16 July 1945. Nuclear weapons were used against Hiroshima and Nagasaki in August of that year, and the possession and control of such weapons became a central question in international politics.", "ja": "1938年末にドイツで核分裂現象が確認され、翌年その解釈が発表されると、連鎖反応を用いた爆発的なエネルギー放出の可能性が物理学界で議論された。アメリカでは1939年にアインシュタインが署名した書簡が大統領に届けられ、初期の検討が始まった。\n\n1942年8月13日、陸軍工兵隊にマンハッタン工兵管区が設置され、9月にレズリー・グローヴス准将が事業を統括することになった。ロバート・オッペンハイマーがニューメキシコ州ロスアラモス研究所の責任者となり兵器設計を担当した。\n\n1942年12月2日、シカゴ大学でエンリコ・フェルミの一団がシカゴ・パイル1号により制御された核分裂連鎖反応を初めて達成した。テネシー州オークリッジではウラン235の濃縮が、ワシントン州ハンフォードでは原子炉によるプルトニウム生産が進められた。\n\n1945年7月16日、ニューメキシコ州アラモゴード付近でプルトニウム爆縮型装置のトリニティ実験が実施された。同年8月に広島と長崎で核兵器が使用され、以後、核兵器の保有と管理の問題は国際政治の中心的議題となった。"}'::jsonb,
 date '1942-08-13',
 array['핵무기','맨해튼프로젝트','핵분열','제2차세계대전','로스앨러모스']::text[],
 'US Department of Energy, The Manhattan Project: An Interactive History (Office of History and Heritage Resources) / Richard Rhodes, The Making of the Atomic Bomb (Simon & Schuster, 1986)',
 3),

-- 17. DNA 이중나선 (현대)
('TERRA-001','LIFE-005','GENETICS',
 '{"ko":"DNA 이중나선 구조의 규명","en":"Determination of the DNA Double Helix","ja":"DNA二重らせん構造の解明"}'::jsonb,
 '{"ko":"1953년 4월 25일자 네이처에 제임스 왓슨과 프랜시스 크릭의 짧은 논문이 실려 DNA가 두 가닥이 꼬인 이중나선 구조라는 모형을 제시했다. 같은 호에는 킹스칼리지 런던 연구진의 X선 회절 논문도 함께 게재되었다.","en":"A short paper by James Watson and Francis Crick in Nature of 25 April 1953 proposed a model in which DNA consists of two chains wound into a double helix. The same issue carried X-ray diffraction papers from the King''s College London group.","ja":"1953年4月25日付のネイチャーにジェームズ・ワトソンとフランシス・クリックの短い論文が掲載され、DNAが2本鎖のねじれた二重らせん構造であるとする模型が示された。同じ号にはキングス・カレッジ・ロンドンの研究陣によるX線回折の論文も併せて掲載された。"}'::jsonb,
 '{"ko": "20세기 전반 유전 물질의 정체를 두고 단백질과 핵산 사이에서 논의가 이어졌다. 1944년 에이버리 연구팀의 형질전환 실험과 1952년 허시와 체이스의 실험은 DNA가 유전 정보를 담고 있다는 근거를 제시했다.\n\n케임브리지 캐번디시 연구소의 왓슨과 크릭은 모형 조립 방식으로 구조를 탐색했다. 킹스칼리지 런던의 로절린드 프랭클린과 레이먼드 고슬링이 얻은 고해상도 X선 회절 사진과 프랭클린의 측정값은 나선 구조와 규격을 판단하는 데 결정적인 자료가 되었다.\n\n1953년 4월 25일 네이처에 실린 논문은 두 가닥이 서로 반대 방향으로 배열되고, 아데닌과 티민, 구아닌과 시토신이 짝을 이루어 안쪽에서 결합한다는 모형을 제시했다. 논문 말미에는 이 염기쌍 방식이 유전 물질의 복제 메커니즘을 시사한다는 문장이 덧붙었다.\n\n이 구조는 이후 분자생물학의 기초가 되었다. 1962년 왓슨, 크릭, 모리스 윌킨스가 노벨 생리의학상을 받았으며, 프랭클린은 1958년에 이미 사망한 상태였다. 프랭클린 자료의 기여와 인용 방식은 이후 과학사에서 지속적으로 검토되어 왔다.", "en": "Through the first half of the twentieth century the identity of the hereditary material was debated between proteins and nucleic acids. The transformation experiments of the Avery group in 1944 and the Hershey-Chase experiment of 1952 provided evidence that DNA carries genetic information.\n\nWatson and Crick at the Cavendish Laboratory in Cambridge approached the structure by building physical models. High-resolution X-ray diffraction images obtained by Rosalind Franklin and Raymond Gosling at King''s College London, together with Franklin''s measurements, were decisive in establishing the helical form and its dimensions.\n\nThe paper published in Nature on 25 April 1953 proposed that two chains run in opposite directions and that adenine pairs with thymine and guanine with cytosine on the inside of the helix. A closing sentence noted that this pairing suggested a copying mechanism for the genetic material.\n\nThe structure became the foundation of molecular biology. Watson, Crick and Maurice Wilkins received the Nobel Prize in Physiology or Medicine in 1962; Franklin had died in 1958. The contribution of her data and the manner of its citation have been examined repeatedly in the history of science since.", "ja": "20世紀前半、遺伝物質の正体をめぐってタンパク質と核酸の間で議論が続いた。1944年のエイブリーらによる形質転換実験と1952年のハーシーとチェイスの実験は、DNAが遺伝情報を担うという根拠を示した。\n\nケンブリッジのキャヴェンディッシュ研究所のワトソンとクリックは、模型を組み立てる方式で構造を探索した。キングス・カレッジ・ロンドンのロザリンド・フランクリンとレイモンド・ゴスリングが得た高解像度のX線回折写真とフランクリンの測定値は、らせん構造とその寸法を判断するうえで決定的な資料となった。\n\n1953年4月25日のネイチャーに載った論文は、二本の鎖が互いに逆向きに並び、アデニンとチミン、グアニンとシトシンが対をなして内側で結合するという模型を示した。論文の末尾には、この塩基対の方式が遺伝物質の複製機構を示唆するという一文が添えられた。\n\nこの構造はその後の分子生物学の基礎となった。1962年にワトソン、クリック、モーリス・ウィルキンスがノーベル生理学・医学賞を受けたが、フランクリンは1958年にすでに没していた。フランクリンの資料の寄与とその引用のあり方は、その後も科学史において繰り返し検討されてきた。"}'::jsonb,
 date '1953-04-25',
 array['DNA','이중나선','유전학','분자생물학','네이처']::text[],
 'J. D. Watson and F. H. C. Crick, "Molecular Structure of Nucleic Acids", Nature 171, 737-738 (1953) / R. E. Franklin and R. G. Gosling, "Molecular Configuration in Sodium Thymonucleate", Nature 171, 740-741 (1953)',
 2),

-- 18. 아폴로 11호 (현대)
('TERRA-001','TECH-004','SPACE',
 '{"ko":"아폴로 11호의 달 착륙","en":"The Apollo 11 Lunar Landing","ja":"アポロ11号の月面着陸"}'::jsonb,
 '{"ko":"1969년 7월 20일 아폴로 11호의 착륙선 이글이 달의 고요의 바다에 착륙했다. 닐 암스트롱과 버즈 올드린이 달 표면에서 활동했고, 마이클 콜린스는 사령선에 남아 달 궤도를 돌았다.","en":"On 20 July 1969 the Apollo 11 lunar module Eagle landed in the Sea of Tranquillity. Neil Armstrong and Buzz Aldrin worked on the surface while Michael Collins remained in lunar orbit aboard the command module.","ja":"1969年7月20日、アポロ11号の着陸船イーグルが月の静かの海に着陸した。ニール・アームストロングとバズ・オルドリンが月面で活動し、マイケル・コリンズは司令船に残って月周回軌道を回った。"}'::jsonb,
 '{"ko": "1961년 미국은 1960년대가 끝나기 전에 사람을 달에 보내고 무사히 귀환시키겠다는 목표를 공표했다. 이후 머큐리와 제미니 계획을 통해 궤도 랑데부와 도킹, 선외 활동 기술이 축적되었고, 새턴 V 발사체와 아폴로 우주선이 개발되었다.\n\n아폴로 11호는 1969년 7월 16일 케네디 우주센터에서 발사되었다. 7월 20일 착륙선 이글이 사령선에서 분리되어 하강했고, 자동 유도 지점이 바위 지대로 확인되자 암스트롱이 수동으로 조종해 착륙 지점을 옮겼다. 착륙은 협정세계시 20시 17분에 이루어졌다.\n\n선외 활동은 협정세계시 기준 7월 21일에 시작되었다. 두 승무원은 표면에서 시료를 채취하고 태양풍 포집 장치, 레이저 반사경, 지진계 등을 설치했다. 회수된 월면 시료의 총 질량은 약 21.5킬로그램이었다.\n\n착륙선 상승단은 사령선과 다시 도킹했고, 세 승무원은 7월 24일 태평양에 착수해 귀환했다. 설치된 레이저 반사경은 이후에도 지구와 달 사이 거리 측정에 사용되고 있다.", "en": "In 1961 the United States announced the goal of landing a person on the Moon and returning them safely before the end of the decade. The Mercury and Gemini programmes built up techniques for orbital rendezvous, docking and extravehicular activity, and the Saturn V launch vehicle and Apollo spacecraft were developed.\n\nApollo 11 launched from the Kennedy Space Center on 16 July 1969. On 20 July the lunar module Eagle separated and descended; when the automatic guidance target proved to be a boulder field, Armstrong took manual control and moved the landing point. Touchdown occurred at 20:17 UTC.\n\nThe surface excursion began on 21 July UTC. The two crew members collected samples and deployed a solar wind collector, a laser retroreflector and a seismometer. The returned lunar material totalled about 21.5 kilograms.\n\nThe ascent stage rejoined the command module, and the three crew members splashed down in the Pacific on 24 July. The retroreflector left on the surface is still used for measurements of the Earth-Moon distance.", "ja": "1961年、アメリカは1960年代が終わる前に人を月へ送り無事に帰還させるという目標を公表した。以後、マーキュリー計画とジェミニ計画を通じて軌道ランデブー、ドッキング、船外活動の技術が蓄積され、サターンV型ロケットとアポロ宇宙船が開発された。\n\nアポロ11号は1969年7月16日にケネディ宇宙センターから打ち上げられた。7月20日、着陸船イーグルが司令船から分離して降下し、自動誘導の目標地点が岩塊地帯だと判明するとアームストロングが手動操縦に切り替えて着陸地点を移した。着陸は協定世界時20時17分に行われた。\n\n船外活動は協定世界時で7月21日に始まった。二人の乗員は表面で試料を採取し、太陽風採集装置、レーザー反射鏡、地震計などを設置した。回収された月面試料の総質量はおよそ21.5キログラムであった。\n\n着陸船の上昇段は司令船と再びドッキングし、三人の乗員は7月24日に太平洋へ着水して帰還した。設置されたレーザー反射鏡は現在も地球と月の距離の測定に用いられている。"}'::jsonb,
 date '1969-07-20',
 array['아폴로11호','달착륙','NASA','우주개발','고요의바다']::text[],
 'NASA, Apollo 11 Mission Report (MSC-00171, November 1969) / NASA Apollo Lunar Surface Journal',
 1),

-- 19. ARPANET (현대)
('TERRA-001','TECH-004','INFO',
 '{"ko":"ARPANET 최초의 노드 간 통신","en":"The First ARPANET Host-to-Host Message","ja":"ARPANET初のノード間通信"}'::jsonb,
 '{"ko":"1969년 10월 29일 UCLA의 컴퓨터가 스탠퍼드 연구소 컴퓨터에 처음으로 원격 접속을 시도했다. 전송 도중 시스템이 멈춰 두 글자만 전달되었으나, 이는 패킷 교환 방식 광역 네트워크의 첫 노드 간 통신으로 기록되었다.","en":"On 29 October 1969 a computer at UCLA attempted the first remote login to a machine at the Stanford Research Institute. The system crashed partway through and only two characters arrived, but the exchange is recorded as the first host-to-host message on a packet-switched wide area network.","ja":"1969年10月29日、UCLAの計算機がスタンフォード研究所の計算機へ初めて遠隔ログインを試みた。送信途中でシステムが停止し2文字のみが届いたが、これはパケット交換方式の広域ネットワークにおける最初のノード間通信として記録された。"}'::jsonb,
 '{"ko": "1960년대 미국 고등연구계획국은 연구 기관들이 보유한 서로 다른 컴퓨터를 연결하는 네트워크를 구상했다. 회선을 독점하는 교환 방식 대신 데이터를 작은 단위로 나누어 전달하는 패킷 교환 개념이 이 구상의 기반이 되었다.\n\n각 노드에는 인터페이스 메시지 프로세서라는 전용 장비가 놓였고, 이 장비는 BBN이 제작했다. 1969년 9월 첫 IMP가 UCLA에 설치되었고, 이어 스탠퍼드 연구소에 두 번째 장비가 놓였다.\n\n10월 29일 UCLA의 찰리 클라인이 스탠퍼드 연구소 시스템에 로그인을 시도하며 문자를 입력했다. 두 글자가 전달된 시점에 원격 시스템이 멈추었고, 복구 후 접속이 완료되었다. 당시 상황은 UCLA의 IMP 운영 일지에 기록되어 있다.\n\n연말까지 UCLA, 스탠퍼드 연구소, 캘리포니아대 샌타바버라, 유타대의 네 개 노드가 연결되었다. 이 네트워크에서 개발된 프로토콜과 운영 경험은 이후 TCP/IP 기반 인터넷으로 이어졌다.", "en": "In the 1960s the Advanced Research Projects Agency in the United States planned a network linking the different computers held by research institutions. The concept of packet switching, in which data is divided into small units for delivery rather than holding a circuit open, formed the basis of that plan.\n\nEach node was fitted with dedicated equipment called an Interface Message Processor, built by BBN. The first IMP was installed at UCLA in September 1969 and a second at the Stanford Research Institute soon after.\n\nOn 29 October Charley Kline at UCLA typed characters while attempting to log in to the SRI system. The remote system stopped after two characters had been delivered, and the connection was completed after a restart. The event is noted in the IMP log kept at UCLA.\n\nBy the end of the year four nodes were connected: UCLA, SRI, the University of California at Santa Barbara and the University of Utah. The protocols and operational experience developed on this network led to the TCP/IP based Internet.", "ja": "1960年代、アメリカ高等研究計画局は研究機関が持つ異なる計算機を接続するネットワークを構想した。回線を占有する交換方式に代えて、データを小さな単位に分けて届けるパケット交換の概念がこの構想の基礎となった。\n\n各ノードにはインターフェース・メッセージ・プロセッサという専用装置が置かれ、この装置はBBNが製作した。1969年9月に最初のIMPがUCLAへ設置され、続いてスタンフォード研究所に2台目が置かれた。\n\n10月29日、UCLAのチャーリー・クラインがスタンフォード研究所のシステムへログインを試みて文字を入力した。2文字が届いた時点で遠隔のシステムが停止し、復旧後に接続が完了した。当時の状況はUCLAのIMP運用日誌に記録されている。\n\n年末までにUCLA、スタンフォード研究所、カリフォルニア大学サンタバーバラ校、ユタ大学の4ノードが接続された。このネットワークで開発されたプロトコルと運用経験は、のちのTCP/IPに基づくインターネットへつながった。"}'::jsonb,
 date '1969-10-29',
 array['ARPANET','네트워크','패킷교환','인터넷','UCLA']::text[],
 'UCLA Kleinrock Internet History Center, IMP Log entry of 29 October 1969 / Internet Society, Brief History of the Internet (Leiner et al.)',
 2),

-- 20. 체르노빌 (현대)
('TERRA-001','EVENT-006','ACCIDENT',
 '{"ko":"체르노빌 원자력 발전소 사고","en":"The Chernobyl Nuclear Power Plant Accident","ja":"チェルノブイリ原子力発電所事故"}'::jsonb,
 '{"ko":"1986년 4월 26일 소비에트 우크라이나 체르노빌 원자력 발전소 4호기에서 안전 시험 중 출력이 급격히 상승해 폭발과 화재가 발생했다. 방사성 물질이 광범위하게 확산되었고, 국제원자력사고등급 최고 단계인 7등급으로 분류되었다.","en":"On 26 April 1986 reactor 4 of the Chernobyl nuclear power plant in Soviet Ukraine underwent a rapid power excursion during a safety test, causing an explosion and fire. Radioactive material spread widely, and the accident was rated level 7, the highest on the International Nuclear Event Scale.","ja":"1986年4月26日、ソビエト・ウクライナのチェルノブイリ原子力発電所4号機で安全試験中に出力が急上昇し、爆発と火災が発生した。放射性物質が広範囲に拡散し、国際原子力事象評価尺度の最高段階であるレベル7に分類された。"}'::jsonb,
 '{"ko": "체르노빌 발전소는 흑연 감속 비등 경수형인 RBMK-1000 원자로를 운용하고 있었다. 1986년 4월 25일부터 4호기에서는 외부 전원이 끊겼을 때 터빈의 관성 회전으로 냉각 펌프를 얼마나 유지할 수 있는지 확인하는 시험이 준비되었다.\n\n시험은 계획보다 늦게, 낮은 출력 상태에서 진행되었다. 이 상태에서 원자로는 불안정해졌고, 4월 26일 새벽 제어봉 삽입이 개시된 직후 출력이 급격히 상승했다. 연료가 파손되고 증기 폭발이 일어나 원자로 상부 구조가 파괴되었으며 흑연 화재가 이어졌다.\n\n초기 대응에 투입된 소방대원과 발전소 직원 가운데 급성 방사선 증후군 환자가 발생했다. 인근 도시 프리피야트 주민은 사고 다음 날인 4월 27일 소개되었고, 이후 발전소 주변에 출입 제한 구역이 설정되었다.\n\n방출된 방사성 핵종은 바람을 따라 유럽 여러 지역에서 검출되었다. 사고 원인에 대해서는 초기 보고 이후 국제 검토가 이루어져, 원자로 설계상의 특성과 운전 절차, 안전 문화의 문제가 함께 지적되었다. 손상된 원자로는 석관으로 덮였고, 2016년 새로운 안전 격납 구조물이 설치되었다.", "en": "The Chernobyl plant operated RBMK-1000 reactors, a graphite-moderated boiling water design. From 25 April 1986 a test was prepared at reactor 4 to determine how long the rotational inertia of a turbine could sustain cooling pumps after a loss of external power.\n\nThe test was carried out later than planned and at low power. The reactor became unstable in that condition, and in the early hours of 26 April the power rose sharply shortly after control rod insertion began. Fuel failed, a steam explosion destroyed the upper structure of the reactor, and a graphite fire followed.\n\nFirefighters and plant staff involved in the initial response developed acute radiation syndrome. Residents of the nearby city of Pripyat were evacuated on 27 April, the day after the accident, and an exclusion zone was later established around the plant.\n\nReleased radionuclides were detected across many parts of Europe as they travelled with the wind. International review after the initial reports identified design characteristics of the reactor, operating procedures and safety culture together as contributing causes. The damaged reactor was covered by a shelter structure, and a new safe confinement was installed in 2016.", "ja": "チェルノブイリ発電所は黒鉛減速沸騰軽水型のRBMK-1000炉を運用していた。1986年4月25日から4号機では、外部電源が失われたときにタービンの慣性回転で冷却ポンプをどれだけ維持できるかを確認する試験が準備されていた。\n\n試験は計画より遅れ、低出力の状態で行われた。この状態で原子炉は不安定になり、4月26日未明、制御棒の挿入が始まった直後に出力が急上昇した。燃料が破損し、蒸気爆発によって原子炉上部の構造が破壊され、黒鉛火災が続いた。\n\n初期対応に投入された消防隊員と発電所職員のなかから急性放射線症候群の患者が出た。近隣都市プリピャチの住民は事故の翌日である4月27日に避難し、その後発電所の周囲に立入制限区域が設定された。\n\n放出された放射性核種は風に乗ってヨーロッパ各地で検出された。事故原因については初期報告ののち国際的な検討が行われ、原子炉の設計上の特性、運転手順、安全文化の問題が併せて指摘された。損傷した原子炉は石棺で覆われ、2016年に新たな安全閉じ込め構造が設置された。"}'::jsonb,
 date '1986-04-26',
 array['체르노빌','원자력','사고','방사능','RBMK']::text[],
 'IAEA, INSAG-7: The Chernobyl Accident — Updating of INSAG-1 (Safety Series No. 75-INSAG-7, 1992) / UNSCEAR 2008 Report, Volume II, Annex D: Health effects due to radiation from the Chernobyl accident',
 3),

-- 21. 월드 와이드 웹 (현대)
('TERRA-001','TECH-004','INFO',
 '{"ko":"월드 와이드 웹의 공개","en":"The Public Release of the World Wide Web","ja":"ワールド・ワイド・ウェブの公開"}'::jsonb,
 '{"ko":"1989년 3월 CERN의 팀 버너스리가 정보 관리 제안서를 제출하면서 하이퍼텍스트 기반 정보 시스템 구상이 시작되었다. 1991년 8월 6일 그는 인터넷 뉴스그룹에 이 시스템을 공개적으로 알렸다.","en":"In March 1989 Tim Berners-Lee at CERN submitted a proposal on information management that set out a hypertext-based information system. On 6 August 1991 he announced the system publicly on an Internet newsgroup.","ja":"1989年3月、CERNのティム・バーナーズ＝リーが情報管理に関する提案書を提出し、ハイパーテキストに基づく情報システムの構想が始まった。1991年8月6日、彼はインターネットのニュースグループでこのシステムを公開した。"}'::jsonb,
 '{"ko": "CERN에는 여러 나라에서 온 연구자들이 서로 다른 장비와 문서 형식을 사용하고 있었고, 자료를 찾고 연결하는 일이 반복적인 문제였다. 팀 버너스리는 1989년 3월 이 문제를 다루는 제안서를 제출했으며, 문서를 서로 연결하는 하이퍼텍스트 구조를 해법으로 제시했다.\n\n1990년 말까지 그는 NeXT 워크스테이션에서 최초의 웹 서버와 브라우저 겸 편집기를 만들었다. 이 과정에서 문서 주소 체계, 전송 규약, 문서 기술 언어의 기본형이 함께 마련되었다.\n\n1991년 8월 6일 버너스리는 alt.hypertext 뉴스그룹에 이 프로젝트를 소개하는 글을 올려 외부에서도 접근할 수 있게 했다. 이후 여러 기관이 서버를 열었고, 1993년 그래픽 브라우저가 배포되면서 이용이 빠르게 늘었다.\n\n1993년 4월 30일 CERN은 웹 관련 소프트웨어를 로열티 없이 공개한다고 선언했다. 이 결정으로 누구나 제약 없이 구현할 수 있게 되었고, 웹은 특정 기관의 시스템이 아니라 공개 표준을 따르는 기반 구조로 자리 잡았다.", "en": "Researchers at CERN came from many countries and used different equipment and document formats, so finding and linking material was a recurring problem. Tim Berners-Lee submitted a proposal addressing this in March 1989, offering a hypertext structure connecting documents as the solution.\n\nBy the end of 1990 he had built the first web server and a combined browser and editor on a NeXT workstation. In the course of that work the basic forms of a document addressing scheme, a transfer protocol and a document markup language were established together.\n\nOn 6 August 1991 Berners-Lee posted a description of the project to the alt.hypertext newsgroup, making it accessible outside CERN. Other institutions opened servers, and use grew quickly after graphical browsers were distributed from 1993.\n\nOn 30 April 1993 CERN declared that the web software would be made available on a royalty-free basis. That decision allowed anyone to implement it without restriction, and the web became infrastructure governed by open standards rather than the system of a single institution.", "ja": "CERNには多くの国から来た研究者がおり、それぞれ異なる機器と文書形式を使っていたため、資料を探して結び付けることが繰り返し問題となっていた。ティム・バーナーズ＝リーは1989年3月にこの問題を扱う提案書を提出し、文書どうしを結ぶハイパーテキスト構造を解決策として示した。\n\n1990年末までに彼はNeXTワークステーション上で最初のウェブサーバーとブラウザ兼エディタを作った。この作業のなかで、文書のアドレス体系、転送規約、文書記述言語の基本形が併せて整えられた。\n\n1991年8月6日、バーナーズ＝リーはニュースグループ alt.hypertext にこのプロジェクトを紹介する投稿を行い、外部からも利用できるようにした。以後、複数の機関がサーバーを立ち上げ、1993年にグラフィカルなブラウザが配布されると利用は急速に増えた。\n\n1993年4月30日、CERNはウェブ関連ソフトウェアをロイヤリティなしで公開すると宣言した。この決定により誰もが制約なく実装できるようになり、ウェブは特定機関のシステムではなく公開標準に従う基盤構造として定着した。"}'::jsonb,
 date '1991-08-06',
 array['월드와이드웹','CERN','하이퍼텍스트','인터넷','버너스리']::text[],
 'Tim Berners-Lee, "Information Management: A Proposal" (CERN, March 1989) / CERN, The birth of the web (official history pages)',
 1),

-- 22. 안네 프랑크의 일기 (현대)
('TERRA-001','PERSON-009','DIARY',
 '{"ko":"안네 프랑크의 일기","en":"The Diary of Anne Frank","ja":"アンネ・フランクの日記"}'::jsonb,
 '{"ko":"안네 프랑크는 1942년 6월 12일 열세 번째 생일에 일기장을 받아 기록을 시작했다. 같은 해 7월부터 암스테르담의 은신처에서 지내며 쓴 이 일기는 1947년 아버지 오토 프랑크에 의해 출간되었다.","en":"Anne Frank received a diary on her thirteenth birthday, 12 June 1942, and began writing. The diary she kept while living in a concealed annexe in Amsterdam from July of that year was published in 1947 by her father, Otto Frank.","ja":"アンネ・フランクは1942年6月12日、13歳の誕生日に日記帳を受け取り記録を始めた。同年7月からアムステルダムの隠れ家で暮らしながら書かれたこの日記は、1947年に父オットー・フランクによって刊行された。"}'::jsonb,
 '{"ko": "프랑크 가족은 독일 프랑크푸르트에서 살다가 1930년대에 네덜란드 암스테르담으로 이주했다. 1940년 독일이 네덜란드를 점령한 뒤 유대인에 대한 제약이 단계적으로 강화되었다.\n\n안네는 1942년 6월 12일 열세 번째 생일 선물로 받은 노트에 기록을 시작했다. 7월 초 언니 마르고트에게 소집 통지가 오자 가족은 아버지의 회사 건물인 프린센흐라흐트 263번지 뒤편 공간으로 옮겨 숨어 지냈다. 이후 네 사람이 더 합류해 모두 여덟 명이 함께 생활했다.\n\n안네는 은신 생활의 일상, 함께 지낸 사람들과의 관계, 바깥 상황에 대한 생각과 글쓰기에 대한 계획을 이어서 적었다. 라디오 방송에서 전후에 전시 기록을 모을 것이라는 이야기를 듣고, 자신의 일기를 책으로 낼 것을 염두에 두고 원고를 다시 고쳐 쓰기도 했다.\n\n1944년 8월 4일 은신처가 발각되어 여덟 명 모두 체포되었고 수용소로 이송되었다. 안네와 마르고트는 1945년 초 베르겐벨젠에서 사망했으며 정확한 날짜는 확인되지 않았다. 유일한 생존자인 오토 프랑크는 보관되어 있던 원고를 정리해 1947년 네덜란드에서 출간했다. 은신처 건물은 현재 안네 프랑크 하우스로 공개되어 있다.", "en": "The Frank family moved from Frankfurt in Germany to Amsterdam in the Netherlands during the 1930s. After the German occupation of the Netherlands in 1940, restrictions on Jewish residents were tightened in stages.\n\nAnne began writing in a notebook received for her thirteenth birthday on 12 June 1942. When her sister Margot received a call-up notice in early July, the family moved into the rear annexe of the company premises at Prinsengracht 263 and went into hiding. Four more people joined them, making eight in all.\n\nAnne recorded daily life in hiding, her relations with the others, her thoughts about events outside and her plans for writing. After hearing a radio broadcast about collecting wartime records once the war ended, she revised her manuscript with publication in mind.\n\nThe hiding place was discovered on 4 August 1944; all eight were arrested and deported to camps. Anne and Margot died at Bergen-Belsen in early 1945, and the exact dates have not been established. Otto Frank, the only survivor of the group, edited the surviving papers and published them in the Netherlands in 1947. The building now houses the Anne Frank House museum.", "ja": "フランク一家はドイツのフランクフルトに住んでいたが、1930年代にオランダのアムステルダムへ移った。1940年にドイツがオランダを占領した後、ユダヤ人に対する制約は段階的に強化された。\n\nアンネは1942年6月12日、13歳の誕生日の贈り物として受け取ったノートに記録を始めた。7月初めに姉マルゴットへ召喚通知が届くと、一家は父の会社の建物であるプリンセンフラハト263番地の裏手の空間へ移り隠れて暮らした。のちに4人が加わり、合わせて8人が共に生活した。\n\nアンネは隠れ家での日常、共に暮らす人々との関係、外の状況についての考え、そして書くことへの計画を書き続けた。戦後に戦時の記録を集めるというラジオ放送を聞き、自分の日記を本にすることを念頭に原稿を書き直しもした。\n\n1944年8月4日に隠れ家が発見され、8人全員が逮捕されて収容所へ移送された。アンネとマルゴットは1945年初めにベルゲン・ベルゼンで死亡し、正確な日付は確認されていない。唯一の生存者であったオットー・フランクは保管されていた原稿を整理し、1947年にオランダで刊行した。隠れ家の建物は現在アンネ・フランクの家として公開されている。"}'::jsonb,
 date '1942-06-12',
 array['안네프랑크','일기','암스테르담','제2차세계대전','홀로코스트']::text[],
 'Anne Frank House, Amsterdam (museum and research documentation) / Anne Frank, Het Achterhuis (Contact, 1947); The Diary of Anne Frank: The Revised Critical Edition (NIOD Institute for War, Holocaust and Genocide Studies)',
 3)

) as d(planet_id, category_id, subcategory_id, title, summary, content,
       event_date, tags, source, level)
where not exists (select 1 from public.records
                   where is_seed and title ->> 'ko' = '베토벤 교향곡 제9번 초연');

-- [화성 4 / 타이탄 2 / 케플러-442b 1 / 프록시마 센타우리 b 1] --------
--  ※ 5.5 의 소재 범위 제한을 지켜, 실제 미션과 관측 사실만 기록합니다.
insert into public.records
  (planet_id, category_id, subcategory_id, title, summary, content,
   event_date, tags, source, level, is_seed, author_id)
select d.planet_id, d.category_id, d.subcategory_id, d.title, d.summary, d.content,
       d.event_date, d.tags, d.source, d.level, true,
       (select id from public.profiles where keeper_code = 'KEEPER-000')
from (values

-- 23. 바이킹 1호
('TERRA-002','TECH-004','MISSION',
 '{"ko":"바이킹 1호 착륙선의 화성 표면 도달","en":"Viking 1 Lands on the Surface of Mars","ja":"バイキング1号着陸機の火星表面到達"}'::jsonb,
 '{"ko":"1976년 7월 20일 NASA의 바이킹 1호 착륙선이 화성 크리세 플라니티아에 착륙했다. 화성 표면에서 장기간 임무를 수행한 최초의 착륙선으로, 영상 촬영과 기상 관측, 생물학 실험을 수행했다.","en":"The NASA Viking 1 lander touched down on Chryse Planitia on Mars on 20 July 1976. It was the first lander to operate on the Martian surface for an extended period, returning images, meteorological data and the results of biology experiments.","ja":"1976年7月20日、NASAのバイキング1号着陸機が火星のクリュセ平原に着陸した。火星表面で長期間の任務を遂行した最初の着陸機であり、画像撮影、気象観測、生物学実験を行った。"}'::jsonb,
 '{"ko": "바이킹 계획은 궤도선과 착륙선을 한 쌍으로 구성해 두 기를 화성에 보내는 사업이었다. 바이킹 1호는 1975년 8월 20일 발사되어 이듬해 화성 궤도에 진입했고, 궤도선이 촬영한 영상으로 착륙 후보지가 재검토되었다.\n\n1976년 7월 20일 착륙선이 궤도선에서 분리되어 크리세 플라니티아에 착륙했다. 착륙선은 착륙 직후부터 표면 영상을 전송했으며, 붉은 색조의 암석 평원과 하늘의 밝기가 기록되었다.\n\n착륙선에는 세 종류의 생물학 실험 장치가 실려 있었다. 실험 결과 가운데 일부는 대사 활동을 시사하는 신호를 보였으나, 함께 수행된 기체 크로마토그래프 질량분석기에서 유기물이 검출되지 않아 화학적 반응으로 해석되었다. 이 결과는 이후에도 논의의 대상이 되었다.\n\n착륙선은 기상 관측과 토양 성분 분석, 지진계 운용을 이어갔고 예정된 임무 기간을 크게 넘겨 작동했다. 교신은 1982년 11월에 종료되었다. 바이킹이 수집한 대기 조성과 표면 환경 자료는 이후 화성 탐사 계획의 기준 자료가 되었다.", "en": "The Viking programme sent two spacecraft to Mars, each pairing an orbiter with a lander. Viking 1 launched on 20 August 1975 and entered Mars orbit the following year, and images from the orbiter were used to reassess the candidate landing sites.\n\nOn 20 July 1976 the lander separated from the orbiter and set down on Chryse Planitia. It began transmitting surface images immediately after landing, recording a rock-strewn plain with a reddish cast and the brightness of the sky.\n\nThe lander carried three biology experiments. Some results showed signals suggestive of metabolic activity, but the gas chromatograph mass spectrometer detected no organic compounds, and the results were interpreted as chemical reactions. The findings have continued to be discussed since.\n\nThe lander went on to perform meteorological observation, soil composition analysis and seismometry, operating well beyond its planned mission duration. Communication ended in November 1982. The atmospheric and surface environment data returned by Viking became reference material for later Mars missions.", "ja": "バイキング計画は周回機と着陸機を一組とし、2機を火星へ送る事業であった。バイキング1号は1975年8月20日に打ち上げられ、翌年火星周回軌道に入り、周回機が撮影した画像により着陸候補地が再検討された。\n\n1976年7月20日、着陸機が周回機から分離してクリュセ平原に着陸した。着陸機は着陸直後から表面画像を送信し、赤みを帯びた岩の平原と空の明るさが記録された。\n\n着陸機には3種類の生物学実験装置が搭載されていた。実験結果の一部は代謝活動を示唆する信号を示したが、併せて行われたガスクロマトグラフ質量分析計で有機物が検出されなかったため、化学的な反応と解釈された。この結果はその後も議論の対象となっている。\n\n着陸機は気象観測、土壌成分の分析、地震計の運用を続け、予定された運用期間を大きく超えて動作した。交信は1982年11月に終了した。バイキングが収集した大気組成と表面環境の資料は、その後の火星探査計画の基準資料となった。"}'::jsonb,
 date '1976-07-20',
 array['바이킹','화성','착륙선','NASA','크리세플라니티아']::text[],
 'NASA, Viking Mission to Mars (NASA SP-441) / NASA Space Science Data Coordinated Archive, Viking 1 Lander (1975-075C)',
 1),

-- 24. 큐리오시티
('TERRA-002','TECH-004','MISSION',
 '{"ko":"큐리오시티 로버의 게일 크레이터 착륙","en":"Curiosity Lands in Gale Crater","ja":"キュリオシティ・ローバーのゲール・クレーター着陸"}'::jsonb,
 '{"ko":"2012년 8월 6일 NASA의 화성과학실험실 큐리오시티 로버가 게일 크레이터에 착륙했다. 스카이 크레인 방식으로 하강했으며, 이후 이 지역이 과거 호수 환경이었음을 보여주는 퇴적층을 조사했다.","en":"The NASA Mars Science Laboratory rover Curiosity landed in Gale Crater on 6 August 2012. It was lowered by a sky crane, and went on to examine sedimentary layers indicating that the area had once held a lake environment.","ja":"2012年8月6日、NASAの火星科学実験室キュリオシティ・ローバーがゲール・クレーターに着陸した。スカイクレーン方式で降下し、その後この地域がかつて湖の環境であったことを示す堆積層を調査した。"}'::jsonb,
 '{"ko": "화성과학실험실은 이전 로버보다 크고 무거운 차량을 안전하게 내려놓기 위해 새로운 착륙 방식을 채택했다. 하강 단계에서 역추진 장치를 갖춘 비행체가 공중에 정지한 뒤 케이블로 로버를 지면까지 내리고, 분리 후 멀리 이동해 추락하는 스카이 크레인 방식이다.\n\n큐리오시티는 2011년 11월 26일 발사되어 2012년 8월 6일 협정세계시 05시 17분경 게일 크레이터에 착륙했다. 전원으로는 방사성 동위원소 열전 발전기를 사용해 계절과 먼지의 영향을 덜 받도록 설계되었다.\n\n로버는 착륙 지점 인근 옐로나이프 베이에서 이암을 시추해 분석했고, 점토 광물과 황산염, 중성에 가까운 산성도 등 과거에 물이 오래 머문 환경을 시사하는 조건을 확인했다. 이 결과는 2014년 학술지에 정리되어 발표되었다.\n\n이후 큐리오시티는 크레이터 중앙의 아이올리스 몬스 경사면을 오르며 지층을 따라 조사를 이어갔고, 시료에서 유기 분자를 검출하고 대기 중 메탄 농도의 변동을 기록했다. 로버는 착륙 이후 장기간 운용되고 있다.", "en": "The Mars Science Laboratory adopted a new landing method to place a rover larger and heavier than its predecessors safely on the surface. In the sky crane approach a rocket-powered descent stage hovers, lowers the rover on cables to the ground, then separates and flies away to crash at a distance.\n\nCuriosity launched on 26 November 2011 and landed in Gale Crater at about 05:17 UTC on 6 August 2012. It draws power from a radioisotope thermoelectric generator, so that operation depends less on season and dust.\n\nThe rover drilled and analysed mudstone at Yellowknife Bay near the landing site, identifying clay minerals, sulphates and near-neutral acidity, conditions indicating an environment where water had persisted. These results were published in a scientific journal in 2014.\n\nCuriosity has since climbed the slopes of Aeolis Mons at the centre of the crater, surveying successive strata, detecting organic molecules in samples and recording variation in atmospheric methane. The rover has continued operating for many years since landing.", "ja": "火星科学実験室は、従来のローバーより大きく重い車両を安全に降ろすため新しい着陸方式を採用した。降下段階で逆推進装置を備えた飛行体が空中で静止し、ケーブルでローバーを地表まで降ろし、分離後に遠くへ飛び去って墜落するスカイクレーン方式である。\n\nキュリオシティは2011年11月26日に打ち上げられ、2012年8月6日の協定世界時5時17分ごろゲール・クレーターに着陸した。電源には放射性同位体熱電発電機を用い、季節や塵の影響を受けにくいよう設計された。\n\nローバーは着陸地点近くのイエローナイフ湾で泥岩を掘削して分析し、粘土鉱物、硫酸塩、中性に近い酸性度など、かつて水が長く留まった環境を示唆する条件を確認した。この結果は2014年に学術誌にまとめて発表された。\n\nその後キュリオシティはクレーター中央のアイオリス山の斜面を登りながら地層に沿った調査を続け、試料から有機分子を検出し、大気中メタン濃度の変動を記録した。ローバーは着陸以来、長期にわたり運用されている。"}'::jsonb,
 date '2012-08-06',
 array['큐리오시티','화성','로버','게일크레이터','스카이크레인']::text[],
 'NASA Jet Propulsion Laboratory, Mars Science Laboratory mission documentation / J. P. Grotzinger et al., "A Habitable Fluvio-Lacustrine Environment at Yellowknife Bay, Gale Crater, Mars", Science 343, 1242777 (2014)',
 1),

-- 25. 인저뉴어티
('TERRA-002','TECH-004','MISSION',
 '{"ko":"인저뉴어티 헬리콥터의 첫 화성 비행","en":"The First Powered Flight of Ingenuity on Mars","ja":"インジェニュイティ・ヘリコプターの初の火星飛行"}'::jsonb,
 '{"ko":"2021년 4월 19일 NASA의 소형 헬리콥터 인저뉴어티가 화성 제제로 크레이터에서 약 3미터 높이로 떠올라 약 39초 동안 비행했다. 지구 밖 천체에서 이루어진 최초의 동력 제어 비행으로 기록되었다.","en":"On 19 April 2021 the NASA helicopter Ingenuity rose to about three metres and flew for roughly 39 seconds in Jezero Crater on Mars. It is recorded as the first powered, controlled flight on a body other than Earth.","ja":"2021年4月19日、NASAの小型ヘリコプター、インジェニュイティが火星のジェゼロ・クレーターで約3メートルの高さまで上昇し、およそ39秒間飛行した。地球以外の天体で行われた最初の動力制御飛行として記録された。"}'::jsonb,
 '{"ko": "화성 대기는 지구 해수면 기압의 1퍼센트에 못 미칠 만큼 희박해, 회전익으로 양력을 얻기가 매우 어렵다. 인저뉴어티는 이 조건에서 비행이 가능한지 확인하기 위한 기술 시연 기체로 설계되었으며, 가벼운 기체에 고속 회전하는 두 쌍의 반전 로터와 태양전지를 갖추었다.\n\n인저뉴어티는 퍼서비어런스 로버의 하부에 실려 2021년 2월 18일 제제로 크레이터에 도착했다. 로버가 안전한 평지에 기체를 내려놓은 뒤 시험 준비가 진행되었다.\n\n2021년 4월 19일 첫 비행에서 기체는 약 3미터 높이까지 상승해 제자리 비행을 하고 다시 착륙했다. 비행 시간은 약 39초였으며, 퍼서비어런스가 이 장면을 촬영했다.\n\n기술 시연으로 계획된 다섯 차례의 비행을 마친 뒤 임무는 로버의 정찰을 돕는 운용 단계로 연장되었다. 2024년 1월 착륙 과정에서 로터 날개가 손상되어 비행 임무가 종료되었으며, 총 비행 횟수는 72회로 기록되었다.", "en": "The Martian atmosphere is thin, under one percent of sea-level pressure on Earth, which makes generating lift with rotors very difficult. Ingenuity was designed as a technology demonstration to test whether flight was possible in those conditions, with a light airframe, two pairs of fast counter-rotating rotors and a solar panel.\n\nIngenuity travelled to Jezero Crater attached beneath the Perseverance rover, arriving on 18 February 2021. The rover placed it on level ground and preparations for the test followed.\n\nOn the first flight, on 19 April 2021, the aircraft rose to about three metres, hovered and landed again. The flight lasted roughly 39 seconds and was recorded by Perseverance.\n\nAfter completing the five flights planned for the demonstration, the mission was extended into an operational phase supporting rover scouting. Rotor blade damage during a landing in January 2024 ended flight operations, with a recorded total of 72 flights.", "ja": "火星の大気は地球の海面気圧の1パーセントに満たないほど希薄で、回転翼で揚力を得ることが非常に難しい。インジェニュイティはこの条件で飛行が可能かを確認する技術実証機として設計され、軽量の機体に高速で回る二対の反転ローターと太陽電池を備えた。\n\nインジェニュイティはパーサヴィアランス・ローバーの下部に搭載されて2021年2月18日にジェゼロ・クレーターへ到着した。ローバーが安全な平地に機体を降ろしたのち、試験の準備が進められた。\n\n2021年4月19日の初飛行で、機体はおよそ3メートルの高さまで上昇してホバリングし、再び着陸した。飛行時間はおよそ39秒で、その様子はパーサヴィアランスが撮影した。\n\n技術実証として計画された5回の飛行を終えた後、任務はローバーの偵察を支援する運用段階へ延長された。2024年1月、着陸の過程でローターブレードが損傷して飛行任務は終了し、飛行回数は合計72回と記録された。"}'::jsonb,
 date '2021-04-19',
 array['인저뉴어티','화성','헬리콥터','제제로크레이터','비행']::text[],
 'NASA Jet Propulsion Laboratory, Ingenuity Mars Helicopter mission documentation / J. Balaram et al., "Mars Helicopter Technology Demonstrator", AIAA SciTech 2018-0023',
 2),

-- 26. 인사이트 화성 지진
('TERRA-002','NAT-001','SEISMIC',
 '{"ko":"인사이트 착륙선의 첫 화성 지진 관측","en":"InSight Records the First Marsquake","ja":"インサイト着陸機による初の火星地震観測"}'::jsonb,
 '{"ko":"2019년 4월 6일 NASA의 인사이트 착륙선이 화성 표면에 설치한 지진계로 처음으로 화성 내부에서 기원한 것으로 판단되는 진동 신호를 기록했다. 이후 임무 기간 동안 다수의 지진이 관측되어 행성 내부 구조 연구에 사용되었다.","en":"On 6 April 2019 the seismometer deployed by the NASA InSight lander recorded the first signal judged to originate inside Mars. Many further quakes were detected over the mission and were used to study the interior structure of the planet.","ja":"2019年4月6日、NASAのインサイト着陸機が火星表面に設置した地震計により、火星内部を起源とすると判断される振動信号を初めて記録した。その後の任務期間中に多数の地震が観測され、惑星内部構造の研究に用いられた。"}'::jsonb,
 '{"ko": "인사이트는 화성의 표면 활동보다 내부 구조를 조사하기 위해 설계된 정지형 착륙선이다. 2018년 11월 26일 엘리시움 플라니티아에 착륙했으며, 주요 장비로 초고감도 지진계와 열류 측정 장치, 전파 추적 실험 장비를 실었다.\n\n지진계는 로봇 팔로 표면에 내려놓은 뒤 바람과 온도 변화의 영향을 줄이기 위한 덮개로 덮였다. 이러한 배치는 지구 밖 행성에서 이루어진 첫 본격적인 지진 관측 설비였다.\n\n2019년 4월 6일 기록된 신호는 대기 잡음이나 착륙선 자체의 진동이 아니라 행성 내부에서 온 것으로 판단되었다. 이후 수백 건의 지진 신호가 축적되었고, 2022년 5월 4일에는 관측 기간 중 가장 큰 규모로 보고된 사건이 기록되었다.\n\n지진파의 도달 시각과 파형 분석을 통해 화성의 지각 두께, 맨틀 구조, 핵의 크기에 대한 추정이 제시되었다. 착륙선은 태양전지에 쌓인 먼지로 전력이 줄어들면서 2022년 12월 임무를 마쳤다.", "en": "InSight was a stationary lander designed to investigate the interior of Mars rather than surface activity. It landed on Elysium Planitia on 26 November 2018 carrying a very sensitive seismometer, a heat flow probe and a radio science experiment as its main instruments.\n\nThe seismometer was placed on the surface by a robotic arm and covered by a shield to reduce the effects of wind and temperature change. This was the first substantial seismic installation on another planet.\n\nThe signal recorded on 6 April 2019 was judged to come from within the planet rather than from atmospheric noise or the lander itself. Hundreds of further seismic events were recorded, and an event reported as the largest of the mission was registered on 4 May 2022.\n\nAnalysis of arrival times and waveforms produced estimates of crustal thickness, mantle structure and core size for Mars. The lander ended its mission in December 2022 as dust accumulating on its solar panels reduced available power.", "ja": "インサイトは火星の表面活動よりも内部構造を調べるために設計された静止型の着陸機である。2018年11月26日にエリシウム平原へ着陸し、主要機器として超高感度の地震計、熱流量測定装置、電波追跡実験装置を搭載していた。\n\n地震計はロボットアームで表面へ降ろされたのち、風と温度変化の影響を抑えるための覆いで覆われた。この設置は、地球以外の惑星で行われた最初の本格的な地震観測設備であった。\n\n2019年4月6日に記録された信号は、大気の雑音や着陸機自身の振動ではなく惑星内部に由来すると判断された。以後、数百件の地震信号が蓄積され、2022年5月4日には観測期間中で最大と報告される事象が記録された。\n\n地震波の到達時刻と波形の解析を通じて、火星の地殻の厚さ、マントルの構造、核の大きさについての推定が示された。着陸機は太陽電池に積もった塵で電力が減り、2022年12月に任務を終えた。"}'::jsonb,
 date '2019-04-06',
 array['인사이트','화성지진','지진계','내부구조','NASA']::text[],
 'NASA Jet Propulsion Laboratory, InSight Mars Lander mission documentation / W. B. Banerdt et al., "Initial results from the InSight mission on Mars", Nature Geoscience 13, 183-189 (2020)',
 2),

-- 27. 하위헌스 타이탄 착륙
('MOON-TITAN','TECH-004','MISSION',
 '{"ko":"하위헌스 탐사선의 타이탄 착륙","en":"The Huygens Probe Lands on Titan","ja":"ホイヘンス探査機のタイタン着陸"}'::jsonb,
 '{"ko":"2005년 1월 14일 유럽우주국의 하위헌스 탐사선이 토성의 위성 타이탄 대기로 진입해 낙하산으로 강하한 뒤 표면에 착륙했다. 지구에서 가장 먼 거리에서 이루어진 착륙으로 기록되었다.","en":"On 14 January 2005 the European Space Agency probe Huygens entered the atmosphere of Titan, descended by parachute and landed on the surface. It stands as the most distant landing from Earth achieved to date.","ja":"2005年1月14日、欧州宇宙機関のホイヘンス探査機が土星の衛星タイタンの大気に突入し、パラシュートで降下した後、表面に着陸した。地球から最も遠い距離で行われた着陸として記録されている。"}'::jsonb,
 '{"ko": "카시니-하위헌스는 NASA와 유럽우주국, 이탈리아 우주국이 함께 수행한 토성 탐사 사업이다. 1997년 10월 발사된 카시니 궤도선은 2004년 7월 토성 궤도에 진입했고, 여기에 실려 있던 하위헌스 탐사선은 2004년 12월 25일 분리되었다.\n\n타이탄은 두꺼운 질소 대기를 가진 위성으로, 가시광선 관측만으로는 표면을 확인하기 어려웠다. 하위헌스는 이 대기를 통과하며 조성과 바람, 온도를 직접 측정하고 표면 영상을 얻는 것을 목표로 했다.\n\n2005년 1월 14일 탐사선은 대기에 진입해 여러 단계의 낙하산으로 감속하며 약 2시간 27분 동안 하강했다. 하강 중 촬영된 영상에는 물길처럼 갈라진 지형과 어두운 평원이 담겼다.\n\n착륙 후에도 탐사선은 카시니가 지평선 아래로 내려가기 전까지 자료를 계속 송신했으며, 표면 온도와 성분, 착륙 지점의 물성에 관한 측정값이 확보되었다. 이 자료는 타이탄 표면에 액체 탄화수소가 관여하는 순환이 존재한다는 이후 해석의 근거가 되었다.", "en": "Cassini-Huygens was a mission to Saturn conducted jointly by NASA, the European Space Agency and the Italian Space Agency. The Cassini orbiter launched in October 1997 and entered Saturn orbit in July 2004, and the Huygens probe it carried separated on 25 December 2004.\n\nTitan has a thick nitrogen atmosphere, and its surface could not be seen by observation in visible light alone. Huygens was intended to measure composition, wind and temperature directly during descent through that atmosphere and to obtain surface images.\n\nOn 14 January 2005 the probe entered the atmosphere and descended for about two hours and 27 minutes, slowed by a sequence of parachutes. Images taken during descent showed branching channel-like features and dark plains.\n\nThe probe continued transmitting after landing until Cassini passed below the horizon, returning measurements of surface temperature, composition and the mechanical properties of the landing site. These data supported later interpretations that a cycle involving liquid hydrocarbons operates on the surface of Titan.", "ja": "カッシーニ・ホイヘンスはNASA、欧州宇宙機関、イタリア宇宙機関が共同で実施した土星探査事業である。1997年10月に打ち上げられたカッシーニ周回機は2004年7月に土星周回軌道へ入り、搭載されていたホイヘンス探査機は2004年12月25日に分離された。\n\nタイタンは厚い窒素大気を持つ衛星で、可視光の観測だけでは表面を確認しにくかった。ホイヘンスはこの大気を通過しながら組成、風、温度を直接測定し、表面画像を得ることを目標とした。\n\n2005年1月14日、探査機は大気へ突入し、複数段のパラシュートで減速しながらおよそ2時間27分にわたって降下した。降下中に撮影された画像には、水路のように枝分かれした地形と暗い平原が写っていた。\n\n着陸後も探査機はカッシーニが地平線の下へ沈むまで資料を送り続け、表面温度、成分、着陸地点の物性に関する測定値が得られた。この資料は、タイタンの表面に液体炭化水素が関与する循環が存在するという後の解釈の根拠となった。"}'::jsonb,
 date '2005-01-14',
 array['하위헌스','타이탄','카시니','ESA','착륙']::text[],
 'European Space Agency, Cassini-Huygens mission documentation / J.-P. Lebreton et al., "An overview of the descent and landing of the Huygens probe on Titan", Nature 438, 758-764 (2005)',
 2),

-- 28. 타이탄 호수
('MOON-TITAN','NAT-001','HYDRO',
 '{"ko":"타이탄 극지 액체 호수의 확인","en":"Confirmation of Polar Lakes on Titan","ja":"タイタン極域における液体湖の確認"}'::jsonb,
 '{"ko":"2006년 7월 카시니 궤도선의 레이더 관측으로 타이탄 북극 지역에서 호수 형태의 지형이 다수 확인되었다. 관측 결과는 이들 지형이 액체 메탄과 에탄으로 채워져 있음을 시사했으며, 2007년 학술지에 보고되었다.","en":"Radar observations by the Cassini orbiter in July 2006 revealed numerous lake-like features in the north polar region of Titan. The results indicated that these features hold liquid methane and ethane, and were reported in a scientific journal in 2007.","ja":"2006年7月、カッシーニ探査機のレーダー観測により、タイタンの北極域で湖状の地形が多数確認された。観測結果はこれらの地形が液体メタンとエタンで満たされていることを示唆し、2007年に学術誌で報告された。"}'::jsonb,
 '{"ko": "타이탄은 표면 온도가 매우 낮아 물은 얼음 상태로 존재하지만, 메탄과 에탄은 액체로 있을 수 있는 조건이다. 이 때문에 표면에 액체 탄화수소가 고여 있을 가능성이 오래전부터 제기되었으나 두꺼운 연무 때문에 직접 확인이 어려웠다.\n\n카시니 궤도선은 구름과 연무를 통과하는 합성개구 레이더를 이용해 표면 지형을 관측했다. 2006년 7월 22일 근접 통과에서 북극 지역을 촬영한 자료에는 주변보다 레이더 반사가 뚜렷하게 약한 어두운 영역이 여럿 나타났다.\n\n반사가 약하다는 것은 표면이 매우 매끄럽고 흡수성이 크다는 뜻으로, 액체가 고여 있는 상태와 부합한다. 관측된 지형은 해안선처럼 보이는 경계와 유입 수로에 해당하는 구조를 함께 보였다. 연구진은 이 결과를 2007년 네이처에 보고했다.\n\n이후 추가 관측을 통해 크라켄 마레와 리게이아 마레 등 대형 지형에 이름이 부여되었고, 계절에 따른 액체 수위 변화와 강수 흔적도 조사되었다. 타이탄은 지구 외에 표면에 안정적인 액체 저장고가 확인된 천체로 다루어진다.", "en": "Surface temperatures on Titan are low enough that water exists as ice, while methane and ethane can remain liquid. The possibility of standing liquid hydrocarbons on the surface had long been raised, but the thick haze made direct confirmation difficult.\n\nThe Cassini orbiter observed surface terrain with synthetic aperture radar, which penetrates cloud and haze. Data from a close pass on 22 July 2006 covering the north polar region showed several dark areas whose radar return was markedly weaker than their surroundings.\n\nA weak return implies a very smooth and absorbing surface, consistent with standing liquid. The features observed also showed boundaries resembling shorelines together with structures corresponding to inflow channels. The team reported these results in Nature in 2007.\n\nLater observations led to names being assigned to large features such as Kraken Mare and Ligeia Mare, and to studies of seasonal changes in liquid level and traces of precipitation. Titan is treated as the only body besides Earth with confirmed stable bodies of liquid on its surface.", "ja": "タイタンは表面温度が非常に低く水は氷として存在するが、メタンとエタンは液体でありうる条件にある。このため表面に液体炭化水素がたまっている可能性は古くから提起されていたが、厚い靄のため直接の確認は難しかった。\n\nカッシーニ周回機は雲と靄を透過する合成開口レーダーで表面地形を観測した。2006年7月22日の接近通過で北極域を撮影した資料には、周囲よりレーダーの反射が明らかに弱い暗い領域が複数現れた。\n\n反射が弱いことは表面が非常に滑らかで吸収性が高いことを意味し、液体がたまっている状態と符合する。観測された地形は海岸線のように見える境界と、流入水路にあたる構造を併せて示していた。研究陣はこの結果を2007年にネイチャーで報告した。\n\nその後の追加観測により、クラーケン海やリゲイア海などの大型地形に名称が与えられ、季節に伴う液面の変化や降水の痕跡も調査された。タイタンは、地球以外で表面に安定した液体の貯留が確認された天体として扱われている。"}'::jsonb,
 date '2006-07-22',
 array['타이탄','메탄호수','카시니','레이더','탄화수소']::text[],
 'E. R. Stofan et al., "The lakes of Titan", Nature 445, 61-64 (2007) / NASA Jet Propulsion Laboratory, Cassini-Huygens mission documentation',
 3),

-- 29. 케플러-442b
('EXOPLANET-442','EVENT-006','DISCOVERY',
 '{"ko":"케플러-442b의 확인","en":"The Validation of Kepler-442b","ja":"ケプラー442bの確認"}'::jsonb,
 '{"ko":"2015년 1월 케플러 우주망원경의 통과 관측 자료로 검증된 외계행성 가운데 하나로 발표되었다. 거문고자리 방향으로 약 1,200광년 거리의 K형 왜성을 약 112일 주기로 공전하며, 반지름은 지구의 약 1.3배로 산출되었다.","en":"Kepler-442b was announced in January 2015 as one of the planets validated from transit observations by the Kepler space telescope. It orbits a K-type dwarf about 1,200 light-years away toward Lyra with a period of about 112 days, and its radius is derived as roughly 1.3 times that of Earth.","ja":"2015年1月、ケプラー宇宙望遠鏡のトランジット観測データから検証された系外惑星の一つとして発表された。こと座方向へ約1,200光年の距離にあるK型矮星を約112日周期で公転し、半径は地球の約1.3倍と算出された。"}'::jsonb,
 '{"ko": "케플러 우주망원경은 2009년부터 백조자리와 거문고자리 방향의 특정 영역을 지속적으로 관측하며 항성의 밝기 변화를 측정했다. 행성이 항성 앞을 지나갈 때 나타나는 미세한 감광을 검출하는 통과법이 사용되었다.\n\n통과 신호는 항성 자체의 변광이나 배경 쌍성에 의한 오탐일 수 있으므로, 후보를 행성으로 확정하려면 별도의 검증 절차가 필요하다. 연구진은 통계적 검증 기법과 지상 망원경의 보조 관측을 결합해 다수의 소형 후보를 평가했다.\n\n2015년 1월 6일 미국천문학회 회의에서 이 방식으로 검증된 12개 소형 행성이 발표되었고, 케플러-442b도 그 가운데 포함되었다. 관련 논문은 같은 해 천체물리학 저널에 실렸다.\n\n산출된 값에 따르면 이 행성은 태양보다 어둡고 온도가 낮은 K형 왜성을 약 112.3일 주기로 공전하며, 받는 복사량은 지구가 받는 양보다 적다. 반지름은 지구의 약 1.34배로 추정된다. 질량은 직접 측정되지 않았으므로 조성과 표면 환경은 확인되지 않았으며, 이 기록은 관측으로 확인된 범위만을 다룬다.", "en": "From 2009 the Kepler space telescope continuously monitored a fixed field toward Cygnus and Lyra, measuring changes in stellar brightness. It used the transit method, detecting the slight dimming that occurs when a planet passes in front of its star.\n\nA transit signal can be a false positive caused by stellar variability or a background binary, so confirming a candidate as a planet requires separate validation. Researchers combined statistical validation techniques with supporting observations from ground-based telescopes to assess many small candidates.\n\nOn 6 January 2015 twelve small planets validated in this way were announced at a meeting of the American Astronomical Society, Kepler-442b among them. The associated paper appeared in an astrophysics journal later that year.\n\nThe derived values place the planet in a roughly 112.3 day orbit around a K-type dwarf cooler and fainter than the Sun, receiving less radiation than Earth does. Its radius is estimated at about 1.34 Earth radii. Its mass has not been measured directly, so composition and surface conditions are not established, and this record covers only what observation has confirmed.", "ja": "ケプラー宇宙望遠鏡は2009年から、はくちょう座とこと座の方向にある特定の領域を継続的に観測し、恒星の明るさの変化を測定した。惑星が恒星の前を通過するときに生じるわずかな減光を検出するトランジット法が用いられた。\n\nトランジットの信号は恒星自体の変光や背景の連星による誤検出でありうるため、候補を惑星として確定するには別途の検証手続きが必要である。研究陣は統計的な検証手法と地上望遠鏡の補助観測を組み合わせ、多数の小型候補を評価した。\n\n2015年1月6日、アメリカ天文学会の会合でこの方法により検証された12個の小型惑星が発表され、ケプラー442bもそのなかに含まれていた。関連論文は同年、天体物理学の学術誌に掲載された。\n\n算出された値によれば、この惑星は太陽より暗く低温のK型矮星をおよそ112.3日の周期で公転し、受ける放射量は地球が受ける量より少ない。半径は地球のおよそ1.34倍と推定される。質量は直接測定されていないため組成と表面環境は確認されておらず、この記録は観測で確認された範囲のみを扱う。"}'::jsonb,
 date '2015-01-06',
 array['케플러442b','외계행성','통과법','거문고자리','케플러망원경']::text[],
 'G. Torres et al., "Validation of 12 Small Kepler Transiting Planets in the Habitable Zone", The Astrophysical Journal 800, 99 (2015) / NASA Exoplanet Archive, Kepler-442 b entry',
 3),

-- 30. 프록시마 센타우리 b
('EXOPLANET-PCB','EVENT-006','DISCOVERY',
 '{"ko":"프록시마 센타우리 b의 발견","en":"The Detection of Proxima Centauri b","ja":"プロキシマ・ケンタウリbの発見"}'::jsonb,
 '{"ko":"2016년 8월 24일 네이처에 태양에서 가장 가까운 항성 프록시마 센타우리를 도는 행성 후보의 검출 결과가 발표되었다. 시선속도 관측으로 확인되었으며 공전 주기는 약 11.2일, 최소 질량은 지구의 약 1.3배로 산출되었다.","en":"On 24 August 2016 Nature published the detection of a planet candidate orbiting Proxima Centauri, the nearest star to the Sun. It was identified through radial velocity measurements, with an orbital period of about 11.2 days and a minimum mass of roughly 1.3 Earth masses.","ja":"2016年8月24日、ネイチャー誌に太陽から最も近い恒星プロキシマ・ケンタウリを回る惑星候補の検出結果が発表された。視線速度観測により確認され、公転周期は約11.2日、最小質量は地球の約1.3倍と算出された。"}'::jsonb,
 '{"ko": "프록시마 센타우리는 센타우루스자리 방향으로 약 4.24광년 거리에 있는 M형 적색왜성으로, 태양에 가장 가까운 항성이다. 어둡고 활동적인 별이어서 미세한 시선속도 변화를 검출하기가 까다로웠다.\n\n연구진은 2016년 전반기에 페일 레드 닷이라는 이름의 집중 관측 캠페인을 진행했다. 칠레 라 실라 천문대의 HARPS 분광기를 중심으로 매일 관측 자료를 확보했고, 과거에 축적된 관측 자료와 함께 분석했다.\n\n분석 결과 약 11.19일 주기의 시선속도 변동이 확인되었고, 이는 항성 주위를 도는 동반 천체의 존재로 해석되었다. 시선속도법은 궤도 경사각을 알 수 없으므로 질량은 최솟값으로 주어지며, 이 경우 지구 질량의 약 1.27배로 산출되었다.\n\n행성이 받는 항성 복사량은 액체 상태의 물이 존재할 수 있는 범위로 계산되었으나, 적색왜성 특유의 항성 플레어와 조석 고정 가능성 때문에 실제 환경은 확정되지 않았다. 통과 현상이 확인되지 않아 반지름과 대기 조성은 직접 측정되지 않았다.", "en": "Proxima Centauri is an M-type red dwarf about 4.24 light-years away toward Centaurus and is the nearest star to the Sun. It is faint and active, which made detecting small radial velocity changes difficult.\n\nResearchers ran an intensive observing campaign called Pale Red Dot during the first half of 2016. Daily measurements were obtained chiefly with the HARPS spectrograph at La Silla Observatory in Chile and analysed together with archival data.\n\nThe analysis identified a radial velocity variation with a period of about 11.19 days, interpreted as a companion body orbiting the star. Because the radial velocity method leaves the orbital inclination unknown, the mass is given as a minimum, here about 1.27 Earth masses.\n\nThe stellar radiation received by the planet was calculated to fall within the range where liquid water could exist, but the actual environment is not established, given the flares characteristic of red dwarfs and the likelihood of tidal locking. No transit has been observed, so radius and atmospheric composition have not been measured directly.", "ja": "プロキシマ・ケンタウリはケンタウルス座の方向へおよそ4.24光年の距離にあるM型赤色矮星で、太陽に最も近い恒星である。暗く活動的な星であるため、わずかな視線速度の変化を検出することは難しかった。\n\n研究陣は2016年前半にペイル・レッド・ドットという名の集中観測キャンペーンを実施した。チリのラ・シヤ天文台のHARPS分光器を中心に日々の観測資料を確保し、過去に蓄積された観測資料と併せて解析した。\n\n解析の結果、およそ11.19日周期の視線速度の変動が確認され、これは恒星の周りを回る伴天体の存在と解釈された。視線速度法は軌道傾斜角が分からないため質量は最小値として与えられ、この場合は地球質量のおよそ1.27倍と算出された。\n\n惑星が受ける恒星放射量は液体の水が存在しうる範囲と計算されたが、赤色矮星に特有の恒星フレアと潮汐固定の可能性のため実際の環境は確定していない。トランジットが確認されていないため、半径と大気組成は直接測定されていない。"}'::jsonb,
 date '2016-08-24',
 array['프록시마센타우리','외계행성','시선속도','HARPS','적색왜성']::text[],
 'G. Anglada-Escudé et al., "A terrestrial planet candidate in a temperate orbit around Proxima Centauri", Nature 536, 437-440 (2016) / European Southern Observatory, Pale Red Dot campaign documentation',
 4)

) as d(planet_id, category_id, subcategory_id, title, summary, content,
       event_date, tags, source, level)
where not exists (select 1 from public.records
                   where is_seed and title ->> 'ko' = '바이킹 1호 착륙선의 화성 표면 도달');

-- ------------------------------------------------------------
-- 5. 확인용 집계 (실행 결과를 눈으로 확인하세요)
-- ------------------------------------------------------------
--   select planet_id, count(*) from public.records where is_seed group by planet_id order by 1;
--   select * from public.v_archive_stats;

-- END OF seed.sql
