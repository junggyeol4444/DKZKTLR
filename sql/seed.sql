-- Taxonomy and factual starter records. Idempotent where practical.
insert into public.domains(id,name,description,icon,sort_order) values
('HISTORY','{"ko":"역사","en":"History","ja":"歴史"}','{"ko":"사건과 사회의 변화","en":"Events and social change","ja":"出来事と社会の変化"}','⌛',1),
('SCIENCE','{"ko":"과학","en":"Science","ja":"科学"}','{"ko":"관찰과 실험으로 이해하는 세계","en":"The world understood through observation","ja":"観察と実験で理解する世界"}','◉',2),
('TECHNOLOGY','{"ko":"기술","en":"Technology","ja":"技術"}','{"ko":"도구, 발명, 공학과 시스템","en":"Tools, inventions, engineering and systems","ja":"道具、発明、工学とシステム"}','⌘',3),
('CULTURE','{"ko":"문화와 예술","en":"Culture & arts","ja":"文化と芸術"}','{"ko":"인류가 만들고 공유한 표현","en":"Expressions made and shared by people","ja":"人類が創造し共有した表現"}','✦',4),
('PEOPLE','{"ko":"인물과 공동체","en":"People & communities","ja":"人物と共同体"}','{"ko":"삶, 관계, 조직과 사회","en":"Lives, relationships and societies","ja":"人生、関係、組織と社会"}','♙',5),
('PLACES','{"ko":"장소와 환경","en":"Places & environment","ja":"場所と環境"}','{"ko":"지구와 우주의 장소","en":"Places on Earth and beyond","ja":"地球と宇宙の場所"}','⌖',6),
('IDEAS','{"ko":"사상과 지식","en":"Ideas & knowledge","ja":"思想と知識"}','{"ko":"개념, 철학, 언어와 배움","en":"Concepts, philosophy, language and learning","ja":"概念、哲学、言語と学び"}','∞',7),
('LIFE','{"ko":"삶의 기록","en":"Lived experience","ja":"生活の記録"}','{"ko":"개인의 경험과 일상의 증언","en":"Personal experience and everyday testimony","ja":"個人の経験と日常の証言"}','☷',8)
on conflict(id) do update set name=excluded.name,description=excluded.description,icon=excluded.icon,sort_order=excluded.sort_order;

insert into public.categories(id,domain_id,name,description,sort_order) values
('ANCIENT','HISTORY','{"ko":"고대","en":"Ancient history","ja":"古代"}','{"ko":"문자 기록 초기부터의 역사","en":"History from the earliest writing","ja":"初期の文字記録からの歴史"}',1),
('MODERN','HISTORY','{"ko":"근현대","en":"Modern history","ja":"近現代"}','{"ko":"산업화 이후의 세계","en":"The world since industrialization","ja":"産業化以後の世界"}',2),
('SPACE','SCIENCE','{"ko":"우주과학","en":"Space science","ja":"宇宙科学"}','{"ko":"천체와 우주 탐사","en":"Celestial bodies and exploration","ja":"天体と宇宙探査"}',1),
('LIFE-SCI','SCIENCE','{"ko":"생명과학","en":"Life sciences","ja":"生命科学"}','{"ko":"생명과 생태계","en":"Life and ecosystems","ja":"生命と生態系"}',2),
('PHYSICS','SCIENCE','{"ko":"물리와 화학","en":"Physical sciences","ja":"物理・化学"}','{"ko":"물질과 에너지","en":"Matter and energy","ja":"物質とエネルギー"}',3),
('COMPUTING','TECHNOLOGY','{"ko":"컴퓨팅","en":"Computing","ja":"コンピューティング"}','{"ko":"계산, 소프트웨어와 네트워크","en":"Computation, software and networks","ja":"計算、ソフトウェア、ネットワーク"}',1),
('ENGINEERING','TECHNOLOGY','{"ko":"공학과 발명","en":"Engineering","ja":"工学と発明"}','{"ko":"인간이 만든 도구와 구조","en":"Human-made tools and structures","ja":"人が作った道具と構造"}',2),
('VISUAL-ART','CULTURE','{"ko":"시각예술","en":"Visual art","ja":"視覚芸術"}','{"ko":"회화, 조각, 사진과 디자인","en":"Painting, sculpture, photography and design","ja":"絵画、彫刻、写真、デザイン"}',1),
('MUSIC','CULTURE','{"ko":"음악","en":"Music","ja":"音楽"}','{"ko":"소리로 기록된 문화","en":"Culture recorded in sound","ja":"音で記録された文化"}',2),
('BIOGRAPHY','PEOPLE','{"ko":"생애","en":"Biography","ja":"生涯"}','{"ko":"한 사람의 삶과 영향","en":"Individual lives and influence","ja":"個人の人生と影響"}',1),
('MOVEMENTS','PEOPLE','{"ko":"공동체와 운동","en":"Communities & movements","ja":"共同体と運動"}','{"ko":"함께 만든 사회 변화","en":"Social change made together","ja":"共に作った社会変化"}',2),
('EARTH','PLACES','{"ko":"지구","en":"Earth","ja":"地球"}','{"ko":"자연 및 인문 지리","en":"Physical and human geography","ja":"自然・人文地理"}',1),
('BEYOND','PLACES','{"ko":"지구 너머","en":"Beyond Earth","ja":"地球の外"}','{"ko":"태양계와 관측된 외계 세계","en":"The Solar System and observed worlds","ja":"太陽系と観測された世界"}',2),
('PHILOSOPHY','IDEAS','{"ko":"철학과 윤리","en":"Philosophy & ethics","ja":"哲学と倫理"}','{"ko":"앎과 삶에 대한 질문","en":"Questions about knowledge and life","ja":"知と生への問い"}',1),
('LANGUAGE','IDEAS','{"ko":"언어와 소통","en":"Language","ja":"言語とコミュニケーション"}','{"ko":"의미를 만들고 나누는 방식","en":"Ways we make and share meaning","ja":"意味を作り共有する方法"}',2),
('MEMOIR','LIFE','{"ko":"회고와 증언","en":"Memoir & testimony","ja":"回想と証言"}','{"ko":"출처와 맥락을 갖춘 개인의 기록","en":"Personal records with context and provenance","ja":"出典と文脈のある個人記録"}',1)
on conflict(id) do update set domain_id=excluded.domain_id,name=excluded.name,description=excluded.description,sort_order=excluded.sort_order;

