-- Unified PratiCase learning events for personalized medical education.
-- Captures theoretical misses/omissions plus OSCE/oral weak points without
-- changing shared Qlinik question tables.

begin;

create extension if not exists pgcrypto with schema extensions;
create schema if not exists praticase;

alter table praticase.user_case_recommendations
  add column if not exists source text not null default 'manual',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists updated_at timestamptz not null default now();

alter table praticase.user_case_recommendations
  drop constraint if exists user_case_recommendations_source_check;

alter table praticase.user_case_recommendations
  add constraint user_case_recommendations_source_check
  check (source in ('manual', 'admin', 'learning_events'));

create table if not exists praticase.user_learning_events (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null,
  exam_kind text not null check (
    exam_kind in ('theoretical', 'osce', 'oral_exam')
  ),
  outcome text not null check (
    outcome in (
      'incorrect',
      'omitted',
      'unsafe',
      'unnecessary',
      'missed',
      'partial',
      'low_score'
    )
  ),
  severity text not null default 'moderate' check (
    severity in ('critical', 'moderate', 'low')
  ),
  skill_code text not null default 'clinical_reasoning' check (
    skill_code in (
      'communication',
      'history',
      'physical',
      'tests',
      'diagnosis',
      'management',
      'clinical_reasoning',
      'exam_strategy',
      'knowledge'
    )
  ),
  branch text not null default '',
  topic text not null default '',
  concept_label text not null default '',
  session_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  question_id uuid,
  source_table text not null default '',
  source_id text not null default '',
  evidence text not null default '',
  user_action text not null default '',
  mentor_hint text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  occurrence_count integer not null default 1 check (occurrence_count > 0),
  occurred_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, event_key),
  constraint user_learning_events_metadata_check
    check (jsonb_typeof(metadata) = 'object')
);

alter table praticase.user_learning_events enable row level security;

drop policy if exists "Users can read own PratiCase learning events"
  on praticase.user_learning_events;
create policy "Users can read own PratiCase learning events"
on praticase.user_learning_events for select to authenticated
using (auth.uid() = user_id);

create index if not exists user_learning_events_user_latest_idx
  on praticase.user_learning_events(user_id, last_seen_at desc);

create index if not exists user_learning_events_user_exam_idx
  on praticase.user_learning_events(user_id, exam_kind, last_seen_at desc);

create index if not exists user_learning_events_user_skill_idx
  on praticase.user_learning_events(user_id, skill_code, severity);

create index if not exists user_learning_events_user_concept_idx
  on praticase.user_learning_events(user_id, branch, topic, concept_label);

create index if not exists user_case_recommendations_source_idx
  on praticase.user_case_recommendations(user_id, source, sort_order);

create or replace function praticase.learning_item_label(p_item jsonb)
returns text
language plpgsql
immutable
as $$
declare
  v_label text;
