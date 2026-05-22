begin;

alter table praticase.exam_sessions
  drop constraint if exists exam_sessions_current_step_check,
  add constraint exam_sessions_current_step_check check (
    current_step in (
      'history',
      'physical_exam',
      'tests',
      'diagnosis',
      'management',
      'completed'
    )
  );

create table if not exists praticase.management_plan_options (
  id uuid primary key default extensions.gen_random_uuid(),
  case_id uuid not null references praticase.cases(id) on delete cascade,
  category text not null,
  title text not null,
  point_value integer not null default 0,
  is_recommended boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists praticase.session_management_plan_items (
  session_id uuid not null references praticase.exam_sessions(id) on delete cascade,
  option_id uuid not null references praticase.management_plan_options(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (session_id, option_id)
);

create table if not exists praticase.session_management_notes (
  session_id uuid primary key references praticase.exam_sessions(id) on delete cascade,
  diagnosis text not null default '',
  plan_note text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists praticase.session_result_summaries (
  session_id uuid primary key references praticase.exam_sessions(id) on delete cascade,
  total_score integer not null default 0 check (total_score >= 0),
  max_score integer not null default 100 check (max_score > 0),
  percentage integer generated always as (
    case when max_score > 0 then round((total_score::numeric / max_score::numeric) * 100) else 0 end
  ) stored,
  category_scores jsonb not null default '[]'::jsonb,
  strong_points jsonb not null default '[]'::jsonb,
  improvement_points jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.badge_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null,
  subtitle text not null default '',
  icon_key text,
  tier text not null default 'bronze',
  target_count integer not null default 1 check (target_count > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists praticase.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id uuid not null references praticase.badge_definitions(id) on delete cascade,
  progress_count integer not null default 0 check (progress_count >= 0),
  earned_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

create table if not exists praticase.leaderboard_scores (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_url text,
  total_points integer not null default 0 check (total_points >= 0),
  solved_case_count integer not null default 0 check (solved_case_count >= 0),
  correct_diagnosis_rate integer not null default 0 check (
    correct_diagnosis_rate between 0 and 100
  ),
  institution text,
  updated_at timestamptz not null default now()
);

create table if not exists praticase.user_app_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_mode text not null default 'Sistem',
  language text not null default 'Türkçe',
  text_size text not null default 'Orta',
  sound_and_haptics boolean not null default true,
  data_usage text not null default 'Standart',
  offline_mode boolean not null default false,
  case_downloads_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table praticase.management_plan_options enable row level security;
alter table praticase.session_management_plan_items enable row level security;
alter table praticase.session_management_notes enable row level security;
alter table praticase.session_result_summaries enable row level security;
alter table praticase.badge_definitions enable row level security;
alter table praticase.user_badges enable row level security;
alter table praticase.leaderboard_scores enable row level security;
alter table praticase.user_app_settings enable row level security;

drop policy if exists "Public can read published management options" on praticase.management_plan_options;
create policy "Public can read published management options"
on praticase.management_plan_options for select
using (
  exists (
    select 1 from praticase.cases
    where cases.id = management_plan_options.case_id
      and cases.is_published
  )
);

drop policy if exists "Users can read own management selections" on praticase.session_management_plan_items;
create policy "Users can read own management selections"
on praticase.session_management_plan_items for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_plan_items.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own management selections" on praticase.session_management_plan_items;
create policy "Users can write own management selections"
on praticase.session_management_plan_items for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_plan_items.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can read own management notes" on praticase.session_management_notes;
create policy "Users can read own management notes"
on praticase.session_management_notes for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_notes.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can write own management notes" on praticase.session_management_notes;
create policy "Users can write own management notes"
on praticase.session_management_notes for insert
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_notes.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can update own management notes" on praticase.session_management_notes;
create policy "Users can update own management notes"
on praticase.session_management_notes for update
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_notes.session_id
      and exam_sessions.user_id = auth.uid()
  )
)
with check (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_management_notes.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Users can read own result summaries" on praticase.session_result_summaries;
create policy "Users can read own result summaries"
on praticase.session_result_summaries for select
using (
  exists (
    select 1 from praticase.exam_sessions
    where exam_sessions.id = session_result_summaries.session_id
      and exam_sessions.user_id = auth.uid()
  )
);

drop policy if exists "Authenticated can read active badges" on praticase.badge_definitions;
create policy "Authenticated can read active badges"
on praticase.badge_definitions for select
using (is_active and auth.uid() is not null);

drop policy if exists "Users can read own badges" on praticase.user_badges;
create policy "Users can read own badges"
on praticase.user_badges for select
using (auth.uid() = user_id);

drop policy if exists "Authenticated can read leaderboard" on praticase.leaderboard_scores;
create policy "Authenticated can read leaderboard"
on praticase.leaderboard_scores for select
using (auth.uid() is not null);

drop policy if exists "Users can read own app settings" on praticase.user_app_settings;
create policy "Users can read own app settings"
on praticase.user_app_settings for select
using (auth.uid() = user_id);

drop policy if exists "Users can manage own app settings" on praticase.user_app_settings;
create policy "Users can manage own app settings"
on praticase.user_app_settings for all
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create or replace view praticase.session_result_cards
with (security_invoker = true) as
select
  summaries.session_id,
  cases.title as case_title,
  summaries.total_score,
  summaries.max_score,
  summaries.percentage,
  summaries.category_scores,
  summaries.strong_points,
  summaries.improvement_points
from praticase.session_result_summaries summaries
join praticase.exam_sessions sessions on sessions.id = summaries.session_id
join praticase.cases cases on cases.id = sessions.case_id
where sessions.user_id = auth.uid();

create or replace view praticase.user_badge_cards
with (security_invoker = true) as
select
  badges.id as badge_id,
  badges.title,
  badges.subtitle,
  badges.icon_key,
  badges.tier,
  badges.target_count,
  coalesce(user_badges.progress_count, 0) as progress_count,
  user_badges.earned_at,
  badges.sort_order
from praticase.badge_definitions badges
left join praticase.user_badges
  on user_badges.badge_id = badges.id
  and user_badges.user_id = auth.uid()
where badges.is_active;

create or replace view praticase.leaderboard_general
with (security_invoker = true) as
select
  row_number() over (order by total_points desc, solved_case_count desc) as rank,
  user_id,
  display_name,
  avatar_url,
  total_points,
  solved_case_count,
  correct_diagnosis_rate,
  institution,
  user_id = auth.uid() as is_current_user
from praticase.leaderboard_scores;

create or replace view praticase.user_profile_cards
with (security_invoker = true) as
select
  profiles.id as user_id,
  trim(coalesce(profiles.first_name, '') || ' ' || coalesce(profiles.last_name, '')) as display_name,
  profiles.email,
  profiles.class_level,
  profiles.target,
  leaderboard.total_points,
  leaderboard.solved_case_count,
  leaderboard.correct_diagnosis_rate,
  stats.daily_streak,
  stats.success_rate_percent,
  settings.display_mode,
  settings.language,
  settings.text_size,
  settings.sound_and_haptics,
  settings.data_usage,
  settings.offline_mode,
  settings.case_downloads_enabled
from public.profiles
left join praticase.leaderboard_scores leaderboard on leaderboard.user_id = profiles.id
left join praticase.user_dashboard_stats stats on stats.user_id = profiles.id
left join praticase.user_app_settings settings on settings.user_id = profiles.id
where profiles.id = auth.uid();

create index if not exists management_plan_options_case_order_idx
  on praticase.management_plan_options (case_id, category, sort_order);
create index if not exists user_badges_user_earned_idx
  on praticase.user_badges (user_id, earned_at);
create index if not exists leaderboard_scores_points_idx
  on praticase.leaderboard_scores (total_points desc, solved_case_count desc);

commit;
