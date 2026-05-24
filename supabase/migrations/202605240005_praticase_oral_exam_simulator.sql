-- PratiCase Sözlü Sınav Simülasyonu.
-- Türk tıp fakültesi sözlü sınavlarının dinamiğini taklit eder:
-- - Üç hoca persona (Sabırlı Asistan, Sokratik Doçent, Sert Profesör)
-- - Sokratik takip soruları
-- - Vaka tabanlı klinik akıl yürütme
-- - Stres + zaman baskısı
-- - 100 puanlık rubrik (akıl yürütme 40, bilgi 30, iletişim 15, hız 10, profesyonellik 5)

begin;

create table if not exists praticase.oral_exam_personas (
  id text primary key,
  title text not null,
  difficulty text not null check (difficulty in ('Kolay', 'Orta', 'Zor')),
  description text not null,
  system_prompt text not null,
  voice_style text not null default 'neutral',
  patience_level integer not null default 5
    check (patience_level between 1 and 10),
  sort_order integer not null default 0
);

insert into praticase.oral_exam_personas(
  id, title, difficulty, description, system_prompt, voice_style, patience_level, sort_order
) values
  (
    'patient_assistant',
    'Sabırlı Asistan',
    'Kolay',
    'Yeni asistan doktor: hatalarını nazikçe düzeltir, ipucu verir, öğrenmeye odaklıdır.',
    'Sen kıdemli bir tıp asistanısın. Öğrenciyi sözlü sınavda değerlendiriyorsun. Sıcak, sabırlı ve eğitici bir tonla konuş. Öğrenci eksik cevap verirse ipucu ver. Tek seferde bir soru sor, kısa olsun. Doğru cevap aldığında olumlu pekiştir ve bir sonraki adımı sor. ASLA tek seferde birden fazla soru sorma. Klinik akıl yürütmeyi test et, ezbere bilgiyi değil.',
    'warm',
    8,
    10
  ),
  (
    'socratic_associate',
    'Sokratik Doçent',
    'Orta',
    'Doçent: sürekli "niye?" diye sorar, öğrencinin mantığını test eder, ezbere cevap kabul etmez.',
    'Sen klinikte sözlü sınav yapan bir doçentsin. Sokratik yöntemle ilerlersin: her cevabın ardından "neden?", "açıklayın", "başka olasılık?", "ne yaparsınız?" gibi takip soruları sorarsın. Doğru cevap aldığında bile bir kademe derinleştir. Ezbere yanıtları yakala ve eleştir. Tek seferde bir soru. Tonun ölçülü, profesyonel, hafifçe sorgulayıcı.',
    'measured',
    5,
    20
  ),
  (
    'stern_professor',
    'Sert Profesör',
    'Zor',
    'Profesör: az konuşur, hatayı affetmez. Yanlış cevap = sert takip. Pas geçmek hoş karşılanmaz.',
    'Sen tıp fakültesinin sert profesörüsün. Sözlü sınavda az konuşursun, doğrudan ve keskin sorular sorarsın. Öğrenci yanlış cevap verirse ya da bilmediği için "öğretilmedi" derse bunu açıkça eleştir. Eksik cevaplarda "yetersiz", "daha?", "bu kadar mı?" gibi kısa baskı uygula. Doğru ve eksiksiz cevap aldığında kuru bir "iyi" yeterlidir. Asla iki soru aynı anda sorma. Stres uygula ama hakaret etme.',
    'firm',
    3,
    30
  )
on conflict (id) do update set
  title = excluded.title,
  difficulty = excluded.difficulty,
  description = excluded.description,
  system_prompt = excluded.system_prompt,
  voice_style = excluded.voice_style,
  patience_level = excluded.patience_level,
  sort_order = excluded.sort_order;

create table if not exists praticase.oral_exam_branches (
  id text primary key,
  title text not null,
  description text not null,
  case_seed text not null,
  sort_order integer not null default 0
);

insert into praticase.oral_exam_branches(id, title, description, case_seed, sort_order) values
  ('dahiliye', 'Dahiliye',
   'İç hastalıkları stajı: kronik hastalıklar, akut dekompansasyon, ayırıcı tanı yoğun.',
   'Yetişkin hasta polikliniğe veya servise başvurmuş. Şikayet ön plana çıkan dahili bir problem olmalı (hipertansiyon, diyabet komplikasyonu, KAH, KOAH alevlenmesi, akut karın ağrısı, ateş etiyolojisi, anemi vb).',
   10),
  ('cerrahi', 'Genel Cerrahi',
   'Acil ve elektif cerrahi vakalar: akut karın, travma, post-op komplikasyon.',
   'Yetişkin hasta acile veya cerrahi servise başvurmuş. Vaka akut batın (apandisit, kolesistit, peritonit), travma, post-op ateş veya elektif vaka değerlendirmesi olmalı.',
   20),
  ('cocuk', 'Çocuk Sağlığı',
   'Pediatri stajı: ateş, ishal, solunum yolu, büyüme-gelişme, aşı, acil pediatrik vakalar.',
   'Çocuk hasta polikliniğe veya acile başvurmuş. Yaş (0-18) ve şikayet belirli olmalı. Ateş + döküntü, akut bronşiyolit, dehidratasyon, ALTE, idrar yolu enfeksiyonu gibi pediatriye özgü olsun.',
   30),
  ('kadin_dogum', 'Kadın Doğum',
   'Obstetri ve jinekoloji: gebelik takibi, akut pelvik ağrı, kanama, postpartum komplikasyon.',
   'Üreme çağında veya gebe kadın hasta. Vaka: ektopik gebelik şüphesi, preeklampsi, anormal uterin kanama, postpartum kanama, akut salpenjit veya gebelik takibi olabilir.',
   40),
  ('acil', 'Acil Tıp',
   'Acil servise başvuran kritik hasta: travma, göğüs ağrısı, dispne, bilinç bozukluğu.',
   'Acil servise başvurmuş kritik veya yarı kritik hasta. Göğüs ağrısı (AKS), dispne (PTE, pnömoni, KKY), bilinç değişikliği (hipoglisemi, intoksikasyon, SVO), travma, anaflaksi gibi zaman duyarlı vakalar.',
   50)
