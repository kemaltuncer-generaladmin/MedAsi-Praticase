begin;

create table if not exists praticase.support_topics (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null,
  icon_key text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists praticase.faq_items (
  id uuid primary key default extensions.gen_random_uuid(),
  question text not null,
  answer text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists praticase.announcements (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null,
  body text not null default '',
  icon_key text,
  published_at timestamptz not null default now(),
  is_active boolean not null default true
);

create table if not exists praticase.contact_requests (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  email text not null,
  message text not null,
  status text not null default 'open',
  created_at timestamptz not null default now()
);

create table if not exists praticase.user_notes (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid references praticase.cases(id) on delete set null,
  title text not null default '',
  body text not null,
  category text not null default 'Genel',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.lab_result_details (
  id uuid primary key default extensions.gen_random_uuid(),
  test_option_id uuid not null references praticase.test_options(id) on delete cascade,
  title text not null,
  measured_at timestamptz,
  parameters jsonb not null default '[]'::jsonb,
  interpretation text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists praticase.imaging_result_details (
  id uuid primary key default extensions.gen_random_uuid(),
  test_option_id uuid not null references praticase.test_options(id) on delete cascade,
  title text not null,
  image_url text,
  report text not null default '',
  conclusion text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists praticase.medication_infos (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid references praticase.cases(id) on delete cascade,
  name text not null,
  dosage text not null default '',
  route text not null default '',
  indication text not null default '',
  side_effects text not null default '',
  contraindications text not null default '',
  source_url text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table praticase.support_topics enable row level security;
alter table praticase.faq_items enable row level security;
alter table praticase.announcements enable row level security;
alter table praticase.contact_requests enable row level security;
alter table praticase.user_notes enable row level security;
alter table praticase.lab_result_details enable row level security;
alter table praticase.imaging_result_details enable row level security;
alter table praticase.medication_infos enable row level security;

drop policy if exists "Authenticated can read support topics" on praticase.support_topics;
create policy "Authenticated can read support topics"
on praticase.support_topics for select
using (auth.uid() is not null and is_active);

drop policy if exists "Authenticated can read faq items" on praticase.faq_items;
create policy "Authenticated can read faq items"
on praticase.faq_items for select
using (auth.uid() is not null and is_active);

drop policy if exists "Authenticated can read announcements" on praticase.announcements;
create policy "Authenticated can read announcements"
on praticase.announcements for select
using (auth.uid() is not null and is_active);

drop policy if exists "Users can create own contact requests" on praticase.contact_requests;
create policy "Users can create own contact requests"
on praticase.contact_requests for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can read own contact requests" on praticase.contact_requests;
create policy "Users can read own contact requests"
on praticase.contact_requests for select
using (auth.uid() = user_id);

drop policy if exists "Users can manage own notes" on praticase.user_notes;
create policy "Users can manage own notes"
on praticase.user_notes for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Authenticated can read lab result details" on praticase.lab_result_details;
create policy "Authenticated can read lab result details"
on praticase.lab_result_details for select
using (auth.uid() is not null);

drop policy if exists "Authenticated can read imaging result details" on praticase.imaging_result_details;
create policy "Authenticated can read imaging result details"
on praticase.imaging_result_details for select
using (auth.uid() is not null);

drop policy if exists "Authenticated can read medication infos" on praticase.medication_infos;
create policy "Authenticated can read medication infos"
on praticase.medication_infos for select
using (auth.uid() is not null);

create or replace view praticase.user_notification_cards
with (security_invoker = true) as
select id, title, body, is_read, created_at
from praticase.user_notifications
where user_id = auth.uid()
order by created_at desc;

create or replace view praticase.user_favorite_cases
with (security_invoker = true) as
select
  cases.id as case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.points,
  cases.icon_key,
  bookmarks.created_at
from praticase.user_bookmarked_cases bookmarks
join praticase.cases cases on cases.id = bookmarks.case_id
where bookmarks.user_id = auth.uid()
  and cases.is_published
order by bookmarks.created_at desc;

create or replace view praticase.user_case_history_cards
with (security_invoker = true) as
select
  sessions.id as session_id,
  cases.id as case_id,
  cases.title,
  cases.icon_key,
  sessions.status,
  sessions.updated_at,
  progress.progress_percent,
  summaries.total_score
from praticase.exam_sessions sessions
join praticase.cases cases on cases.id = sessions.case_id
left join praticase.user_case_progress progress
  on progress.user_id = sessions.user_id
  and progress.case_id = sessions.case_id
left join praticase.session_result_summaries summaries
  on summaries.session_id = sessions.id
where sessions.user_id = auth.uid()
order by sessions.updated_at desc;

create or replace view praticase.user_data_overview
with (security_invoker = true) as
select 'İstatistiklerim' as title, 'user_dashboard_stats' as data_key
union all select 'Rozetlerim', 'user_badges'
union all select 'Vaka Geçmişim', 'exam_sessions'
union all select 'İndirdiklerim', 'downloads'
union all select 'Notlarım', 'user_notes'
union all select 'Favori Vakalarım', 'user_bookmarked_cases'
union all select 'Başarılarım', 'badge_definitions';

create or replace view praticase.user_case_progress_steps
with (security_invoker = true) as
select
  sessions.id as session_id,
  cases.title as case_title,
  sessions.current_step,
  jsonb_build_array(
    jsonb_build_object('title', 'Anamnez', 'step', 'history', 'status', case when sessions.current_step in ('physical_exam','tests','diagnosis','management','completed') then 'Tamamlandı' else 'Devam Ediyor' end),
    jsonb_build_object('title', 'Fizik Muayene', 'step', 'physical_exam', 'status', case when sessions.current_step in ('tests','diagnosis','management','completed') then 'Tamamlandı' when sessions.current_step = 'physical_exam' then 'Devam Ediyor' else 'Bekliyor' end),
    jsonb_build_object('title', 'Tetkikler', 'step', 'tests', 'status', case when sessions.current_step in ('diagnosis','management','completed') then 'Tamamlandı' when sessions.current_step = 'tests' then 'Devam Ediyor' else 'Bekliyor' end),
    jsonb_build_object('title', 'Tanı', 'step', 'diagnosis', 'status', case when sessions.current_step in ('management','completed') then 'Tamamlandı' when sessions.current_step = 'diagnosis' then 'Devam Ediyor' else 'Bekliyor' end),
    jsonb_build_object('title', 'Tedavi', 'step', 'management', 'status', case when sessions.current_step = 'completed' then 'Tamamlandı' when sessions.current_step = 'management' then 'Devam Ediyor' else 'Bekliyor' end),
    jsonb_build_object('title', 'Sonuç', 'step', 'completed', 'status', case when sessions.current_step = 'completed' then 'Tamamlandı' else 'Bekliyor' end)
  ) as steps
from praticase.exam_sessions sessions
join praticase.cases cases on cases.id = sessions.case_id
where sessions.user_id = auth.uid();

create index if not exists support_topics_order_idx on praticase.support_topics (is_active, sort_order);
create index if not exists faq_items_order_idx on praticase.faq_items (is_active, sort_order);
create index if not exists announcements_published_idx on praticase.announcements (is_active, published_at desc);
create index if not exists user_notes_user_updated_idx on praticase.user_notes (user_id, updated_at desc);

commit;