begin
  if p_item is null then
    return '';
  end if;

  if jsonb_typeof(p_item) = 'string' then
    return trim(p_item #>> '{}');
  end if;

  if jsonb_typeof(p_item) = 'object' then
    v_label := coalesce(
      p_item ->> 'title',
      p_item ->> 'label',
      p_item ->> 'name',
      p_item ->> 'question',
      p_item ->> 'item',
      p_item ->> 'text',
      p_item ->> 'description',
      p_item ->> 'reason'
    );
    return trim(coalesce(v_label, ''));
  end if;

  return trim(p_item #>> '{}');
end;
$$;

create or replace function praticase.learning_skill_label(p_skill_code text)
returns text
language sql
immutable
as $$
  select case coalesce(p_skill_code, '')
    when 'communication' then 'İletişim'
    when 'history' then 'Anamnez'
    when 'physical' then 'Fizik Muayene'
    when 'tests' then 'Tetkik'
    when 'diagnosis' then 'Tanı'
    when 'management' then 'Yönetim'
    when 'exam_strategy' then 'Sınav Stratejisi'
    when 'knowledge' then 'Teorik Bilgi'
    else 'Klinik Akıl Yürütme'
  end
$$;

create or replace function praticase.learning_skill_code_for_title(
  p_title text
)
returns text
language plpgsql
immutable
as $$
declare
  v_title text := lower(coalesce(p_title, ''));
begin
  if v_title like '%ileti%' then
    return 'communication';
  elsif v_title like '%anamnez%' or v_title like '%öykü%' then
    return 'history';
  elsif v_title like '%muayene%' or v_title like '%fizik%' then
    return 'physical';
  elsif v_title like '%tetk%' or v_title like '%test%' then
    return 'tests';
  elsif v_title like '%tanı%' or v_title like '%diagn%' then
    return 'diagnosis';
  elsif v_title like '%yönet%' or v_title like '%tedavi%' then
    return 'management';
  elsif v_title like '%bilgi%' or v_title like '%knowledge%' then
    return 'knowledge';
  end if;

  return 'clinical_reasoning';
end;
$$;

create or replace function praticase.record_user_learning_event(
  p_user_id uuid,
  p_event_key text,
  p_exam_kind text,
  p_outcome text,
  p_severity text default 'moderate',
  p_skill_code text default 'clinical_reasoning',
  p_branch text default '',
  p_topic text default '',
  p_concept_label text default '',
  p_session_id uuid default null,
  p_case_id uuid default null,
  p_question_id uuid default null,
  p_source_table text default '',
  p_source_id text default '',
  p_evidence text default '',
  p_user_action text default '',
  p_mentor_hint text default '',
  p_metadata jsonb default '{}'::jsonb,
  p_refresh_recommendations boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_id uuid;
  v_event_key text;
  v_exam_kind text;
  v_outcome text;
  v_severity text;
  v_skill_code text;
  v_metadata jsonb;
begin
  if p_user_id is null then
    return null;
  end if;

  v_exam_kind := case
    when p_exam_kind in ('theoretical', 'osce', 'oral_exam') then p_exam_kind
    else 'osce'
  end;
  v_outcome := case
    when p_outcome in (
      'incorrect',
      'omitted',
      'unsafe',
      'unnecessary',
      'missed',
      'partial',
      'low_score'
    ) then p_outcome
    else 'low_score'
  end;
  v_severity := case
    when p_severity in ('critical', 'moderate', 'low') then p_severity
    else 'moderate'
  end;
  v_skill_code := case
    when p_skill_code in (
      'communication',
      'history',
      'physical',
      'tests',
      'diagnosis',
      'management',
      'clinical_reasoning',
      'exam_strategy',
      'knowledge'
    ) then p_skill_code
    else 'clinical_reasoning'
  end;
  v_metadata := case
    when jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
      then coalesce(p_metadata, '{}'::jsonb)
    else '{}'::jsonb
  end;
  v_event_key := nullif(trim(coalesce(p_event_key, '')), '');
  if v_event_key is null then
    v_event_key :=
      v_exam_kind || ':' ||
      coalesce(p_source_table, '') || ':' ||
      coalesce(p_source_id, '') || ':' ||
      v_outcome || ':' ||
      md5(
        coalesce(p_concept_label, '') || ':' ||
        coalesce(p_topic, '') || ':' ||
        coalesce(p_branch, '')
      );
  end if;

  insert into praticase.user_learning_events as events (
    user_id,
    event_key,
    exam_kind,
    outcome,
    severity,
    skill_code,
    branch,
    topic,
    concept_label,
    session_id,
    case_id,
    question_id,
    source_table,
    source_id,
    evidence,
    user_action,
    mentor_hint,
    metadata,
    occurrence_count,
    occurred_at,
    last_seen_at,
    updated_at
  ) values (
    p_user_id,
    v_event_key,
    v_exam_kind,
    v_outcome,
    v_severity,
    v_skill_code,
    left(trim(coalesce(p_branch, '')), 160),
    left(trim(coalesce(p_topic, '')), 220),
    left(trim(coalesce(p_concept_label, '')), 220),
    p_session_id,
    p_case_id,
    p_question_id,
    left(trim(coalesce(p_source_table, '')), 120),
    left(trim(coalesce(p_source_id, '')), 160),
    left(trim(coalesce(p_evidence, '')), 1200),
    left(trim(coalesce(p_user_action, '')), 1200),
    left(trim(coalesce(p_mentor_hint, '')), 1200),
    v_metadata,
    1,
    now(),
    now(),
    now()
  )
  on conflict (user_id, event_key) do update set
    exam_kind = excluded.exam_kind,
    outcome = excluded.outcome,
    severity = excluded.severity,
    skill_code = excluded.skill_code,
    branch = excluded.branch,
    topic = excluded.topic,
    concept_label = excluded.concept_label,
    session_id = coalesce(excluded.session_id, events.session_id),
    case_id = coalesce(excluded.case_id, events.case_id),
    question_id = coalesce(excluded.question_id, events.question_id),
    source_table = excluded.source_table,
    source_id = excluded.source_id,
    evidence = coalesce(nullif(excluded.evidence, ''), events.evidence),
    user_action = coalesce(nullif(excluded.user_action, ''), events.user_action),
    mentor_hint = coalesce(nullif(excluded.mentor_hint, ''), events.mentor_hint),
    metadata = events.metadata || excluded.metadata,
    occurrence_count = events.occurrence_count + 1,
    last_seen_at = now(),
    updated_at = now()
  returning id into v_id;

  if p_refresh_recommendations then
    perform praticase.refresh_user_case_recommendations(p_user_id);
  end if;

  return v_id;
end;
$$;

create or replace function praticase.record_learning_items(
  p_user_id uuid,
  p_event_prefix text,
  p_exam_kind text,
  p_outcome text,
  p_severity text,
  p_skill_code text,
  p_items jsonb,
  p_branch text default '',
  p_topic text default '',
  p_session_id uuid default null,
  p_case_id uuid default null,
  p_question_id uuid default null,
  p_source_table text default '',
  p_source_id text default '',
  p_mentor_hint text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_item jsonb;
  v_index integer;
  v_label text;
  v_count integer := 0;
begin
  if jsonb_typeof(coalesce(p_items, '[]'::jsonb)) <> 'array' then
    return 0;
  end if;

  for v_item, v_index in
    select value, ordinality::integer
    from jsonb_array_elements(coalesce(p_items, '[]'::jsonb))
      with ordinality
  loop
    v_label := praticase.learning_item_label(v_item);
    if v_label = '' then
      continue;
    end if;

    perform praticase.record_user_learning_event(
      p_user_id => p_user_id,
      p_event_key => concat_ws(
        ':',
        nullif(trim(coalesce(p_event_prefix, '')), ''),
        p_skill_code,
        p_outcome,
        v_index::text,
        md5(v_label)
      ),
      p_exam_kind => p_exam_kind,
      p_outcome => p_outcome,
      p_severity => p_severity,
      p_skill_code => p_skill_code,
      p_branch => p_branch,
      p_topic => p_topic,
      p_concept_label => v_label,
      p_session_id => p_session_id,
      p_case_id => p_case_id,
      p_question_id => p_question_id,
      p_source_table => p_source_table,
      p_source_id => p_source_id,
      p_evidence => v_label,
      p_mentor_hint => p_mentor_hint,
      p_metadata => case
        when jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
          then p_metadata
        else '{}'::jsonb
      end || jsonb_build_object('raw_item', v_item),
      p_refresh_recommendations => false
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function praticase.record_score_gap_events(
  p_user_id uuid,
  p_event_prefix text,
  p_exam_kind text,
  p_category_scores jsonb,
  p_branch text default '',
  p_topic text default '',
  p_session_id uuid default null,
  p_case_id uuid default null,
  p_source_table text default '',
  p_source_id text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_item jsonb;
  v_title text;
  v_skill_code text;
  v_score numeric;
  v_max numeric;
  v_ratio numeric;
  v_count integer := 0;
begin
  if jsonb_typeof(coalesce(p_category_scores, '[]'::jsonb)) <> 'array' then
    return 0;
  end if;

  for v_item in
    select value from jsonb_array_elements(coalesce(p_category_scores, '[]'::jsonb))
  loop
    v_title := trim(coalesce(v_item ->> 'title', ''));
    v_score := case
      when coalesce(v_item ->> 'score', '') ~ '^-?[0-9]+(\.[0-9]+)?$'
        then (v_item ->> 'score')::numeric
      else 0
    end;
    v_max := case
      when coalesce(v_item ->> 'maxScore', '') ~ '^[0-9]+(\.[0-9]+)?$'
        then (v_item ->> 'maxScore')::numeric
      else 0
    end;

    if v_title = '' or coalesce(v_max, 0) <= 0 then
      continue;
    end if;

    v_ratio := coalesce(v_score, 0) / v_max;
    if v_ratio >= 0.6 then
      continue;
    end if;

    v_skill_code := praticase.learning_skill_code_for_title(v_title);
    perform praticase.record_user_learning_event(
      p_user_id => p_user_id,
      p_event_key => concat_ws(
        ':',
        nullif(trim(coalesce(p_event_prefix, '')), ''),
        'score',
        v_skill_code
      ),
      p_exam_kind => p_exam_kind,
      p_outcome => 'low_score',
      p_severity => case when v_ratio < 0.4 then 'critical' else 'moderate' end,
      p_skill_code => v_skill_code,
      p_branch => p_branch,
      p_topic => p_topic,
      p_concept_label => v_title,
      p_session_id => p_session_id,
      p_case_id => p_case_id,
      p_source_table => p_source_table,
      p_source_id => p_source_id,
      p_evidence => concat(
        v_title,
        ': ',
        coalesce(v_score, 0)::text,
        '/',
        v_max::text
      ),
      p_metadata => case
        when jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) = 'object'
          then p_metadata
        else '{}'::jsonb
      end || jsonb_build_object(
        'category_score', v_item,
        'score_ratio', v_ratio
      ),
      p_refresh_recommendations => false
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace view praticase.user_learning_gap_rollups
with (security_invoker = true) as
select
  events.user_id,
  events.exam_kind,
  events.skill_code,
  praticase.learning_skill_label(events.skill_code) as skill_label,
  coalesce(nullif(events.concept_label, ''), nullif(events.topic, ''), nullif(events.branch, ''), 'Genel') as concept_label,
  events.topic,
  events.branch,
  count(*)::integer as event_count,
  sum(events.occurrence_count)::integer as occurrence_count,
  count(*) filter (where events.severity = 'critical')::integer as critical_count,
  count(*) filter (where events.outcome = 'incorrect')::integer as incorrect_count,
  count(*) filter (where events.outcome = 'omitted')::integer as omitted_count,
  count(*) filter (where events.outcome = 'missed')::integer as missed_count,
  count(*) filter (where events.outcome = 'unnecessary')::integer as unnecessary_count,
  count(*) filter (where events.outcome = 'unsafe')::integer as unsafe_count,
  max(events.last_seen_at) as latest_seen_at,
  round(
    sum(
      events.occurrence_count *
      case events.severity
        when 'critical' then 3
        when 'moderate' then 2
        else 1
      end
    )::numeric,
    2
  ) as personalization_score
from praticase.user_learning_events events
group by
  events.user_id,
  events.exam_kind,
  events.skill_code,
  coalesce(nullif(events.concept_label, ''), nullif(events.topic, ''), nullif(events.branch, ''), 'Genel'),
  events.topic,
  events.branch;

create or replace function praticase.refresh_user_case_recommendations(
  p_user_id uuid
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_inserted integer := 0;
begin
  if p_user_id is null then
    return 0;
  end if;

  delete from praticase.user_case_recommendations
  where user_id = p_user_id
    and source = 'learning_events';

  with gaps as (
    select
      branch,
      topic,
      concept_label,
      skill_code,
      skill_label,
      personalization_score,
      event_count,
      critical_count,
      latest_seen_at
    from praticase.user_learning_gap_rollups
    where user_id = p_user_id
    order by personalization_score desc, latest_seen_at desc
    limit 12
  ),
  candidates as (
    select
      cases.id as case_id,
      max(
        (
          case
            when gaps.branch <> ''
              and lower(cases.branch) = lower(gaps.branch) then 10
            when gaps.branch <> ''
              and (
                lower(cases.branch) like '%' || lower(gaps.branch) || '%'
                or lower(gaps.branch) like '%' || lower(cases.branch) || '%'
              ) then 6
            else 0
          end +
          case
            when gaps.concept_label <> ''
              and lower(
                coalesce(cases.title, '') || ' ' ||
                coalesce(cases.summary, '') || ' ' ||
                coalesce(cases.candidate_prompt, '') || ' ' ||
                coalesce(cases.expected_history::text, '') || ' ' ||
                coalesce(cases.expected_physical_exam::text, '') || ' ' ||
                coalesce(cases.expected_tests::text, '') || ' ' ||
                coalesce(cases.management_steps::text, '')
              ) like '%' || lower(gaps.concept_label) || '%'
              then 7
            when gaps.topic <> ''
              and lower(
                coalesce(cases.title, '') || ' ' ||
                coalesce(cases.summary, '') || ' ' ||
                coalesce(cases.candidate_prompt, '')
              ) like '%' || lower(gaps.topic) || '%'
              then 4
            else 0
          end
        ) * (1 + gaps.personalization_score / 10.0)
      ) as score,
      (array_agg(gaps.concept_label order by gaps.personalization_score desc))[1] as concept_label,
      (array_agg(gaps.skill_label order by gaps.personalization_score desc))[1] as skill_label,
      (array_agg(gaps.branch order by gaps.personalization_score desc))[1] as branch,
      sum(gaps.event_count)::integer as event_count,
      sum(gaps.critical_count)::integer as critical_count
    from praticase.cases cases
    join gaps on true
    where cases.is_published
      and cases.slug like 'admin-%'
    group by cases.id
  ),
  ranked as (
    select
      case_id,
      concept_label,
      skill_label,
      branch,
      event_count,
      critical_count,
      row_number() over (
        order by score desc, critical_count desc, event_count desc, case_id
      ) as sort_order
    from candidates
    where score > 0
    limit 8
  ),
  inserted as (
    insert into praticase.user_case_recommendations as recommendations (
      user_id,
      case_id,
      sort_order,
      reason,
      source,
      metadata,
      created_at,
      updated_at
    )
    select
      p_user_id,
      ranked.case_id,
      ranked.sort_order,
      trim(concat_ws(
        ' ',
        'Kişisel eksiklerinden',
        nullif(ranked.concept_label, ''),
        '(' || nullif(ranked.skill_label, '') || ')',
        'için önerildi.'
      )),
      'learning_events',
      jsonb_build_object(
        'concept_label', ranked.concept_label,
        'skill_label', ranked.skill_label,
        'branch', ranked.branch,
        'event_count', ranked.event_count,
        'critical_count', ranked.critical_count
      ),
      now(),
      now()
    from ranked
    on conflict (user_id, case_id) do update set
      sort_order = excluded.sort_order,
      reason = excluded.reason,
      source = excluded.source,
      metadata = excluded.metadata,
      updated_at = now()
    where recommendations.source = 'learning_events'
    returning 1
  )
  select count(*)::integer into v_inserted from inserted;

  return coalesce(v_inserted, 0);
end;
$$;

create or replace function praticase.capture_osce_result_learning_events()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_user_id uuid;
  v_case_id uuid;
  v_case_title text;
  v_branch text;
  v_prefix text;
  v_count integer := 0;
begin
  select sessions.user_id, sessions.case_id, cases.title, cases.branch
    into v_user_id, v_case_id, v_case_title, v_branch
  from praticase.exam_sessions sessions
  join praticase.cases cases on cases.id = sessions.case_id
  where sessions.id = new.session_id;

  if v_user_id is null then
    return new;
  end if;

  v_prefix := 'osce:' || new.session_id::text;

  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':critical', 'osce', 'unsafe', 'critical',
    'clinical_reasoning', new.critical_mistakes, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Kritik güvenlik hatalarını kapat.', jsonb_build_object(
      'case_title', v_case_title,
      'percentage', new.percentage
    )
  );
  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':history', 'osce', 'missed', 'moderate',
    'history', new.missed_history, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Eksik anamnez başlıklarını sistematik listele.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':physical', 'osce', 'missed', 'moderate',
    'physical', new.missed_physical_exam, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Hedefe yönelik muayene seçimlerini tamamla.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':missed_tests', 'osce', 'missed', 'moderate',
    'tests', new.missed_tests, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Gerekli tetkikleri klinik gerekçeyle seç.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':unnecessary_tests', 'osce', 'unnecessary',
    'moderate', 'tests', new.unnecessary_tests, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Gereksiz tetkikleri azalt.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    v_user_id, v_prefix || ':improvement', 'osce', 'low_score', 'low',
    'clinical_reasoning', new.improvement_points, v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_result_summaries',
    new.session_id::text, 'Bir sonraki denemede bu öneriyi aktif hedef yap.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_score_gap_events(
    v_user_id, v_prefix, 'osce', new.category_scores, v_branch, v_case_title,
    new.session_id, v_case_id, 'session_result_summaries',
    new.session_id::text, '{}'::jsonb
  );

  if v_count > 0 then
    perform praticase.refresh_user_case_recommendations(v_user_id);
  end if;

  return new;
end;
$$;

drop trigger if exists capture_osce_result_learning_events
  on praticase.session_result_summaries;
create trigger capture_osce_result_learning_events
after insert or update on praticase.session_result_summaries
for each row execute function praticase.capture_osce_result_learning_events();

create or replace function praticase.capture_osce_ai_learning_events()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_case_id uuid;
  v_case_title text;
  v_branch text;
  v_feedback jsonb;
  v_prefix text;
  v_count integer := 0;
begin
  if new.status <> 'completed' or new.feedback is null then
    return new;
  end if;

  select sessions.case_id, cases.title, cases.branch
    into v_case_id, v_case_title, v_branch
  from praticase.exam_sessions sessions
  join praticase.cases cases on cases.id = sessions.case_id
  where sessions.id = new.session_id;

  v_feedback := case
    when jsonb_typeof(new.feedback) = 'object' then new.feedback
    else '{}'::jsonb
  end;
  v_prefix := 'osce_ai:' || new.session_id::text;

  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':critical', 'osce', 'unsafe', 'critical',
    'clinical_reasoning', v_feedback -> 'criticalMistakes', v_branch,
    v_case_title, new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne kritik hatalarını önceliklendir.',
    jsonb_build_object('prompt_version', new.prompt_version, 'model', new.model)
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':history', 'osce', 'missed', 'moderate',
    'history', v_feedback -> 'missedHistory', v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne eksik anamnezlerini hedefle.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':physical', 'osce', 'missed', 'moderate',
    'physical', v_feedback -> 'missedPhysicalExam', v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne muayene eksiklerini hedefle.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':missed_tests', 'osce', 'missed', 'moderate',
    'tests', v_feedback -> 'missedTests', v_branch, v_case_title,
    new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne gerekli tetkik eksiklerini hedefle.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':unnecessary_tests', 'osce', 'unnecessary',
    'moderate', 'tests', v_feedback -> 'unnecessaryTests', v_branch,
    v_case_title, new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne gereksiz tetkiklerini azalt.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':improvement', 'osce', 'low_score', 'low',
    'clinical_reasoning', v_feedback -> 'improvementPoints', v_branch,
    v_case_title, new.session_id, v_case_id, null, 'session_ai_enrichments',
    new.session_id::text, 'AI karne önerisini bir sonraki hedef yap.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_score_gap_events(
    new.user_id, v_prefix, 'osce', v_feedback -> 'categoryScores', v_branch,
    v_case_title, new.session_id, v_case_id, 'session_ai_enrichments',
    new.session_id::text, '{}'::jsonb
  );

  if v_count > 0 then
    perform praticase.refresh_user_case_recommendations(new.user_id);
  end if;

  return new;
end;
$$;

drop trigger if exists capture_osce_ai_learning_events
  on praticase.session_ai_enrichments;
create trigger capture_osce_ai_learning_events
after insert or update on praticase.session_ai_enrichments
for each row execute function praticase.capture_osce_ai_learning_events();

create or replace function praticase.capture_oral_session_learning_events()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_branch text;
  v_prefix text;
  v_scores jsonb;
  v_count integer := 0;
begin
  if new.status <> 'completed' then
    return new;
  end if;

  select title into v_branch
  from praticase.oral_exam_branches
  where id = new.branch_id;

  v_prefix := 'oral:' || new.id::text;
  v_scores := jsonb_build_array(
    jsonb_build_object('title', 'Klinik Akıl Yürütme', 'score', coalesce(new.reasoning_score, 0), 'maxScore', 40),
    jsonb_build_object('title', 'Teorik Bilgi', 'score', coalesce(new.knowledge_score, 0), 'maxScore', 30),
    jsonb_build_object('title', 'İletişim', 'score', coalesce(new.communication_score, 0), 'maxScore', 15),
    jsonb_build_object('title', 'Sınav Stratejisi', 'score', coalesce(new.pace_score, 0), 'maxScore', 10),
    jsonb_build_object('title', 'Profesyonellik', 'score', coalesce(new.professionalism_score, 0), 'maxScore', 5)
  );

  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':critical', 'oral_exam', 'unsafe', 'critical',
    'clinical_reasoning', new.critical_errors, coalesce(v_branch, ''),
    new.case_brief, new.id, null, null, 'oral_exam_sessions', new.id::text,
    'Sözlüde kritik hataları kapat.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':missed', 'oral_exam', 'missed', 'moderate',
    'clinical_reasoning', new.missed_points, coalesce(v_branch, ''),
    new.case_brief, new.id, null, null, 'oral_exam_sessions', new.id::text,
    'Sözlüde kaçan ana noktaları öncele.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':improvement', 'oral_exam', 'low_score', 'low',
    'clinical_reasoning', new.improvement_points, coalesce(v_branch, ''),
    new.case_brief, new.id, null, null, 'oral_exam_sessions', new.id::text,
    'Komite önerisini sonraki denemeye hedef yap.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_learning_items(
    new.user_id, v_prefix || ':plan', 'oral_exam', 'low_score', 'low',
    'exam_strategy', new.next_attempt_plan, coalesce(v_branch, ''),
    new.case_brief, new.id, null, null, 'oral_exam_sessions', new.id::text,
    'Bir sonraki deneme planını takip et.', '{}'::jsonb
  );
  v_count := v_count + praticase.record_score_gap_events(
    new.user_id, v_prefix, 'oral_exam', v_scores, coalesce(v_branch, ''),
    new.case_brief, new.id, null, 'oral_exam_sessions', new.id::text,
    '{}'::jsonb
  );

  if v_count > 0 then
    perform praticase.refresh_user_case_recommendations(new.user_id);
  end if;

  return new;
end;
$$;

drop trigger if exists capture_oral_session_learning_events
  on praticase.oral_exam_sessions;
create trigger capture_oral_session_learning_events
after insert or update on praticase.oral_exam_sessions
for each row execute function praticase.capture_oral_session_learning_events();

create or replace function praticase.capture_oral_turn_learning_events()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_session praticase.oral_exam_sessions%rowtype;
  v_branch text;
  v_eval jsonb;
  v_prefix text;
  v_moderation text;
  v_score_delta integer;
  v_count integer := 0;
begin
  if new.evaluation is null
     or jsonb_typeof(new.evaluation) <> 'object'
     or new.evaluation = '{}'::jsonb then
    return new;
  end if;

  select * into v_session
  from praticase.oral_exam_sessions
  where id = new.session_id;

  if v_session.user_id is null then
    return new;
  end if;

  select title into v_branch
  from praticase.oral_exam_branches
  where id = v_session.branch_id;

  v_eval := new.evaluation;
  v_prefix := 'oral_turn:' || new.id::text;
  v_moderation := coalesce(v_eval ->> 'moderation', '');
  v_score_delta := case
    when coalesce(v_eval ->> 'score_delta', '') ~ '^-?[0-9]+$'
      then (v_eval ->> 'score_delta')::integer
    else 0
  end;

  v_count := v_count + praticase.record_learning_items(
    v_session.user_id, v_prefix || ':missing', 'oral_exam', 'missed',
    'moderate', 'clinical_reasoning', v_eval -> 'missing_points',
    coalesce(v_branch, ''), v_session.case_brief, v_session.id, null, null,
    'oral_exam_turns', new.id::text,
    'Bu turdaki eksik akıl yürütme başlıklarını kapat.',
    jsonb_build_object('sequence', new.sequence, 'moderation', v_moderation)
  );
  v_count := v_count + praticase.record_learning_items(
    v_session.user_id, v_prefix || ':safety', 'oral_exam', 'unsafe',
    'critical', 'clinical_reasoning', v_eval -> 'safety_flags',
    coalesce(v_branch, ''), v_session.case_brief, v_session.id, null, null,
    'oral_exam_turns', new.id::text,
    'Güvenlik bayrağı üreten yanıtları düzelt.',
    jsonb_build_object('sequence', new.sequence, 'moderation', v_moderation)
  );

  if v_moderation = 'unsafe' then
    perform praticase.record_user_learning_event(
      p_user_id => v_session.user_id,
      p_event_key => v_prefix || ':unsafe',
      p_exam_kind => 'oral_exam',
      p_outcome => 'unsafe',
      p_severity => 'critical',
      p_skill_code => 'clinical_reasoning',
      p_branch => coalesce(v_branch, ''),
      p_topic => v_session.case_brief,
      p_concept_label => 'Güvenli olmayan sözlü yanıt',
      p_session_id => v_session.id,
      p_source_table => 'oral_exam_turns',
      p_source_id => new.id::text,
      p_evidence => coalesce(v_eval ->> 'reasoning', new.message, ''),
      p_mentor_hint => 'Güvenli yaklaşımı ve kırmızı bayrakları netleştir.',
      p_metadata => jsonb_build_object('sequence', new.sequence, 'evaluation', v_eval),
      p_refresh_recommendations => false
    );
    v_count := v_count + 1;
  elsif v_score_delta < 0 then
    perform praticase.record_user_learning_event(
      p_user_id => v_session.user_id,
      p_event_key => v_prefix || ':score_delta',
      p_exam_kind => 'oral_exam',
      p_outcome => 'low_score',
      p_severity => case when v_score_delta <= -5 then 'moderate' else 'low' end,
      p_skill_code => 'clinical_reasoning',
      p_branch => coalesce(v_branch, ''),
      p_topic => v_session.case_brief,
      p_concept_label => 'Tur bazlı puan kaybı',
      p_session_id => v_session.id,
      p_source_table => 'oral_exam_turns',
      p_source_id => new.id::text,
      p_evidence => coalesce(v_eval ->> 'reasoning', ''),
      p_mentor_hint => 'Cevabını klinik gerekçe ve güvenli yönetimle destekle.',
      p_metadata => jsonb_build_object('sequence', new.sequence, 'evaluation', v_eval),
      p_refresh_recommendations => false
    );
    v_count := v_count + 1;
  end if;

  if v_count > 0 then
    perform praticase.refresh_user_case_recommendations(v_session.user_id);
  end if;

  return new;
end;
$$;

drop trigger if exists capture_oral_turn_learning_events
  on praticase.oral_exam_turns;
create trigger capture_oral_turn_learning_events
after insert or update on praticase.oral_exam_turns
for each row execute function praticase.capture_oral_turn_learning_events();

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
  ) as is_bookmarked,
  recommendations.reason,
  recommendations.source,
  recommendations.metadata
from praticase.user_case_recommendations as recommendations
join praticase.cases as cases on cases.id = recommendations.case_id
where cases.is_published
  and cases.slug like 'admin-%';

grant select on praticase.user_learning_events to authenticated, service_role;
grant select on praticase.user_learning_gap_rollups to authenticated, service_role;
grant select on praticase.user_recommended_cases to authenticated, service_role;
grant all on praticase.user_learning_events to service_role;
grant execute on function praticase.record_user_learning_event(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  uuid,
  uuid,
  uuid,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  boolean
) to service_role;
grant execute on function praticase.refresh_user_case_recommendations(uuid)
to service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605270003', '202605270003_praticase_personal_learning_events.sql')
on conflict (version) do nothing;

commit;