on conflict (id) do update set
  title = excluded.title,
  description = excluded.description,
  case_seed = excluded.case_seed,
  sort_order = excluded.sort_order;

create table if not exists praticase.oral_exam_sessions (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  persona_id text not null references praticase.oral_exam_personas(id),
  branch_id text not null references praticase.oral_exam_branches(id),
  duration_seconds integer not null default 900
    check (duration_seconds between 300 and 1800),
  case_brief text not null default '',
  status text not null default 'active'
    check (status in ('active', 'completed', 'abandoned')),
  total_score integer,
  max_score integer not null default 100,
  reasoning_score integer,
  knowledge_score integer,
  communication_score integer,
  pace_score integer,
  professionalism_score integer,
  mentor_summary text,
  strong_points jsonb not null default '[]'::jsonb,
  improvement_points jsonb not null default '[]'::jsonb,
  missed_points jsonb not null default '[]'::jsonb,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  updated_at timestamptz not null default now()
);

create index if not exists oral_exam_sessions_user_idx
  on praticase.oral_exam_sessions(user_id, started_at desc);

create table if not exists praticase.oral_exam_turns (
  id uuid primary key default extensions.gen_random_uuid(),
  session_id uuid not null references praticase.oral_exam_sessions(id) on delete cascade,
  sequence integer not null,
  speaker text not null check (speaker in ('mentor', 'candidate', 'system')),
  message text not null,
  is_followup boolean not null default false,
  was_skipped boolean not null default false,
  evaluation jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists oral_exam_turns_session_seq_idx
  on praticase.oral_exam_turns(session_id, sequence);

alter table praticase.oral_exam_personas enable row level security;
alter table praticase.oral_exam_branches enable row level security;
alter table praticase.oral_exam_sessions enable row level security;
alter table praticase.oral_exam_turns enable row level security;

drop policy if exists "Public can read oral exam personas" on praticase.oral_exam_personas;
create policy "Public can read oral exam personas"
on praticase.oral_exam_personas for select to anon, authenticated using (true);

drop policy if exists "Public can read oral exam branches" on praticase.oral_exam_branches;
create policy "Public can read oral exam branches"
on praticase.oral_exam_branches for select to anon, authenticated using (true);

drop policy if exists "Users can read own oral exam sessions" on praticase.oral_exam_sessions;
create policy "Users can read own oral exam sessions"
on praticase.oral_exam_sessions for select to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can create own oral exam sessions" on praticase.oral_exam_sessions;
create policy "Users can create own oral exam sessions"
on praticase.oral_exam_sessions for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update own oral exam sessions" on praticase.oral_exam_sessions;
create policy "Users can update own oral exam sessions"
on praticase.oral_exam_sessions for update to authenticated
using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can read own oral exam turns" on praticase.oral_exam_turns;
create policy "Users can read own oral exam turns"
on praticase.oral_exam_turns for select to authenticated
using (
  exists (
    select 1 from praticase.oral_exam_sessions s
    where s.id = oral_exam_turns.session_id and s.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own oral exam turns" on praticase.oral_exam_turns;
create policy "Users can write own oral exam turns"
on praticase.oral_exam_turns for insert to authenticated
with check (
  exists (
    select 1 from praticase.oral_exam_sessions s
    where s.id = oral_exam_turns.session_id and s.user_id = auth.uid()
  )
);

grant select on
  praticase.oral_exam_personas,
  praticase.oral_exam_branches,
  praticase.oral_exam_sessions,
  praticase.oral_exam_turns
to anon, authenticated, service_role;

grant insert, update on
  praticase.oral_exam_sessions,
  praticase.oral_exam_turns
to authenticated, service_role;

grant all on praticase.oral_exam_personas, praticase.oral_exam_branches to service_role;

-- Exam mode card kayıt
insert into praticase.exam_mode_cards(
  id, title, subtitle, icon_key, action_key, sort_order, is_active
) values (
  'oral_exam',
  'Sözlü Sınav',
  'Sanal hocayla bire bir sözlü sınav simülasyonu. Sokratik soru, klinik akıl yürütme, rubrik puanlama.',
  'oral_exam',
  'oral_exam',
  60,
  true
) on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  icon_key = excluded.icon_key,
  action_key = excluded.action_key,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

-- Home banner: yeni mod tanıtımı
insert into praticase.home_banners(
  title, subtitle, cta_label, cta_route, sort_order, is_active
) values (
  'Sözlü Sınav Simülasyonu',
  'Sanal hocayla bire bir sözlü sınav: sokratik takip, klinik karar, rubrik tabanlı karne. Yeni mod canlıda.',
  'Sözlü Sınava Başla',
  '/oral-exam',
  15,
  true
);

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240005', '202605240005_praticase_oral_exam_simulator.sql')
on conflict (version) do nothing;

commit;
