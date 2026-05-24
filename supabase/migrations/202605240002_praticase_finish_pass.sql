begin;

create table if not exists public.ai_usage_events (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feature text not null,
  provider text not null default 'vertex_ai',
  model text not null,
  prompt_token_count integer not null default 0,
  candidates_token_count integer not null default 0,
  thoughts_token_count integer not null default 0,
  total_token_count integer not null default 0,
  cached_content_token_count integer not null default 0,
  input_cost_usd numeric(12, 6) not null default 0,
  output_cost_usd numeric(12, 6) not null default 0,
  total_cost_usd numeric(12, 6) not null default 0,
  charged_coin_amount numeric(10, 4) not null default 0,
  usage_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint ai_usage_events_feature_check check (length(trim(feature)) > 0),
  constraint ai_usage_events_model_check check (length(trim(model)) > 0),
  constraint ai_usage_events_usage_metadata_check check (jsonb_typeof(usage_metadata) = 'object')
);

create index if not exists ai_usage_events_user_created_idx
  on public.ai_usage_events(user_id, created_at desc);

alter table public.ai_usage_events enable row level security;

revoke all on public.ai_usage_events from public, anon, authenticated;
grant all on public.ai_usage_events to service_role;

drop policy if exists "ai usage events select own" on public.ai_usage_events;
create policy "ai usage events select own"
on public.ai_usage_events
for select
to authenticated
using (auth.uid() = user_id);

insert into praticase.home_banners(
  title,
  subtitle,
  cta_label,
  cta_route,
  sort_order,
  is_active
)
values
  (
    'Sesli Anamnez Modu',
    'Hasta yanıtlarını dinle, Türkçe sesle yazdır ve OSCE temposunu gerçek sınava yaklaştır.',
    'Sesli İstasyona Gir',
    '/cases',
    20,
    true
  ),
  (
    'Zayıf Alan Tekrarı',
    'AI karnesindeki eksik anamnez, muayene ve tetkik başlıklarından hedefli tekrar yap.',
    'Gelişimi Aç',
    '/progress',
    30,
    true
  ),
  (
    'Teorik Sınav Köprüsü',
    'Qlinik soru bankasından ders ve konu seçerek klinik performansını teoriyle destekle.',
    'Teorik Sınav',
    '/theoretical-exam',
    40,
    true
  );

insert into praticase.exam_mode_cards(
  id,
  title,
  subtitle,
  icon_key,
  action_key,
  sort_order,
  is_active
)
values (
  'theoretical_exam',
  'Teorik Sınav',
  'Qlinik soru bankasından ders, konu ve soru sayısı seçerek deneme oluştur.',
  'theoretical',
  'theoretical_exam',
  50,
  true
)
on conflict (id) do update set
  title = excluded.title,
  subtitle = excluded.subtitle,
  icon_key = excluded.icon_key,
  action_key = excluded.action_key,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

create or replace function praticase.profile_display_name(p_user_id uuid)
returns text
language sql
stable
security definer
set search_path = praticase, public, extensions
as $$
  select coalesce(
    nullif(trim(concat_ws(' ', profiles.first_name, profiles.last_name)), ''),
    nullif(trim(auth_users.raw_user_meta_data ->> 'full_name'), ''),
    'PratiCase Öğrencisi'
  )
  from auth.users auth_users
  left join public.profiles profiles on profiles.id = auth_users.id
  where auth_users.id = p_user_id
$$;

create or replace function praticase.apply_leaderboard_display_name()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  new.display_name := coalesce(
    nullif(praticase.profile_display_name(new.user_id), ''),
    'PratiCase Öğrencisi'
  );
  return new;
end;
$$;

drop trigger if exists apply_leaderboard_display_name
  on praticase.leaderboard_scores;

create trigger apply_leaderboard_display_name
before insert or update of user_id, display_name on praticase.leaderboard_scores
for each row
execute function praticase.apply_leaderboard_display_name();

update praticase.leaderboard_scores scores
set display_name = coalesce(
  nullif(praticase.profile_display_name(scores.user_id), ''),
  'PratiCase Öğrencisi'
);

