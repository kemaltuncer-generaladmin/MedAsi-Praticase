-- PratiCase OSCE standard clinical catalog.
-- All published OSCE cases expose the same physical exam and test groups.
-- Case-specific findings override the global default; missing items fall back
-- to a no-pathology answer so candidates cannot infer the diagnosis from the
-- visible option list.

begin;

create table if not exists praticase.global_physical_exam_groups (
  id text primary key,
  title text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists praticase.global_physical_exam_options (
  id text primary key,
  group_id text not null references praticase.global_physical_exam_groups(id) on delete cascade,
  title text not null,
  default_finding text not null default 'Patolojik bulgu saptanmadı.',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists praticase.global_test_groups (
  id text primary key,
  title text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists praticase.global_test_options (
  id text primary key,
  group_id text not null references praticase.global_test_groups(id) on delete cascade,
  title text not null,
  default_result text not null default 'Referans aralığında, anlamlı patoloji saptanmadı.',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table praticase.global_physical_exam_groups enable row level security;
alter table praticase.global_physical_exam_options enable row level security;
alter table praticase.global_test_groups enable row level security;
alter table praticase.global_test_options enable row level security;

drop policy if exists "Public can read global physical groups"
  on praticase.global_physical_exam_groups;
create policy "Public can read global physical groups"
on praticase.global_physical_exam_groups for select to anon, authenticated using (true);

drop policy if exists "Public can read global physical options"
  on praticase.global_physical_exam_options;
create policy "Public can read global physical options"
on praticase.global_physical_exam_options for select to anon, authenticated using (true);

drop policy if exists "Public can read global test groups"
  on praticase.global_test_groups;
create policy "Public can read global test groups"
on praticase.global_test_groups for select to anon, authenticated using (true);

drop policy if exists "Public can read global test options"
  on praticase.global_test_options;
create policy "Public can read global test options"
on praticase.global_test_options for select to anon, authenticated using (true);

grant select on
  praticase.global_physical_exam_groups,
  praticase.global_physical_exam_options,
  praticase.global_test_groups,
  praticase.global_test_options
to anon, authenticated, service_role;

grant all on
  praticase.global_physical_exam_groups,
  praticase.global_physical_exam_options,
  praticase.global_test_groups,
  praticase.global_test_options
to service_role;

insert into praticase.global_physical_exam_groups(id, title, sort_order) values
  ('genel',          'Genel Değerlendirme / Vital Bulgular', 10),
  ('bas_boyun',      'Baş-Boyun',                            20),
  ('toraks',         'Toraks / Solunum',                     30),
  ('kvs',            'Kardiyovasküler',                      40),
  ('batin',          'Batın',                                50),
  ('urogenital',     'Ürogenital / Pelvik / Skrotal',        60),
  ('norolojik',      'Nörolojik',                            70),
  ('kas_iskelet',    'Ekstremite / Kas-İskelet',             80),
  ('cilt_lenf',      'Cilt / Lenfatik',                      90),
  ('mental',         'Mental Durum',                         100)
on conflict (id) do update set
  title = excluded.title,
  sort_order = excluded.sort_order;

insert into praticase.global_physical_exam_options(id, group_id, title, default_finding, sort_order) values
  ('genel_gorunum',          'genel',       'Genel görünüm ve bilinç',                   'Hasta uyanık, koopere, oryante, akut hasta görünümünde değil.',                 10),
  ('vital_bulgular',         'genel',       'Vital bulgular (TA, nabız, ateş, SpO2, SS)','TA 120/75 mmHg, nabız 78/dk düzenli, ateş 36.7°C, SpO2 %98, SS 16/dk.',         20),
  ('hidrasyon',              'genel',       'Hidrasyon ve perfüzyon',                    'Cilt turgoru normal, mukozalar nemli, kapiller dolum < 2 sn.',                  30),
  ('antropometri',           'genel',       'Antropometri / BMI değerlendirmesi',        'Vücut yapısı yaşına uygun, ek bulgu yok.',                                      40),
  ('bas_inspeksiyon',        'bas_boyun',   'Baş ve yüz inspeksiyonu',                   'Asimetri, ödem veya travma izi yok.',                                           10),
  ('goz_muayenesi',          'bas_boyun',   'Göz muayenesi (pupil, konjunktiva, ikter)', 'Pupiller izokorik, ışık refleksi bilateral pozitif, ikter veya konjunktivit yok.',20),
  ('agiz_farinks',           'bas_boyun',   'Ağız, farinks, tonsiller',                  'Orofarinks doğal, tonsiller normal, eksuda yok.',                                30),
  ('tiroid',                 'bas_boyun',   'Tiroid palpasyonu',                         'Tiroid lojunda büyüme veya nodül palpe edilmedi.',                              40),
  ('servikal_lenf',          'bas_boyun',   'Servikal lenfadenopati',                    'Servikal, supraklaviküler ve aksiller LAP saptanmadı.',                          50),
  ('boyun_hareket',          'bas_boyun',   'Boyun hareketleri ve ense sertliği',        'Boyun hareketleri tam, ense sertliği yok.',                                     60),
  ('toraks_insp',            'toraks',      'Toraks inspeksiyonu ve solunum eforu',      'Solunum simetrik, ek solunum kası kullanımı yok.',                              10),
  ('toraks_palp',            'toraks',      'Toraks palpasyonu ve vibrasyon',            'Bilateral vibrasyon eşit, hassasiyet yok.',                                     20),
  ('akciger_oskult',         'toraks',      'Akciğer oskültasyonu',                      'Solunum sesleri bilateral doğal, ek ses yok.',                                  30),
  ('perkusyon',              'toraks',      'Perküsyon',                                 'Akciğer alanları sonor, matite veya hipersonorite yok.',                        40),
  ('kvs_insp',               'kvs',         'Prekordiyum inspeksiyonu',                  'Prekordiyumda görünür pulsasyon yok.',                                          10),
  ('kalp_oskult',            'kvs',         'Kalp oskültasyonu (S1, S2, ek ses, üfürüm)','S1-S2 doğal, ek ses veya üfürüm yok.',                                          20),
  ('periferik_nabiz',        'kvs',         'Periferik nabızlar ve simetri',             'Tüm periferik nabızlar bilateral palpabl ve simetrik.',                          30),
  ('odem_dolasim',           'kvs',         'Periferik ödem ve dolaşım bulguları',       'Ekstremitelerde ödem, siyanoz veya soğukluk yok.',                              40),
  ('batin_insp',             'batin',       'Batın inspeksiyonu',                        'Batın simetrik, skar yok, distansiyon yok.',                                    10),
  ('barsak_sesleri',         'batin',       'Bağırsak sesleri',                          'Bağırsak sesleri tüm kadranlarda normoaktif.',                                  20),
  ('yuzeyel_palp',           'batin',       'Yüzeyel palpasyon',                         'Yüzeyel palpasyonda hassasiyet, defans veya rebound yok.',                       30),
  ('derin_palp',             'batin',       'Derin palpasyon ve organomegali',           'Hepatomegali, splenomegali veya kitle palpe edilmedi.',                          40),
  ('murphy',                 'batin',       'Murphy bulgusu',                            'Murphy bulgusu negatif.',                                                        50),
  ('mcburney',               'batin',       'McBurney noktası ve rebound',               'McBurney noktasında hassasiyet veya rebound saptanmadı.',                        60),
  ('rovsing',                'batin',       'Rovsing bulgusu',                           'Rovsing bulgusu negatif.',                                                       70),
  ('kva',                    'batin',       'KVA (kostovertebral açı) hassasiyeti',      'Bilateral KVA hassasiyeti negatif.',                                             80),
  ('pelvik',                 'urogenital',  'Pelvik muayene (kadın hastada)',            'Vajinal akıntı, hassasiyet veya adneksiyal kitle yok.',                          10),
  ('skrotal',                'urogenital',  'Skrotal ve inguinal muayene (erkek hastada)','Skrotum simetrik, kremaster refleksi pozitif, fıtık yok.',                      20),
  ('rektal',                 'urogenital',  'Rektal/prostat muayene endikasyonu',        'Endikasyon değerlendirildi, anlamlı patoloji saptanmadı.',                       30),
  ('bilinc_gks',             'norolojik',   'Bilinç düzeyi ve GKS',                      'GKS 15, oryantasyon tam, ek defisit yok.',                                       10),
  ('kranial_sinir',          'norolojik',   'Kraniyal sinirler',                         '12 kraniyal sinir muayenesi doğal.',                                             20),
  ('motor',                  'norolojik',   'Motor güç ve tonus',                        'Tüm ekstremitelerde 5/5 motor güç, tonus normal.',                              30),
  ('duyu_refleks',           'norolojik',   'Duyu ve derin tendon refleksleri',          'Duyu modaliteleri doğal, DTR\’ler bilateral normoaktif.',                      40),
  ('serebellar',             'norolojik',   'Serebellar testler ve denge',               'Parmak-burun ve diz-topuk testleri doğal, Romberg negatif.',                     50),
  ('eklem_hareket',          'kas_iskelet', 'Aktif ve pasif eklem hareketleri',          'Tüm büyük eklemlerde hareket açıklığı tam, ağrı yok.',                          10),
  ('kas_inspeksiyon',        'kas_iskelet', 'Kas inspeksiyonu ve atrofi',                'Kas kitlesi simetrik, atrofi yok.',                                              20),
  ('travma_bulgu',           'kas_iskelet', 'Ekstremitede travma / şişlik / hassasiyet', 'Travma izi, hematom veya patolojik hassasiyet saptanmadı.',                      30),
  ('cilt_muayene',           'cilt_lenf',   'Cilt muayenesi (döküntü, ikter, peteşi)',   'Cilt doğal, döküntü veya ikter yok.',                                            10),
  ('lenf_zincirleri',        'cilt_lenf',   'Yüzeyel lenf zincirleri',                   'Servikal, aksiller, inguinal LAP saptanmadı.',                                  20),
  ('mse_genel',              'mental',      'Mental durum muayenesi',                    'Affekt uygun, düşünce içeriği organize, hallüsinasyon yok.',                    10),
  ('konusma',                'mental',      'Konuşma ve dil değerlendirmesi',            'Konuşma akıcı, içerik uygun, afazi yok.',                                       20)
on conflict (id) do update set
  group_id = excluded.group_id,
  title = excluded.title,
  default_finding = excluded.default_finding,
  sort_order = excluded.sort_order;

insert into praticase.global_test_groups(id, title, sort_order) values
  ('lab_temel',     'Temel Laboratuvar',           10),
  ('lab_biyokimya', 'Biyokimya ve Endokrin',       20),
  ('lab_idrar',     'İdrar ve Hızlı Testler',      30),
  ('lab_mikro',     'Mikrobiyoloji / Patoloji',    40),
  ('img_grafi',     'Direkt Grafi',                50),
  ('img_usg',       'Ultrasonografi',              60),
  ('img_kesitsel',  'Tomografi ve MR',             70),
  ('ekg_diger',     'EKG ve Yatak Başı Test',      80),
  ('ozel',          'Özel Tetkikler / Konsültasyon',90)
on conflict (id) do update set
  title = excluded.title,
  sort_order = excluded.sort_order;

insert into praticase.global_test_options(id, group_id, title, default_result, sort_order) values
  ('hemogram',          'lab_temel',     'Hemogram (CBC)',                    'Tüm değerler referans aralığında.',                            10),
  ('crp',               'lab_temel',     'CRP',                               'Normal sınırlarda.',                                            20),
  ('sedim',             'lab_temel',     'Sedimentasyon',                     'Yaş ve cinsiyete göre normal.',                                30),
  ('koagulasyon',       'lab_temel',     'PT, INR, aPTT',                     'Koagülasyon profili normal sınırlarda.',                       40),
  ('glukoz',            'lab_biyokimya', 'Açlık glukoz',                      'Referans aralığında.',                                          10),
  ('uree_kreatinin',    'lab_biyokimya', 'BUN / Kreatinin',                   'Böbrek fonksiyonları normal.',                                  20),
  ('elektrolit',        'lab_biyokimya', 'Sodyum / Potasyum / Klor',          'Elektrolitler referans aralığında.',                            30),
  ('karaciger_paneli',  'lab_biyokimya', 'AST, ALT, ALP, GGT, Bilirubin',     'Karaciğer fonksiyon testleri normal.',                          40),
  ('lipaz_amilaz',      'lab_biyokimya', 'Lipaz / Amilaz',                    'Pankreatik enzimler normal sınırlarda.',                        50),
  ('troponin',          'lab_biyokimya', 'Troponin (yüksek hassasiyetli)',    'Negatif.',                                                       60),
  ('tsh',               'lab_biyokimya', 'TSH',                               'Ötiroid değerler.',                                              70),
  ('idrar',             'lab_idrar',     'Tam idrar tahlili',                 'Lökosit, eritrosit, nitrit negatif, dansite normal.',           10),
  ('idrar_kultur',      'lab_idrar',     'İdrar kültürü',                     '24-72 saatte sonuçlanır; başlangıç ampirik tedavi planlanabilir.',20),
  ('beta_hcg',          'lab_idrar',     'Beta-hCG (kadın hasta)',            'Negatif.',                                                       30),
  ('stik_glukoz',       'lab_idrar',     'Parmak ucu glukoz (POC)',           'Normal sınırlarda.',                                            40),
  ('kan_kultur',        'lab_mikro',     'Kan kültürü (gerekirse iki şişe)',  'Kültür ekildi, ön rapor 24-48 saatte.',                         10),
  ('bogaz_kultur',      'lab_mikro',     'Boğaz / sürüntü kültürü',           'Standart flora.',                                                20),
  ('grm_balgam',        'lab_mikro',     'Gram boyama / balgam incelemesi',   'Polimorf hücreler azalmış, baskın bir patojen görülmedi.',     30),
  ('akc_grafi',         'img_grafi',     'PA akciğer grafisi',                'Akciğer alanları temiz, kardiyotorasik oran normal.',           10),
  ('batin_grafi',       'img_grafi',     'Ayakta direkt batın grafisi',       'Serbest hava yok, anlamlı hava-sıvı seviyesi yok.',             20),
  ('ekstremite_grafi',  'img_grafi',     'Ekstremite grafisi',                'Kemik bütünlüğü korunmuş, fraktür/dislokasyon yok.',           30),
  ('servikal_grafi',    'img_grafi',     'Servikal vertebra grafisi',         'Servikal vertebra hizalanması korunmuş.',                       40),
  ('batin_usg',         'img_usg',       'Batın USG',                          'Karaciğer, safra kesesi, böbrekler doğal; serbest sıvı yok.',  10),
  ('pelvik_usg',        'img_usg',       'Pelvik / transvajinal USG',         'Uterus ve adneksler doğal, serbest sıvı yok.',                 20),
  ('skrotal_usg',       'img_usg',       'Skrotal Doppler USG',               'Bilateral testis kan akımı korunmuş.',                          30),
  ('toraks_usg',        'img_usg',       'Toraks USG / akciğer USG',          'B-line/perde bulgusu yok.',                                     40),
  ('beyin_bt',          'img_kesitsel',  'Kontrastsız beyin BT',              'Akut intrakraniyal kanama veya kitle saptanmadı.',             10),
  ('batin_bt',          'img_kesitsel',  'Kontrastlı batın BT',                'Anlamlı akut bulgu yok, organ perfüzyonları korunmuş.',        20),
  ('toraks_bt',         'img_kesitsel',  'Kontrastlı toraks BT',              'Pulmoner emboli veya kitle saptanmadı.',                        30),
  ('mr_genel',          'img_kesitsel',  'MR (bölgesel)',                     'Endikasyon değerlendirildi; öncelik klinik gözlemde.',         40),
  ('ekg',               'ekg_diger',     'EKG (12 derivasyon)',               'Sinüs ritmi, akut iskemik değişiklik yok.',                     10),
  ('kan_gazi',          'ekg_diger',     'Arteriyel kan gazı',                'pH ve laktat normal, asit-baz dengesi korunmuş.',               20),
  ('hizli_strep',       'ekg_diger',     'Hızlı strep test',                  'Negatif.',                                                       30),
  ('eko',               'ozel',          'Ekokardiyografi',                   'EF korunmuş, kapaklar doğal.',                                  10),
  ('endoskopi',         'ozel',          'Üst GİS endoskopi',                  'Endikasyon değerlendirildi; mukoza intakt.',                   20),
  ('konsultasyon',      'ozel',          'İlgili branş konsültasyonu',        'Konsültasyon talebi iletildi.',                                 30)
on conflict (id) do update set
  group_id = excluded.group_id,
  title = excluded.title,
  default_result = excluded.default_result,
  sort_order = excluded.sort_order;

-- Standard catalog rows must be queryable per case_id so the existing Flutter
-- repository does not need to learn a second data model. We expose unified
-- views that emit a row per case x global option, overridden by case-specific
-- physical_exam_options / test_options whenever the title matches.

create or replace function praticase.normalize_label(p_value text)
returns text language sql immutable as $$
  select regexp_replace(lower(coalesce(p_value, '')), '\s+', ' ', 'g')
$$;

create or replace view praticase.case_physical_exam_groups_v
with (security_invoker = true) as
with case_groups as (
  select
    cases.id as case_id,
    coalesce(nullif(trim(g.id::text), ''), 'case:' || g.id::text) as id,
    g.title,
    g.sort_order,
    'case'::text as source
  from praticase.cases cases
  join praticase.physical_exam_groups g on g.case_id = cases.id
  where cases.is_published
), global_groups as (
  select
    cases.id as case_id,
    'global:' || g.id as id,
    g.title,
    g.sort_order,
    'global'::text as source
  from praticase.cases cases
  cross join praticase.global_physical_exam_groups g
  where cases.is_published
)
select * from case_groups
union all
select gg.* from global_groups gg
where not exists (
  select 1 from case_groups cg
  where cg.case_id = gg.case_id
    and praticase.normalize_label(cg.title) = praticase.normalize_label(gg.title)
);

create or replace view praticase.case_physical_exam_options_v
with (security_invoker = true) as
with case_groups as (
  select cases.id as case_id, g.id::text as case_group_id, g.title as group_title
  from praticase.cases cases
  join praticase.physical_exam_groups g on g.case_id = cases.id
  where cases.is_published
), case_options as (
  select
    cg.case_id,
    o.id::text as id,
    cg.case_group_id as group_id,
    o.title,
    o.finding,
    o.point_value,
    o.is_critical,
    o.sort_order
  from case_groups cg
  join praticase.physical_exam_options o on o.group_id = cg.case_group_id::uuid
), global_groups as (
  select cases.id as case_id, g.id as global_group_id, g.title as group_title
  from praticase.cases cases
  cross join praticase.global_physical_exam_groups g
  where cases.is_published
), global_options as (
  select
    gg.case_id,
    'global:' || o.id as id,
    case
      when exists (
        select 1 from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
      ) then (
        select cg.case_group_id from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
        limit 1
      )
      else 'global:' || gg.global_group_id
    end as group_id,
    o.title,
    o.default_finding as finding,
    0 as point_value,
    false as is_critical,
    o.sort_order + 1000 as sort_order
  from global_groups gg
  join praticase.global_physical_exam_options o on o.group_id = gg.global_group_id
)
select * from case_options
union all
select * from global_options g
where not exists (
  select 1 from case_options c
  where c.case_id = g.case_id
    and c.group_id = g.group_id
    and praticase.normalize_label(c.title) = praticase.normalize_label(g.title)
);

create or replace view praticase.case_test_groups_v
with (security_invoker = true) as
with case_groups as (
  select cases.id as case_id, g.id::text as id, g.title, g.sort_order, 'case'::text as source
  from praticase.cases cases
  join praticase.test_groups g on g.case_id = cases.id
  where cases.is_published
), global_groups as (
  select cases.id as case_id, 'global:' || g.id as id, g.title, g.sort_order, 'global'::text as source
  from praticase.cases cases
  cross join praticase.global_test_groups g
  where cases.is_published
)
select * from case_groups
union all
select gg.* from global_groups gg
where not exists (
  select 1 from case_groups cg
  where cg.case_id = gg.case_id
    and praticase.normalize_label(cg.title) = praticase.normalize_label(gg.title)
);

create or replace view praticase.case_test_options_v
with (security_invoker = true) as
with case_groups as (
  select cases.id as case_id, g.id::text as case_group_id, g.title as group_title
  from praticase.cases cases
  join praticase.test_groups g on g.case_id = cases.id
  where cases.is_published
), case_options as (
  select
    cg.case_id,
    o.id::text as id,
    cg.case_group_id as group_id,
    o.title,
    o.result,
    o.point_cost,
    o.is_unnecessary,
    o.sort_order
  from case_groups cg
  join praticase.test_options o on o.group_id = cg.case_group_id::uuid
), global_groups as (
  select cases.id as case_id, g.id as global_group_id, g.title as group_title
  from praticase.cases cases
  cross join praticase.global_test_groups g
  where cases.is_published
), global_options as (
  select
    gg.case_id,
    'global:' || o.id as id,
    case
      when exists (
        select 1 from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
      ) then (
        select cg.case_group_id from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
        limit 1
      )
      else 'global:' || gg.global_group_id
    end as group_id,
    o.title,
    o.default_result as result,
    0 as point_cost,
    false as is_unnecessary,
    o.sort_order + 1000 as sort_order
  from global_groups gg
  join praticase.global_test_options o on o.group_id = gg.global_group_id
)
select * from case_options
union all
select * from global_options g
where not exists (
  select 1 from case_options c
  where c.case_id = g.case_id
    and c.group_id = g.group_id
    and praticase.normalize_label(c.title) = praticase.normalize_label(g.title)
);

grant select on
  praticase.case_physical_exam_groups_v,
  praticase.case_physical_exam_options_v,
  praticase.case_test_groups_v,
  praticase.case_test_options_v
to anon, authenticated, service_role;

-- Allow recording selections for global options without writing into the
-- case-specific tables. We keep the existing primary key (session_id,
-- option_id) but loosen the FK to permit synthetic "global:*" identifiers.

alter table praticase.session_physical_exam_findings
  drop constraint if exists session_physical_exam_findings_option_id_fkey;

alter table praticase.session_physical_exam_findings
  alter column option_id type text using option_id::text;

alter table praticase.session_requested_tests
  drop constraint if exists session_requested_tests_option_id_fkey;

alter table praticase.session_requested_tests
  alter column option_id type text using option_id::text;

-- Backfill selections for cases that previously stored uuid only.
update praticase.session_physical_exam_findings
set option_id = option_id
where option_id is not null;

update praticase.session_requested_tests
set option_id = option_id
where option_id is not null;

-- The finalize function joins selected option ids with physical_exam_options
-- and test_options on uuid. Recreate it so global selections are tolerated
-- and contribute zero-score (catalogue items are non-scoring).
create or replace function praticase.finalize_exam_session(p_session_id uuid)
returns table(session_id uuid, total_score integer, max_score integer, percentage integer)
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_user_id uuid;
  v_case_id uuid;
  v_had_result boolean;
  v_candidate_message_count integer := 0;
  v_communication integer := 0;
  v_history integer := 0;
  v_physical integer := 0;
  v_tests integer := 0;
  v_diagnosis integer := 0;
  v_management integer := 0;
  v_total integer := 0;
  v_scores jsonb;
  v_strong jsonb := '[]'::jsonb;
  v_improvement jsonb := '[]'::jsonb;
  v_unnecessary jsonb := '[]'::jsonb;
begin
  select s.user_id, s.case_id into v_user_id, v_case_id
  from praticase.exam_sessions s where s.id = p_session_id;
  if v_user_id is null or v_user_id <> auth.uid() then
    raise exception 'Exam session not found';
  end if;

  select exists(select 1 from praticase.session_result_summaries r where r.session_id = p_session_id)
  into v_had_result;

  select count(*)::integer into v_candidate_message_count
  from praticase.exam_messages where session_id = p_session_id and sender = 'candidate';
  v_communication := least(v_candidate_message_count, 10);
  v_history := least(v_candidate_message_count * 3, 30);

  select least(coalesce(sum(coalesce(o.point_value, 0)), 0)::integer, 20) into v_physical
  from praticase.session_physical_exam_findings f
  left join praticase.physical_exam_options o
    on f.option_id ~ '^[0-9a-fA-F-]{36}$' and o.id::text = f.option_id;

  select greatest(0, least(coalesce(sum(case when coalesce(o.is_unnecessary, false) then -5 else 5 end), 0)::integer, 15)),
    coalesce(jsonb_agg(o.title) filter (where coalesce(o.is_unnecessary, false)), '[]'::jsonb)
  into v_tests, v_unnecessary
  from praticase.session_requested_tests r
  left join praticase.test_options o
    on r.option_id ~ '^[0-9a-fA-F-]{36}$' and o.id::text = r.option_id;

  select case
    when exists (
      select 1 from praticase.session_diagnosis_answers a
      join unnest(a.selected_option_ids) i on true
      join praticase.diagnosis_options o on o.id = i
      where a.session_id = p_session_id and o.is_primary
    ) then 15
    when exists (
      select 1 from praticase.session_diagnosis_answers a
      join unnest(a.selected_option_ids) i on true
      join praticase.diagnosis_options o on o.id = i
      where a.session_id = p_session_id and o.is_correct
    ) then 10 else 0 end
  into v_diagnosis;

  select least(coalesce(sum(o.point_value), 0)::integer, 10) into v_management
  from praticase.session_management_plan_items i
  join praticase.management_plan_options o on o.id = i.option_id
  where i.session_id = p_session_id;

  v_total := v_communication + v_history + v_physical + v_tests + v_diagnosis + v_management;
  v_scores := jsonb_build_array(
    jsonb_build_object('title', 'İletişim', 'score', v_communication, 'maxScore', 10),
    jsonb_build_object('title', 'Anamnez', 'score', v_history, 'maxScore', 30),
    jsonb_build_object('title', 'Fizik Muayene', 'score', v_physical, 'maxScore', 20),
    jsonb_build_object('title', 'Ön Tanılar', 'score', v_diagnosis, 'maxScore', 15),
    jsonb_build_object('title', 'Tetkikler', 'score', v_tests, 'maxScore', 15),
    jsonb_build_object('title', 'Yönetim', 'score', v_management, 'maxScore', 10)
  );
  if v_history >= 18 then v_strong := v_strong || '["Anamnez akışın düzenli ilerledi."]'::jsonb;
  else v_improvement := v_improvement || '["Anamnez başlıklarını daha sistematik sorgula."]'::jsonb; end if;
  if v_physical < 12 then v_improvement := v_improvement || '["Sistemik muayene seçimini genişlet."]'::jsonb; end if;
  if jsonb_array_length(v_unnecessary) > 0 then
    v_improvement := v_improvement || '["Tetkik istemlerini klinik gerekliliğe göre daralt."]'::jsonb;
  end if;

  insert into praticase.session_result_summaries(
    session_id, total_score, max_score, category_scores, strong_points,
    improvement_points, unnecessary_tests, updated_at
  ) values (
    p_session_id, v_total, 100, v_scores, v_strong, v_improvement, v_unnecessary, now()
  ) on conflict (session_id) do update set
    total_score = excluded.total_score, max_score = 100,
    category_scores = excluded.category_scores, strong_points = excluded.strong_points,
    improvement_points = excluded.improvement_points,
    unnecessary_tests = excluded.unnecessary_tests, updated_at = now();

  update praticase.exam_sessions set current_step = 'completed', status = 'completed',
    ended_at = coalesce(ended_at, now()), updated_at = now()
  where id = p_session_id;

  insert into praticase.user_case_progress(user_id, case_id, status, progress_percent, last_score, completed_at, updated_at)
  values (v_user_id, v_case_id, 'completed', 100, v_total, now(), now())
  on conflict (user_id, case_id) do update set status = 'completed', progress_percent = 100,
    last_score = excluded.last_score, completed_at = coalesce(praticase.user_case_progress.completed_at, now()), updated_at = now();

  if not v_had_result then
    update praticase.cases set solved_count = solved_count + 1, updated_at = now() where id = v_case_id;
    insert into praticase.user_dashboard_stats(user_id, solved_case_count, success_rate_percent, total_points, daily_streak, updated_at)
    values (v_user_id, 1, v_total, v_total, 1, now())
    on conflict (user_id) do update set solved_case_count = praticase.user_dashboard_stats.solved_case_count + 1,
      success_rate_percent = v_total, total_points = praticase.user_dashboard_stats.total_points + v_total,
      daily_streak = greatest(praticase.user_dashboard_stats.daily_streak, 1), updated_at = now();
    insert into praticase.leaderboard_scores(user_id, display_name, total_points, solved_case_count, correct_diagnosis_rate, updated_at)
    values (v_user_id, coalesce(praticase.profile_display_name(v_user_id), 'PratiCase Öğrencisi'), v_total, 1,
      case when v_diagnosis >= 12 then 100 else 0 end, now())
    on conflict (user_id) do update set total_points = praticase.leaderboard_scores.total_points + v_total,
      solved_case_count = praticase.leaderboard_scores.solved_case_count + 1,
      correct_diagnosis_rate = case when v_diagnosis >= 12 then 100 else 0 end, updated_at = now();
  end if;

  insert into praticase.session_evaluation_snapshots(
    session_id, user_id, case_id, evaluation_input, deterministic_result
  )
  select p_session_id, v_user_id, v_case_id,
    jsonb_build_object(
      'transcript', coalesce((select jsonb_agg(jsonb_build_object('sender', sender, 'message', message, 'createdAt', created_at) order by created_at) from praticase.exam_messages where session_id = p_session_id), '[]'::jsonb),
      'physicalExamOptionIds', coalesce((select jsonb_agg(option_id) from praticase.session_physical_exam_findings where session_id = p_session_id), '[]'::jsonb),
      'testOptionIds', coalesce((select jsonb_agg(option_id) from praticase.session_requested_tests where session_id = p_session_id), '[]'::jsonb),
      'diagnosis', coalesce((select to_jsonb(a) from praticase.session_diagnosis_answers a where a.session_id = p_session_id), '{}'::jsonb),
      'management', coalesce((select to_jsonb(n) from praticase.session_management_notes n where n.session_id = p_session_id), '{}'::jsonb)
    ),
    jsonb_build_object('totalScore', v_total, 'maxScore', 100, 'categoryScores', v_scores)
  on conflict (session_id) do nothing;

  return query select p_session_id, v_total, 100, v_total;
end;
$$;

grant execute on function praticase.finalize_exam_session(uuid) to authenticated;

-- Helper RPC that lets the Flutter client send a global selection without
-- caring about uuid casting.
create or replace function praticase.upsert_session_physical_selection(
  p_session_id uuid,
  p_option_id text
) returns void
language plpgsql security definer
set search_path = praticase, public, extensions
as $$
begin
  if (select user_id from praticase.exam_sessions where id = p_session_id) <> auth.uid() then
    raise exception 'Exam session not found';
  end if;
  insert into praticase.session_physical_exam_findings(session_id, option_id)
  values (p_session_id, p_option_id)
  on conflict (session_id, option_id) do nothing;
end;
$$;

create or replace function praticase.upsert_session_test_request(
  p_session_id uuid,
  p_option_id text
) returns void
language plpgsql security definer
set search_path = praticase, public, extensions
as $$
begin
  if (select user_id from praticase.exam_sessions where id = p_session_id) <> auth.uid() then
    raise exception 'Exam session not found';
  end if;
  insert into praticase.session_requested_tests(session_id, option_id)
  values (p_session_id, p_option_id)
  on conflict (session_id, option_id) do nothing;
end;
$$;

grant execute on function praticase.upsert_session_physical_selection(uuid, text)
  to authenticated;
grant execute on function praticase.upsert_session_test_request(uuid, text)
  to authenticated;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240004', '202605240004_praticase_standard_clinical_catalog.sql')
on conflict (version) do nothing;

commit;
