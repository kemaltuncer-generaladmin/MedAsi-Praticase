begin;

alter table praticase.contact_requests
  drop constraint if exists contact_requests_subject_not_blank,
  add constraint contact_requests_subject_not_blank check (length(trim(subject)) >= 3),
  drop constraint if exists contact_requests_email_format,
  add constraint contact_requests_email_format check (
    email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  ),
  drop constraint if exists contact_requests_message_not_blank,
  add constraint contact_requests_message_not_blank check (length(trim(message)) >= 10);

alter table praticase.user_notes
  drop constraint if exists user_notes_body_not_blank,
  add constraint user_notes_body_not_blank check (length(trim(body)) > 0);

create or replace view praticase.user_profile_cards
with (security_invoker = true) as
select
  profiles.id as user_id,
  trim(coalesce(profiles.first_name, '') || ' ' || coalesce(profiles.last_name, '')) as display_name,
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

create or replace view praticase.user_note_cards
with (security_invoker = true) as
select
  notes.id,
  notes.title,
  notes.body,
  notes.category,
  notes.updated_at,
  cases.title as case_title
from praticase.user_notes notes
left join praticase.cases cases on cases.id = notes.case_id
where notes.user_id = auth.uid()
order by notes.updated_at desc;

grant usage on schema praticase to anon, authenticated, service_role;
grant select on all tables in schema praticase to anon, authenticated, service_role;
grant insert, update, delete on all tables in schema praticase to authenticated, service_role;
grant usage, select on all sequences in schema praticase to authenticated, service_role;

commit;