drop view if exists praticase.user_profile_cards cascade;
create view praticase.user_profile_cards
with (security_invoker = true) as
select
  profiles.id as user_id,
  coalesce(
    nullif(praticase.profile_display_name(profiles.id), ''),
    'PratiCase Öğrencisi'
  ) as display_name,
  profiles.email,
  coalesce(nullif(profiles.class_level, ''), '5') as class_level,
  coalesce(nullif(profiles.target, ''), 'Staj + TUS') as target,
  coalesce(leaderboard.total_points, 0) as total_points,
  coalesce(leaderboard.solved_case_count, 0) as solved_case_count,
  coalesce(leaderboard.correct_diagnosis_rate, 0) as correct_diagnosis_rate,
  coalesce(stats.daily_streak, 0) as daily_streak,
  coalesce(stats.success_rate_percent, 0) as success_rate_percent,
  coalesce(settings.display_mode, 'Sistem') as display_mode,
  coalesce(settings.language, 'Türkçe') as language,
  coalesce(settings.text_size, 'Orta') as text_size,
  coalesce(settings.sound_and_haptics, true) as sound_and_haptics,
  coalesce(settings.data_usage, 'Standart') as data_usage,
  coalesce(settings.offline_mode, false) as offline_mode,
  coalesce(settings.case_downloads_enabled, false) as case_downloads_enabled
from public.profiles
left join praticase.leaderboard_scores leaderboard on leaderboard.user_id = profiles.id
left join praticase.user_dashboard_stats stats on stats.user_id = profiles.id
left join praticase.user_app_settings settings on settings.user_id = profiles.id
where profiles.id = auth.uid();
grant select on praticase.user_profile_cards to authenticated, service_role;

drop view if exists praticase.session_result_cards cascade;
create view praticase.session_result_cards
with (security_invoker = true) as
select
  summaries.session_id,
  cases.title as case_title,
  cases.branch as case_branch,
  sessions.ended_at,
  summaries.total_score,
  summaries.max_score,
  summaries.percentage,
  summaries.category_scores,
  summaries.strong_points,
  summaries.improvement_points,
  summaries.critical_mistakes,
  summaries.unnecessary_tests,
  summaries.missed_history,
  summaries.missed_physical_exam,
  summaries.ideal_approach
from praticase.session_result_summaries summaries
join praticase.exam_sessions sessions on sessions.id = summaries.session_id
join praticase.cases cases on cases.id = sessions.case_id
where sessions.user_id = auth.uid();
grant select on praticase.session_result_cards to authenticated, service_role;

alter table praticase.user_notifications
  add column if not exists campaign_id uuid,
  add column if not exists deep_link text;

create table if not exists praticase.notification_campaigns (
  id uuid primary key default extensions.gen_random_uuid(),
  title text not null check (length(trim(title)) > 0),
  body text not null default '',
  audience text not null default 'all' check (audience in ('all', 'users')),
  target_user_ids uuid[],
  deep_link text,
  is_active boolean not null default true,
  sent_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists user_notifications_campaign_user_idx
  on praticase.user_notifications(campaign_id, user_id)
  where campaign_id is not null;

create index if not exists notification_campaigns_created_idx
  on praticase.notification_campaigns(created_at desc);

alter table praticase.notification_campaigns enable row level security;

grant select, insert, update, delete on praticase.notification_campaigns to service_role;
grant execute on function praticase.profile_display_name(uuid) to authenticated, service_role;

create or replace function praticase.materialize_notification_campaign(
  p_campaign_id uuid
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_campaign praticase.notification_campaigns%rowtype;
  v_inserted integer := 0;
begin
  select *
    into v_campaign
  from praticase.notification_campaigns
  where id = p_campaign_id
    and is_active;

  if not found then
    raise exception 'Notification campaign not found';
  end if;

  with recipients as (
    select profiles.id as user_id
    from public.profiles
    where v_campaign.audience = 'all'
      or (
        v_campaign.audience = 'users'
        and profiles.id = any(coalesce(v_campaign.target_user_ids, array[]::uuid[]))
      )
  ),
  inserted as (
    insert into praticase.user_notifications(
      user_id,
      campaign_id,
      title,
      body,
      deep_link,
      created_at
    )
    select
      recipients.user_id,
      v_campaign.id,
      v_campaign.title,
      v_campaign.body,
      v_campaign.deep_link,
      now()
    from recipients
    on conflict do nothing
    returning 1
  )
  select count(*)::integer into v_inserted from inserted;

  update praticase.notification_campaigns
  set sent_at = coalesce(sent_at, now()),
      updated_at = now()
  where id = v_campaign.id;

  return v_inserted;
end;
$$;

grant execute on function praticase.materialize_notification_campaign(uuid)
  to service_role;

do $$
begin
  alter publication supabase_realtime add table praticase.user_notifications;
exception
  when duplicate_object or undefined_object then null;
end $$;

commit;