-- Create the non-login seed author. The auth row keeps the profile FK valid and can be removed with seed data.
do $$
declare keeper uuid := '00000000-0000-0000-0000-000000000000';
begin
 if not exists(select 1 from auth.users where id=keeper) then
  insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values('00000000-0000-0000-0000-000000000000',keeper,'authenticated','authenticated','system@invalid.local',crypt(gen_random_uuid()::text,gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{"display_name":"Archive System","lang":"ko"}',now(),now());
 end if;
 update public.profiles set keeper_code='KEEPER-000',display_name='Archive System',level=5 where id=keeper;
end $$;

-- Concise seed entries are factual index cards. Editors can expand them with sourced detail.
insert into public.records(record_code,domain_id,category_id,title,summary,content,event_date,tags,source,level,author_id,is_seed) values
('ARC-HISTORY-000001','HISTORY','ANCIENT','{"ko":"로제타석 발견","en":"Discovery of the Rosetta Stone","ja":"ロゼッタ・ストーンの発見"}','{"ko":"1799년 로제타에서 발견된 비문은 이집트 상형문자 해독의 핵심 자료가 되었다."}','{"ko":"로제타석에는 같은 법령이 여러 문자로 새겨져 있다. 이 자료는 고대 이집트 문자를 읽는 연구의 전환점이 되었다."}','1799-07-15',array['이집트','문자','고고학'],'https://www.britishmuseum.org/collection/object/Y_EA24',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-HISTORY-000002','HISTORY','MODERN','{"ko":"세계 인권 선언 채택"}','{"ko":"유엔 총회는 1948년 12월 10일 세계 인권 선언을 채택했다."}','{"ko":"세계 인권 선언은 모든 사람이 누려야 할 기본 권리와 자유를 30개 조항으로 제시했다."}','1948-12-10',array['인권','유엔','법'],'https://www.un.org/en/about-us/universal-declaration-of-human-rights',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-HISTORY-000003','HISTORY','MODERN','{"ko":"베를린 장벽 개방"}','{"ko":"1989년 11월 9일 동독의 국경 통제 변화 발표 뒤 베를린 장벽의 통행이 열렸다."}','{"ko":"장벽 개방은 독일 분단 종식과 1990년 통일로 이어지는 결정적 사건이었다."}','1989-11-09',array['독일','냉전','통일'],'https://www.britannica.com/topic/Berlin-Wall',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000004','SCIENCE','SPACE','{"ko":"스푸트니크 1호 발사"}','{"ko":"소련은 1957년 10월 4일 최초의 인공위성 스푸트니크 1호를 발사했다."}','{"ko":"스푸트니크 1호의 궤도 진입은 우주 시대의 시작을 알렸다."}','1957-10-04',array['우주','위성','소련'],'https://www.nasa.gov/history/sputnik/index.html',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000005','SCIENCE','SPACE','{"ko":"아폴로 11호 달 착륙"}','{"ko":"아폴로 11호 달 착륙선은 1969년 7월 20일 달에 착륙했다."}','{"ko":"닐 암스트롱과 버즈 올드린은 인류 최초로 달 표면에서 활동했다."}','1969-07-20',array['달','아폴로','우주탐사'],'https://www.nasa.gov/mission/apollo-11/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000006','SCIENCE','SPACE','{"ko":"보이저 1호 발사"}','{"ko":"NASA의 보이저 1호는 1977년 9월 5일 외행성 탐사를 위해 발사되었다."}','{"ko":"보이저 1호는 목성과 토성을 관측했으며 이후 성간 공간을 탐사하고 있다."}','1977-09-05',array['보이저','NASA','태양계'],'https://science.nasa.gov/mission/voyager/voyager-1/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000007','SCIENCE','SPACE','{"ko":"허블 우주망원경 발사"}','{"ko":"허블 우주망원경은 1990년 4월 24일 우주왕복선 디스커버리호로 발사되었다."}','{"ko":"지구 대기 위에서 관측하는 허블은 우주 연구와 천문 이미지에 큰 영향을 주었다."}','1990-04-24',array['허블','망원경','천문학'],'https://science.nasa.gov/mission/hubble/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000008','SCIENCE','SPACE','{"ko":"케플러-442b 발견 발표"}','{"ko":"NASA는 2015년 케플러 우주망원경 자료에서 확인된 외계행성 케플러-442b를 발표했다."}','{"ko":"케플러-442b는 통과법으로 발견된 외계행성으로, 관측된 물리량을 넘어 생명이나 문명을 추정할 수는 없다."}','2015-01-06',array['외계행성','케플러','천문학'],'https://science.nasa.gov/exoplanet-catalog/kepler-442-b/',4,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000009','SCIENCE','SPACE','{"ko":"프록시마 센타우리 b 발견"}','{"ko":"2016년 프록시마 센타우리 주위를 도는 외계행성 프록시마 b의 발견이 발표되었다."}','{"ko":"프록시마 b는 태양에서 가장 가까운 항성계에서 발견된 행성이다. 알려진 정보는 관측 결과에 한정된다."}','2016-08-24',array['외계행성','프록시마','천문학'],'https://science.nasa.gov/exoplanet-catalog/proxima-centauri-b/',4,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000010','SCIENCE','SPACE','{"ko":"퍼서비어런스 화성 착륙"}','{"ko":"NASA의 퍼서비어런스 로버는 2021년 2월 18일 화성 예제로 충돌구에 착륙했다."}','{"ko":"퍼서비어런스는 화성의 고대 환경을 조사하고 암석과 토양 시료를 수집하는 임무를 수행한다."}','2021-02-18',array['화성','로버','NASA'],'https://science.nasa.gov/mission/mars-2020-perseverance/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000011','SCIENCE','LIFE-SCI','{"ko":"DNA 이중나선 구조 논문"}','{"ko":"1953년 DNA의 이중나선 구조를 제안하는 논문이 네이처에 발표되었다."}','{"ko":"DNA 구조 연구에는 X선 회절 자료를 만든 로절린드 프랭클린과 모리스 윌킨스 등의 기여가 있었다."}','1953-04-25',array['DNA','유전학','생명과학'],'https://www.nature.com/articles/171737a0',4,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000012','SCIENCE','PHYSICS','{"ko":"주기율표의 제안"}','{"ko":"드미트리 멘델레예프는 1869년 원소를 규칙적으로 배열한 주기 체계를 발표했다."}','{"ko":"주기율표는 원소 성질의 반복성을 드러내고 아직 발견되지 않은 원소의 성질을 예측하는 틀이 되었다."}','1869-03-06',array['화학','원소','주기율표'],'https://www.rsc.org/periodic-table/history/about',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-TECHNOLOGY-000013','TECHNOLOGY','COMPUTING','{"ko":"월드 와이드 웹 제안"}','{"ko":"팀 버너스리는 1989년 CERN에서 정보 관리 시스템을 제안했다."}','{"ko":"이 제안과 후속 구현은 URL, HTTP, HTML을 사용하는 월드 와이드 웹의 기반이 되었다."}','1989-03-12',array['웹','인터넷','CERN'],'https://home.cern/science/computing/birth-web',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-TECHNOLOGY-000014','TECHNOLOGY','COMPUTING','{"ko":"최초의 공개 웹사이트"}','{"ko":"CERN은 월드 와이드 웹 프로젝트를 설명하는 최초의 웹사이트를 운영했다."}','{"ko":"해당 사이트는 웹 사용법과 서버 구축법을 안내하며 개방형 정보 공간의 출발점이 되었다."}','1991-08-06',array['웹사이트','CERN','인터넷'],'https://info.cern.ch/',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-TECHNOLOGY-000015','TECHNOLOGY','ENGINEERING','{"ko":"라이트 형제의 동력 비행"}','{"ko":"1903년 12월 17일 라이트 형제는 키티호크 인근에서 통제된 동력 비행을 수행했다."}','{"ko":"플라이어호의 비행은 동력 고정익 항공기의 발전에 중요한 이정표가 되었다."}','1903-12-17',array['항공','비행','공학'],'https://airandspace.si.edu/collection-objects/1903-wright-flyer',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-TECHNOLOGY-000016','TECHNOLOGY','ENGINEERING','{"ko":"최초의 대서양 횡단 전신 케이블"}','{"ko":"1858년 대서양 횡단 전신 케이블을 통한 공식 메시지가 전송되었다."}','{"ko":"초기 케이블은 곧 작동을 멈췄지만 대륙 간 전기 통신의 가능성을 입증했다."}','1858-08-16',array['전신','통신','대서양'],'https://americanhistory.si.edu/collections/object/nmah_713485',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-CULTURE-000017','CULTURE','VISUAL-ART','{"ko":"모나리자의 루브르 소장"}','{"ko":"레오나르도 다 빈치의 모나리자는 프랑스 루브르 박물관에 소장되어 있다."}','{"ko":"16세기 초에 제작된 초상화로, 작품의 제작 맥락과 소장 이력은 미술사 연구의 대상이다."}','1503-01-01',array['회화','르네상스','루브르'],'https://collections.louvre.fr/en/ark:/53355/cl010062370',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-CULTURE-000018','CULTURE','VISUAL-ART','{"ko":"최초의 영구 사진"}','{"ko":"니세포르 니엡스는 1820년대 창밖 풍경을 담은 현존하는 초기 영구 사진을 제작했다."}','{"ko":"긴 노출로 만든 이 이미지는 사진 기술사의 중요한 유물로 보존되고 있다."}','1827-01-01',array['사진','니엡스','이미지'],'https://www.hrc.utexas.edu/niepce-heliograph/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-CULTURE-000019','CULTURE','MUSIC','{"ko":"베토벤 교향곡 9번 초연"}','{"ko":"베토벤의 교향곡 9번은 1824년 5월 7일 빈에서 초연되었다."}','{"ko":"마지막 악장에 합창을 결합한 이 작품은 이후 음악과 문화에 넓은 영향을 미쳤다."}','1824-05-07',array['베토벤','교향곡','빈'],'https://www.beethoven.de/en/work/view/7025284113793024/Sinfonie+Nr.+9+d-Moll+op.+125',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-PEOPLE-000020','PEOPLE','BIOGRAPHY','{"ko":"마리 퀴리의 노벨상"}','{"ko":"마리 퀴리는 1903년 물리학상과 1911년 화학상을 받았다."}','{"ko":"퀴리는 방사능 연구로 서로 다른 과학 분야에서 노벨상을 받은 과학자가 되었다."}','1911-12-10',array['마리퀴리','노벨상','과학자'],'https://www.nobelprize.org/prizes/chemistry/1911/marie-curie/facts/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-PEOPLE-000021','PEOPLE','BIOGRAPHY','{"ko":"앨런 튜링의 계산 가능성 논문"}','{"ko":"앨런 튜링은 1936년 계산 가능한 수와 결정 문제를 다룬 논문을 제출했다."}','{"ko":"논문에서 설명한 추상 기계는 계산 이론과 컴퓨터 과학의 기초 개념이 되었다."}','1936-05-28',array['튜링','계산이론','컴퓨터'],'https://www.cs.virginia.edu/~robins/Turing_Paper_1936.pdf',4,'00000000-0000-0000-0000-000000000000',true),
('ARC-PEOPLE-000022','PEOPLE','MOVEMENTS','{"ko":"셀마-몽고메리 행진"}','{"ko":"1965년 미국 앨라배마에서 투표권을 요구하는 셀마-몽고메리 행진이 진행되었다."}','{"ko":"비폭력 시위와 행진은 1965년 투표권법 제정에 영향을 준 미국 시민권 운동의 주요 사건이었다."}','1965-03-25',array['시민권','투표권','행진'],'https://www.nps.gov/semo/learn/historyculture/index.htm',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-PLACES-000023','PLACES','EARTH','{"ko":"옐로스톤 국립공원 지정"}','{"ko":"미국은 1872년 3월 1일 옐로스톤을 국립공원으로 지정했다."}','{"ko":"옐로스톤의 지정은 자연 경관을 공공 목적으로 보존하는 국립공원 제도의 중요한 선례가 되었다."}','1872-03-01',array['국립공원','보전','미국'],'https://www.nps.gov/yell/learn/historyculture/index.htm',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-PLACES-000024','PLACES','BEYOND','{"ko":"하위헌스 탐사선의 타이탄 착륙"}','{"ko":"ESA의 하위헌스 탐사선은 2005년 1월 14일 토성의 위성 타이탄에 착륙했다."}','{"ko":"하위헌스는 타이탄 대기를 통과하며 자료를 전송했고 외태양계 천체 표면에 착륙한 최초의 탐사선이 되었다."}','2005-01-14',array['타이탄','하위헌스','토성'],'https://www.esa.int/Science_Exploration/Space_Science/Cassini-Huygens',4,'00000000-0000-0000-0000-000000000000',true),
('ARC-PLACES-000025','PLACES','BEYOND','{"ko":"바이킹 1호 화성 착륙"}','{"ko":"바이킹 1호 착륙선은 1976년 7월 20일 화성 크리세 평원에 착륙했다."}','{"ko":"바이킹 1호는 화성 표면의 고해상도 사진과 기상·토양 자료를 지구로 전송했다."}','1976-07-20',array['화성','바이킹','착륙'],'https://science.nasa.gov/mission/viking-1/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-IDEAS-000026','IDEAS','LANGUAGE','{"ko":"로마자 국제 음성 기호 협회 창립"}','{"ko":"국제 음성학 협회는 1886년 음성 교육자들의 모임에서 시작되었다."}','{"ko":"협회가 발전시킨 국제 음성 기호는 말소리를 일관되게 기록하기 위한 체계다."}','1886-01-01',array['음성학','언어','기호'],'https://www.internationalphoneticassociation.org/content/history-ipa',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-IDEAS-000027','IDEAS','PHILOSOPHY','{"ko":"세계유산협약 채택"}','{"ko":"유네스코 총회는 1972년 11월 16일 세계 문화 및 자연 유산 보호 협약을 채택했다."}','{"ko":"협약은 탁월한 보편적 가치를 지닌 문화·자연 유산을 국제적으로 확인하고 보존하는 틀을 마련했다."}','1972-11-16',array['유네스코','유산','보존'],'https://whc.unesco.org/en/conventiontext/',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-IDEAS-000028','IDEAS','LANGUAGE','{"ko":"한글 창제와 훈민정음 반포"}','{"ko":"세종은 새 문자를 창제했고 1446년 훈민정음을 통해 원리와 용례를 반포했다."}','{"ko":"훈민정음 해례본은 문자 창제의 목적과 제자 원리를 기록한 문헌으로 유네스코 세계기록유산에 등재되어 있다."}','1446-10-09',array['한글','훈민정음','문자'],'https://en.unesco.org/memoryoftheworld/registry/109',3,'00000000-0000-0000-0000-000000000000',true),
('ARC-HISTORY-000029','HISTORY','MODERN','{"ko":"WHO 헌장 발효"}','{"ko":"세계보건기구 헌장은 1948년 4월 7일 발효되었다."}','{"ko":"WHO는 국제 공중보건 협력을 위한 유엔 전문기구로 활동을 시작했다."}','1948-04-07',array['WHO','보건','국제기구'],'https://www.who.int/about/history',2,'00000000-0000-0000-0000-000000000000',true),
('ARC-SCIENCE-000030','SCIENCE','SPACE','{"ko":"제임스 웹 우주망원경 발사"}','{"ko":"제임스 웹 우주망원경은 2021년 12월 25일 아리안 5 로켓으로 발사되었다."}','{"ko":"적외선 관측에 최적화된 웹 망원경은 초기 우주, 은하, 별, 행성계를 연구한다."}','2021-12-25',array['JWST','망원경','우주'],'https://science.nasa.gov/mission/webb/',4,'00000000-0000-0000-0000-000000000000',true)
on conflict(record_code) do nothing;
