begin;

alter table praticase.home_banners
  add column if not exists image_storage_path text,
  add column if not exists image_url text,
  add column if not exists image_alt_text text not null default '',
  add column if not exists deep_link text;

insert into storage.buckets(id, name, public)
values ('praticase-home', 'praticase-home', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can read PratiCase home media" on storage.objects;
create policy "Public can read PratiCase home media"
on storage.objects for select
using (bucket_id = 'praticase-home');

alter table praticase.user_app_settings
  add column if not exists target_exam text not null default 'OSCE',
  add column if not exists target_branches text[] not null default '{}',
  add column if not exists daily_goal integer not null default 1
    check (daily_goal between 1 and 20),
  add column if not exists osce_exam_date date;

alter table praticase.session_management_notes
  add column if not exists consultation_destination text not null default '';

create or replace function praticase.ensure_case_clinical_catalog(p_case_id uuid)
returns void
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_item record;
  v_group_id uuid;
begin
  update praticase.physical_exam_groups
  set title = case
    when lower(title) in ('neurological', 'neurologic', 'nörolojik muayene') then 'Nörolojik'
    when lower(title) in ('head_neck', 'baş boyun', 'baş-boyun muayenesi') then 'Baş-Boyun'
    when lower(title) in ('thorax', 'respiratory', 'toraks muayenesi') then 'Toraks / Solunum'
    when lower(title) in ('cardiovascular', 'kvs muayenesi') then 'Kardiyovasküler'
    when lower(title) in ('abdomen', 'batın muayenesi') then 'Batın'
    when lower(title) in ('extremity', 'ekstremite muayenesi') then 'Ekstremite / Kas-İskelet'
    when lower(title) in ('vitals', 'general', 'genel görünüm') then 'Genel Değerlendirme / Vital Bulgular'
    else title end
  where case_id = p_case_id;

  for v_item in
    select * from (values
      ('Genel Değerlendirme / Vital Bulgular', 'Genel değerlendirme ve vital bulgular', 'Hasta genel olarak stabil görünümde, vital bulgular normal sınırlarda.', 10),
      ('Baş-Boyun', 'Baş-boyun muayenesi', 'Baş-boyun muayenesinde patolojik bulgu saptanmadı.', 20),
      ('Toraks / Solunum', 'Toraks ve solunum muayenesi', 'Solunum sesleri doğal, ek solunum bulgusu yok.', 30),
      ('Kardiyovasküler', 'Kardiyovasküler muayene', 'Kalp sesleri doğal, periferik dolaşım bulguları normal.', 40),
      ('Batın', 'Batın muayenesi', 'Batın muayenesinde ek patolojik bulgu saptanmadı.', 50),
      ('Nörolojik', 'Nörolojik muayene', 'Nörolojik muayenede belirgin patolojik bulgu saptanmadı.', 60),
      ('Ekstremite / Kas-İskelet', 'Ekstremite muayenesi', 'Ekstremite ve kas-iskelet değerlendirmesi doğal.', 70)
    ) as defaults(title, option_title, finding, sort_order)
  loop
    select id into v_group_id from praticase.physical_exam_groups
    where case_id = p_case_id and title = v_item.title limit 1;
    if v_group_id is null then
      insert into praticase.physical_exam_groups(case_id, title, sort_order)
      values (p_case_id, v_item.title, v_item.sort_order)
      returning id into v_group_id;
    end if;
    if not exists (
      select 1 from praticase.physical_exam_options
      where group_id = v_group_id and title = v_item.option_title
    ) then
      insert into praticase.physical_exam_options(group_id, title, finding, point_value, is_critical, sort_order)
      values (v_group_id, v_item.option_title, v_item.finding, 0, false, 999);
    end if;
    v_group_id := null;
  end loop;

  for v_item in
    select * from (values
      ('Laboratuvar', 'Hemogram', 'Referans aralığı dışında anlamlı değer saptanmadı.', 10),
      ('Laboratuvar', 'CRP', 'Normal sınırlarda.', 20),
      ('Laboratuvar', 'Tam İdrar Tahlili', 'Patolojik bulgu saptanmadı.', 30),
      ('Görüntüleme', 'Ultrasonografi', 'Patolojik görüntüleme bulgusu saptanmadı.', 10),
      ('Görüntüleme', 'Bilgisayarlı Tomografi', 'Akut patolojik bulgu saptanmadı.', 20),
      ('Diğer', 'Elektrokardiyografi', 'Sinüs ritmi, akut patolojik değişiklik yok.', 10)
    ) as defaults(group_title, option_title, result_text, sort_order)
  loop
    select id into v_group_id from praticase.test_groups
    where case_id = p_case_id and title = v_item.group_title limit 1;
    if v_group_id is null then
      insert into praticase.test_groups(case_id, title, sort_order)
      values (
        p_case_id, v_item.group_title,
        case v_item.group_title when 'Laboratuvar' then 10 when 'Görüntüleme' then 20 else 30 end
      ) returning id into v_group_id;
    end if;
    if not exists (
      select 1 from praticase.test_options
      where group_id = v_group_id and title = v_item.option_title
    ) then
      insert into praticase.test_options(group_id, title, result, point_cost, is_unnecessary, sort_order)
      values (v_group_id, v_item.option_title, v_item.result_text, 0, false, v_item.sort_order);
    end if;
    v_group_id := null;
  end loop;
end;
$$;

create or replace function praticase.ensure_published_case_clinical_catalog()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  if new.is_published then
    perform praticase.ensure_case_clinical_catalog(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists ensure_published_case_clinical_catalog on praticase.cases;
create trigger ensure_published_case_clinical_catalog
after insert or update of is_published on praticase.cases
for each row execute function praticase.ensure_published_case_clinical_catalog();

do $$
declare v_case_id uuid;
begin
  for v_case_id in select id from praticase.cases where is_published loop
    perform praticase.ensure_case_clinical_catalog(v_case_id);
  end loop;
end $$;

update praticase.exam_mode_cards
set is_active = false, updated_at = now()
where id = 'branch_package';

update praticase.exam_mode_cards
set title = 'Teorik Sınav', updated_at = now()
where id = 'theoretical_exam';

create or replace function praticase.complete_user_profile(
  p_grade text,
  p_class_level text,
  p_target_exam text,
  p_target_branches text[],
  p_target text,
  p_daily_goal integer,
  p_exam_date timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_user auth.users%rowtype;
  v_now timestamptz := now();
  v_name text;
  v_parts text[];
begin
  select * into v_user from auth.users where id = auth.uid();
  if v_user.id is null then
    raise exception 'Authenticated user required';
  end if;

  v_name := trim(coalesce(v_user.raw_user_meta_data ->> 'full_name', ''));
  v_parts := regexp_split_to_array(v_name, '\s+');

  insert into public.profiles(
    id, email, first_name, last_name, class_level, target, theme_key,
    legal_terms_accepted_at, privacy_notice_accepted_at, consent_version,
    updated_at
  )
  values (
    v_user.id,
    v_user.email,
    nullif(v_parts[1], ''),
    nullif(array_to_string(v_parts[2:array_length(v_parts, 1)], ' '), ''),
    nullif(trim(p_class_level), ''),
    nullif(trim(p_target), ''),
    'clinical',
    v_now,
    v_now,
    coalesce(nullif(v_user.raw_user_meta_data ->> 'consent_version', ''), 'praticase-auth-v1'),
    v_now
  )
  on conflict (id) do update set
    email = excluded.email,
    first_name = coalesce(excluded.first_name, public.profiles.first_name),
    last_name = coalesce(excluded.last_name, public.profiles.last_name),
    class_level = excluded.class_level,
    target = excluded.target,
    legal_terms_accepted_at = coalesce(public.profiles.legal_terms_accepted_at, v_now),
    privacy_notice_accepted_at = coalesce(public.profiles.privacy_notice_accepted_at, v_now),
    consent_version = coalesce(public.profiles.consent_version, excluded.consent_version),
    updated_at = v_now;

  insert into praticase.user_app_settings(
    user_id, target_exam, target_branches, daily_goal, osce_exam_date, updated_at
  )
  values (
    v_user.id,
    coalesce(nullif(trim(p_target_exam), ''), 'OSCE'),
    coalesce(p_target_branches, '{}'),
    greatest(1, least(coalesce(p_daily_goal, 1), 20)),
    p_exam_date::date,
    v_now
  )
  on conflict (user_id) do update set
    target_exam = excluded.target_exam,
    target_branches = excluded.target_branches,
    daily_goal = excluded.daily_goal,
    osce_exam_date = excluded.osce_exam_date,
    updated_at = v_now;

  update auth.users
  set raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) ||
    jsonb_build_object(
      'praticase_profile_completed', true,
      'grade', p_grade,
      'target_branches', coalesce(p_target_branches, '{}'),
      'daily_goal', greatest(1, least(coalesce(p_daily_goal, 1), 20)),
      'osce_exam_date', p_exam_date
    ),
    updated_at = v_now
  where id = v_user.id;
end;
$$;

revoke all on function praticase.complete_user_profile(
  text, text, text, text[], text, integer, timestamptz
) from public, anon;
grant execute on function praticase.complete_user_profile(
  text, text, text, text[], text, integer, timestamptz
) to authenticated;

create table if not exists praticase.session_evaluation_snapshots (
  session_id uuid primary key references praticase.exam_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  case_id uuid not null references praticase.cases(id) on delete cascade,
  schema_version text not null default 'osce-evaluation-v1',
  rubric_version text not null default 'praticase-rubric-100-v1',
  evaluation_input jsonb not null,
  deterministic_result jsonb not null,
  created_at timestamptz not null default now()
);

create table if not exists praticase.session_ai_enrichments (
  session_id uuid primary key references praticase.exam_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'running', 'completed', 'failed')),
  provider text,
  model text,
  prompt_version text not null default 'osce-feedback-v1',
  schema_version text not null default 'osce-ai-enrichment-v1',
  feedback jsonb,
  usage_metadata jsonb not null default '{}'::jsonb,
  charged_coin_amount numeric(10, 4) not null default 0,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table praticase.session_evaluation_snapshots enable row level security;
alter table praticase.session_ai_enrichments enable row level security;

create policy "Users can read own evaluation snapshots"
on praticase.session_evaluation_snapshots for select to authenticated
using (auth.uid() = user_id);

create policy "Users can read own AI enrichments"
on praticase.session_ai_enrichments for select to authenticated
using (auth.uid() = user_id);

grant select on praticase.session_evaluation_snapshots to authenticated, service_role;
grant select on praticase.session_ai_enrichments to authenticated, service_role;
grant all on praticase.session_evaluation_snapshots to service_role;
grant all on praticase.session_ai_enrichments to service_role;

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

  select least(coalesce(sum(o.point_value), 0)::integer, 20) into v_physical
  from praticase.session_physical_exam_findings f
  join praticase.physical_exam_options o on o.id = f.option_id
  where f.session_id = p_session_id;

  select greatest(0, least(coalesce(sum(case when o.is_unnecessary then -5 else 5 end), 0)::integer, 15)),
    coalesce(jsonb_agg(o.title) filter (where o.is_unnecessary), '[]'::jsonb)
  into v_tests, v_unnecessary
  from praticase.session_requested_tests r
  join praticase.test_options o on o.id = r.option_id
  where r.session_id = p_session_id;

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

drop view if exists praticase.user_profile_cards cascade;
create view praticase.user_profile_cards
with (security_invoker = true) as
select
  profiles.id as user_id,
  coalesce(nullif(praticase.profile_display_name(profiles.id), ''), 'PratiCase Öğrencisi') as display_name,
  profiles.email,
  coalesce(nullif(profiles.class_level, ''), '5') as class_level,
  coalesce(nullif(profiles.target, ''), 'Staj + OSCE') as target,
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
  coalesce(settings.case_downloads_enabled, false) as case_downloads_enabled,
  coalesce(settings.target_exam, 'OSCE') as target_exam,
  coalesce(settings.target_branches, '{}') as target_branches,
  coalesce(settings.daily_goal, 1) as daily_goal,
  settings.osce_exam_date
from public.profiles profiles
left join praticase.leaderboard_scores leaderboard on leaderboard.user_id = profiles.id
left join praticase.user_dashboard_stats stats on stats.user_id = profiles.id
left join praticase.user_app_settings settings on settings.user_id = profiles.id
where profiles.id = auth.uid();
grant select on praticase.user_profile_cards to authenticated, service_role;

commit;
