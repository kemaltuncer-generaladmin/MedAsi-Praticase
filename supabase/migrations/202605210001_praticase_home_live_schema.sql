begin;

create extension if not exists pgcrypto with schema extensions;
create schema if not exists praticase;

create table if not exists praticase.home_banners (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null check (char_length(trim(title)) > 0),
  subtitle text not null default '',
  cta_label text not null default 'Başla',
  cta_route text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.cases (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique,
  title text not null,
  branch text not null,
  difficulty text not null check (difficulty in ('Kolay', 'Orta', 'Zor')),
  duration_minutes integer not null check (duration_minutes > 0),
  setting text not null,
  candidate_prompt text not null,
  patient_profile jsonb not null default '{}'::jsonb,
  expected_history jsonb not null default '[]'::jsonb,
  expected_physical_exam jsonb not null default '[]'::jsonb,
  expected_differentials jsonb not null default '[]'::jsonb,
  expected_tests jsonb not null default '[]'::jsonb,
  unnecessary_tests jsonb not null default '[]'::jsonb,
  management_steps jsonb not null default '[]'::jsonb,
  critical_mistakes jsonb not null default '[]'::jsonb,
  rubric jsonb not null default '{}'::jsonb,
  points integer not null default 0 check (points >= 0),
  icon_key text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.user_dashboard_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  solved_case_count integer not null default 0 check (solved_case_count >= 0),
  success_rate_percent integer not null default 0 check (
    success_rate_percent between 0 and 100
  ),
  total_points integer not null default 0 check (total_points >= 0),
  daily_streak integer not null default 0 check (daily_streak >= 0),
  solved_delta_percent integer not null default 0,
  success_delta_percent integer not null default 0,
  points_delta_percent integer not null default 0,
  streak_label text,
  updated_at timestamptz not null default now()
);

create table if not exists praticase.user_case_progress (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid not null references praticase.cases(id) on delete cascade,
  status text not null default 'in_progress' check (
    status in ('not_started', 'in_progress', 'completed')
  ),
  progress_percent integer not null default 0 check (
    progress_percent between 0 and 100
  ),
  last_score integer check (last_score between 0 and 100),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, case_id)
);

create table if not exists praticase.user_case_recommendations (
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid not null references praticase.cases(id) on delete cascade,
  sort_order integer not null default 0,
  reason text,
  created_at timestamptz not null default now(),
  primary key (user_id, case_id)
);

create table if not exists praticase.user_bookmarked_cases (
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid not null references praticase.cases(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, case_id)
);

create table if not exists praticase.user_notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists praticase.user_badge_summaries (
  user_id uuid primary key references auth.users(id) on delete cascade,
  title text not null,
  subtitle text not null default '',
  action_label text not null default 'Rozetlerim',
  updated_at timestamptz not null default now()
);

alter table praticase.home_banners enable row level security;
alter table praticase.cases enable row level security;
alter table praticase.user_dashboard_stats enable row level security;
alter table praticase.user_case_progress enable row level security;
alter table praticase.user_case_recommendations enable row level security;
alter table praticase.user_bookmarked_cases enable row level security;
alter table praticase.user_notifications enable row level security;
alter table praticase.user_badge_summaries enable row level security;

drop policy if exists "Public can read active PratiCase home banners" on praticase.home_banners;
create policy "Public can read active PratiCase home banners"
on praticase.home_banners for select
using (
  is_active
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

drop policy if exists "Public can read published PratiCase cases" on praticase.cases;
create policy "Public can read published PratiCase cases"
on praticase.cases for select
using (is_published);

drop policy if exists "Users can read own PratiCase stats" on praticase.user_dashboard_stats;
create policy "Users can read own PratiCase stats"
on praticase.user_dashboard_stats for select
using (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase progress" on praticase.user_case_progress;
create policy "Users can read own PratiCase progress"
on praticase.user_case_progress for select
using (auth.uid() = user_id);

drop policy if exists "Users can write own PratiCase progress" on praticase.user_case_progress;
create policy "Users can write own PratiCase progress"
on praticase.user_case_progress for insert
with check (auth.uid() = user_id);

drop policy if exists "Users can update own PratiCase progress" on praticase.user_case_progress;
create policy "Users can update own PratiCase progress"
on praticase.user_case_progress for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase recommendations" on praticase.user_case_recommendations;
create policy "Users can read own PratiCase recommendations"
on praticase.user_case_recommendations for select
using (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase bookmarks" on praticase.user_bookmarked_cases;
create policy "Users can read own PratiCase bookmarks"
on praticase.user_bookmarked_cases for select
using (auth.uid() = user_id);

drop policy if exists "Users can manage own PratiCase bookmarks" on praticase.user_bookmarked_cases;
create policy "Users can manage own PratiCase bookmarks"
on praticase.user_bookmarked_cases for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase notifications" on praticase.user_notifications;
create policy "Users can read own PratiCase notifications"
on praticase.user_notifications for select
using (auth.uid() = user_id);

drop policy if exists "Users can update own PratiCase notifications" on praticase.user_notifications;
create policy "Users can update own PratiCase notifications"
on praticase.user_notifications for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can read own PratiCase badges" on praticase.user_badge_summaries;
create policy "Users can read own PratiCase badges"
on praticase.user_badge_summaries for select
using (auth.uid() = user_id);

create or replace view praticase.user_home_case_progress
with (security_invoker = true) as
select
  progress.user_id,
  progress.case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  progress.progress_percent,
  progress.updated_at
from praticase.user_case_progress as progress
join praticase.cases as cases on cases.id = progress.case_id
where progress.status = 'in_progress'
  and cases.is_published;

create or replace view praticase.user_recommended_cases
with (security_invoker = true) as
select
  recommendations.user_id,
  recommendations.case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.points,
  cases.icon_key,
  recommendations.sort_order,
  exists (
    select 1
    from praticase.user_bookmarked_cases as bookmarks
    where bookmarks.user_id = recommendations.user_id
      and bookmarks.case_id = recommendations.case_id
  ) as is_bookmarked
from praticase.user_case_recommendations as recommendations
join praticase.cases as cases on cases.id = recommendations.case_id
where cases.is_published;

create index if not exists home_banners_active_order_idx
  on praticase.home_banners (is_active, sort_order);
create index if not exists cases_published_branch_idx
  on praticase.cases (is_published, branch, difficulty);
create index if not exists user_case_progress_user_updated_idx
  on praticase.user_case_progress (user_id, updated_at desc);
create index if not exists user_case_recommendations_user_order_idx
  on praticase.user_case_recommendations (user_id, sort_order);
create index if not exists user_notifications_user_read_idx
  on praticase.user_notifications (user_id, is_read);

commit;
