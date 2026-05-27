-- Bridge PratiCase learning memory into the shared Medasi ecosystem memory.
-- Raw PratiCase detail stays in praticase.user_learning_events; other apps read
-- controlled core.learning_events / app summaries when the core schema exists.

begin;

create schema if not exists praticase;

do $$
begin
  if to_regclass('core.applications') is not null then
    execute $sql$
      insert into core.applications(code, name, kind, is_active, metadata)
      values (
        'praticase',
        'PratiCase',
        'app',
        true,
        jsonb_build_object(
          'product', 'OSCE, teorik ve sözlü sınav simülatörü',
          'memory_contract', 'praticase_learning_events_v2',
          'raw_detail_owner', 'praticase.user_learning_events',
          'exposed_surface', 'core.learning_events + core.user_app_memory_summaries'
        )
      )
      on conflict (code) do update set
        name = excluded.name,
        kind = excluded.kind,
        is_active = true,
        metadata = core.applications.metadata || excluded.metadata,
        updated_at = now()
    $sql$;
  end if;
end;
$$;

create index if not exists user_learning_events_source_idx
  on praticase.user_learning_events(source_table, source_id);

create index if not exists user_learning_events_user_outcome_idx
  on praticase.user_learning_events(user_id, outcome, severity, last_seen_at desc);

create or replace function praticase.learning_exam_kind_label(
  p_exam_kind text
)
returns text
language sql
immutable
as $$
  select case coalesce(p_exam_kind, '')
    when 'theoretical' then 'teorik'
    when 'oral_exam' then 'sözlü'
    else 'OSCE'
  end
$$;

create or replace function praticase.learning_core_event_type(
  p_exam_kind text,
  p_outcome text,
  p_skill_code text
)
returns text
language sql
immutable
as $$
  select regexp_replace(
    lower(
      concat_ws(
        '.',
        'praticase',
        case
          when p_exam_kind in ('theoretical', 'osce', 'oral_exam')
            then p_exam_kind
          else 'osce'
        end,
        case
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
        end,
        case
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
        end
      )
    ),
    '[^a-z0-9_.-]+',
    '_',
    'g'
  )
$$;

create or replace function praticase.learning_core_signal_strength(
  p_outcome text,
  p_severity text,
  p_occurrence_count integer default 1
)
returns numeric
language sql
immutable
as $$
  select round(
    (
      case coalesce(p_outcome, '')
        when 'unsafe' then -3.0
        when 'incorrect' then -2.2
        when 'omitted' then -2.0
        when 'missed' then -1.8
        when 'unnecessary' then -1.6
        when 'partial' then -1.0
        when 'low_score' then -1.2
        else -1.0
      end
      *
      case coalesce(p_severity, '')
        when 'critical' then 1.35
        when 'moderate' then 1.0
        else 0.7
      end
      *
      least(greatest(coalesce(p_occurrence_count, 1), 1), 10)
    )::numeric,
    3
  )
$$;

create or replace function praticase.learning_core_mastery_delta(
  p_outcome text,
  p_severity text
)
returns numeric
language sql
immutable
as $$
  select round(
    (
      case coalesce(p_outcome, '')
        when 'unsafe' then -0.34
        when 'incorrect' then -0.24
        when 'omitted' then -0.22
        when 'missed' then -0.20
        when 'unnecessary' then -0.16
        when 'partial' then -0.10
        when 'low_score' then -0.12
        else -0.10
      end
      *
      case coalesce(p_severity, '')
        when 'critical' then 1.25
        when 'moderate' then 1.0
        else 0.7
      end
    )::numeric,
    3
  )
$$;

create or replace function praticase.learning_core_entity_type(
  p_exam_kind text,
  p_source_table text,
  p_question_id uuid,
  p_case_id uuid,
  p_session_id uuid
)
returns text
language sql
immutable
as $$
  select case
    when p_question_id is not null then 'question'
    when p_case_id is not null then 'case'
    when coalesce(p_source_table, '') = 'oral_exam_turns' then 'oral_turn'
    when p_session_id is not null and p_exam_kind = 'oral_exam' then 'oral_session'
    when p_session_id is not null then 'osce_session'
    else 'learning_event'
  end
$$;

create or replace function praticase.learning_core_entity_id(
  p_event_id uuid,
  p_question_id uuid,
  p_case_id uuid,
  p_session_id uuid,
  p_source_id text
)
returns text
language sql
immutable
as $$
  select coalesce(
    p_question_id::text,
    p_case_id::text,
    p_session_id::text,
    nullif(trim(coalesce(p_source_id, '')), ''),
    p_event_id::text
  )
$$;

create or replace function praticase.learning_event_core_payload(
  p_event praticase.user_learning_events
)
returns jsonb
language plpgsql
stable
as $$
declare
  v_metadata jsonb := case
    when jsonb_typeof(coalesce(p_event.metadata, '{}'::jsonb)) = 'object'
      then coalesce(p_event.metadata, '{}'::jsonb)
    else '{}'::jsonb
  end;
  v_public_metadata jsonb;
begin
  v_public_metadata :=
    v_metadata
    - 'raw_metadata'
    - 'result'
    - 'evaluation'
    - 'question_text'
    - 'options'
    - 'option_rationales'
    - 'explanation'
    - 'selected_index'
    - 'selected_option_text'
    - 'selected_option_rationale'
    - 'correct_index'
    - 'correct_option_text'
    - 'correct_option_rationale'
    - 'raw_item';

  return jsonb_build_object(
    'schema_version', 'praticase_core_learning_event_v1',
    'event_id', p_event.id,
    'event_key', p_event.event_key,
    'exam_kind', p_event.exam_kind,
    'exam_kind_label', praticase.learning_exam_kind_label(p_event.exam_kind),
    'outcome', p_event.outcome,
    'severity', p_event.severity,
    'skill_code', p_event.skill_code,
    'skill_label', praticase.learning_skill_label(p_event.skill_code),
    'branch', nullif(p_event.branch, ''),
    'topic', nullif(p_event.topic, ''),
    'concept_label', nullif(p_event.concept_label, ''),
    'learning_sentence', nullif(p_event.learning_sentence, ''),
    'evidence', nullif(p_event.evidence, ''),
    'user_action', nullif(p_event.user_action, ''),
    'mentor_hint', nullif(p_event.mentor_hint, ''),
    'occurrence_count', p_event.occurrence_count,
    'raw_source_table', nullif(p_event.source_table, ''),
    'raw_source_id', nullif(p_event.source_id, ''),
    'session_id', p_event.session_id,
    'case_id', p_event.case_id,
    'question_id', p_event.question_id,
    'metadata', v_public_metadata
  );
end;
$$;

create or replace function praticase.push_learning_event_to_core(
  p_event_id uuid,
  p_refresh_rollups boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_event praticase.user_learning_events%rowtype;
  v_event_id uuid;
  v_metadata jsonb;
begin
  if p_event_id is null then
    return null;
  end if;

  if to_regproc('public.core_record_learning_event') is null then
    return null;
  end if;

  select *
    into v_event
  from praticase.user_learning_events
  where id = p_event_id;

  if v_event.id is null then
    return null;
  end if;

  v_metadata := case
    when jsonb_typeof(coalesce(v_event.metadata, '{}'::jsonb)) = 'object'
      then coalesce(v_event.metadata, '{}'::jsonb)
    else '{}'::jsonb
  end;

  v_event_id := public.core_record_learning_event(
    p_user_id => v_event.user_id,
    p_source_app_code => 'praticase',
    p_event_type => praticase.learning_core_event_type(
      v_event.exam_kind,
      v_event.outcome,
      v_event.skill_code
    ),
    p_occurred_at => coalesce(v_event.last_seen_at, v_event.occurred_at, now()),
    p_subject => nullif(v_event.branch, ''),
    p_topic => nullif(v_event.topic, ''),
    p_subtopic => nullif(v_event.concept_label, ''),
    p_difficulty => nullif(v_metadata ->> 'difficulty', ''),
    p_question_type => coalesce(
      nullif(v_metadata ->> 'question_type', ''),
      nullif(v_event.skill_code, '')
    ),
    p_cognitive_level => nullif(v_metadata ->> 'cognitive_level', ''),
    p_confidence_label => nullif(v_metadata ->> 'confidence', ''),
    p_signal_strength => praticase.learning_core_signal_strength(
      v_event.outcome,
      v_event.severity,
      v_event.occurrence_count
    ),
    p_mastery_delta => praticase.learning_core_mastery_delta(
      v_event.outcome,
      v_event.severity
    ),
    p_entity_type => praticase.learning_core_entity_type(
      v_event.exam_kind,
      v_event.source_table,
      v_event.question_id,
      v_event.case_id,
      v_event.session_id
    ),
    p_entity_id => praticase.learning_core_entity_id(
      v_event.id,
      v_event.question_id,
      v_event.case_id,
      v_event.session_id,
      v_event.source_id
    ),
    p_source_table => 'praticase.user_learning_events',
    p_source_id => v_event.id::text,
    p_payload => praticase.learning_event_core_payload(v_event),
    p_privacy_scope => 'ecosystem_personalization',
    p_refresh_rollups => coalesce(p_refresh_rollups, true)
  );

  return v_event_id;
exception
  when others then
    raise warning 'PratiCase core learning sync failed for event %: %',
      p_event_id,
      sqlerrm;
    return null;
end;
$$;

create or replace function praticase.praticase_app_memory_summary(
  p_user_id uuid,
  p_limit integer default 40
)
returns jsonb
language sql
stable
security definer
set search_path = praticase, public, extensions
as $$
  with authz as (
    select coalesce(auth.uid() = p_user_id, false)
      or coalesce(auth.role(), '') = 'service_role' as ok
  ),
  bounded as (
    select least(greatest(coalesce(p_limit, 40), 1), 120) as limit_value
  ),
  events as (
    select *
    from praticase.user_learning_events, authz
    where authz.ok
      and user_id = p_user_id
    order by last_seen_at desc
    limit (select limit_value from bounded)
  ),
  by_exam as (
    select
      exam_kind,
      count(*)::integer as event_count,
      sum(occurrence_count)::integer as occurrence_count,
      count(*) filter (where severity = 'critical')::integer as critical_count,
      max(last_seen_at) as latest_seen_at
    from events
    group by exam_kind
  ),
  top_gaps as (
    select
      exam_kind,
      skill_code,
      skill_label,
      concept_label,
      topic,
      branch,
      event_count,
      occurrence_count,
      critical_count,
      incorrect_count,
      omitted_count,
      missed_count,
      unnecessary_count,
      unsafe_count,
      personalization_score,
      latest_seen_at
    from praticase.user_learning_gap_rollups, authz
    where authz.ok
      and user_id = p_user_id
    order by personalization_score desc, latest_seen_at desc
    limit 12
  ),
  recent_sentences as (
    select
      event_id,
      exam_kind,
      outcome,
      severity,
      skill_code,
      skill_label,
      branch,
      topic,
      concept_label,
      learning_sentence,
      occurrence_count,
      last_seen_at
    from praticase.user_learning_history_sentences, authz
    where authz.ok
      and user_id = p_user_id
    order by last_seen_at desc
    limit (select limit_value from bounded)
  ),
  lead_gap as (
    select *
    from top_gaps
    order by personalization_score desc, latest_seen_at desc
    limit 1
  ),
  counts as (
    select
      count(*)::integer as event_count,
      coalesce(sum(occurrence_count), 0)::integer as occurrence_count,
      count(*) filter (where severity = 'critical')::integer as critical_count,
      max(last_seen_at) as latest_seen_at
    from events
  )
  select jsonb_build_object(
    'summary_sentence',
      coalesce(
        (
          select format(
            'PratiCase hafızasında kullanıcının öncelikli açığı %s %s alanında %s; toplam %s olay ve %s tekrar sinyali var.',
            praticase.learning_exam_kind_label(lead_gap.exam_kind),
            coalesce(nullif(lead_gap.skill_label, ''), 'klinik beceri'),
            coalesce(nullif(lead_gap.concept_label, ''), nullif(lead_gap.topic, ''), 'genel tekrar'),
            (select event_count from counts),
            (select occurrence_count from counts)
          )
          from lead_gap
        ),
        'PratiCase hafızasında henüz yeterli teorik, OSCE veya sözlü öğrenme sinyali yok.'
      ),
    'source', 'praticase',
    'schema_version', 'praticase_app_memory_v2',
    'user_id', p_user_id,
    'profile',
      coalesce((select to_jsonb(counts) from counts), '{}'::jsonb),
    'by_exam_kind',
      coalesce((select jsonb_agg(to_jsonb(by_exam)) from by_exam), '[]'::jsonb),
    'top_gaps',
      coalesce((select jsonb_agg(to_jsonb(top_gaps)) from top_gaps), '[]'::jsonb),
    'recent_sentences',
      coalesce(
        (select jsonb_agg(to_jsonb(recent_sentences)) from recent_sentences),
        '[]'::jsonb
      )
  )
$$;

create or replace function praticase.sync_praticase_app_memory_summary(
  p_user_id uuid,
  p_refresh_reason text default 'learning_event'
)
returns jsonb
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_summary jsonb;
  v_result jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'error', 'missing_user_id');
  end if;

  if to_regproc('public.core_upsert_app_memory_summary') is null then
    return jsonb_build_object('ok', false, 'error', 'core_memory_unavailable');
  end if;

  v_summary := praticase.praticase_app_memory_summary(p_user_id, 60);

  v_result := public.core_upsert_app_memory_summary(
    p_user_id => p_user_id,
    p_app_code => 'praticase',
    p_summary_sentence => coalesce(
      nullif(v_summary ->> 'summary_sentence', ''),
      'PratiCase hafızasında henüz yeterli öğrenme sinyali yok.'
    ),
    p_summary_json => v_summary,
    p_model => 'deterministic-praticase-db-v2',
    p_refresh_reason => coalesce(nullif(trim(p_refresh_reason), ''), 'learning_event'),
    p_stale_after => now() + interval '6 hours'
  );

  return coalesce(v_result, jsonb_build_object('ok', true));
exception
  when others then
    raise warning 'PratiCase app memory summary sync failed for user %: %',
      p_user_id,
      sqlerrm;
    return jsonb_build_object('ok', false, 'error', sqlerrm);
end;
$$;

create or replace function praticase.capture_learning_event_core_sync()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  perform praticase.push_learning_event_to_core(new.id, true);
  perform praticase.sync_praticase_app_memory_summary(
    new.user_id,
    'learning_event'
  );
  return new;
exception
  when others then
    raise warning 'PratiCase learning event core trigger failed for event %: %',
      new.id,
      sqlerrm;
    return new;
end;
$$;

drop trigger if exists capture_learning_event_core_sync
  on praticase.user_learning_events;
create trigger capture_learning_event_core_sync
after insert or update of
  exam_kind,
  outcome,
  severity,
  skill_code,
  branch,
  topic,
  concept_label,
  evidence,
  user_action,
  mentor_hint,
  metadata,
  occurrence_count,
  last_seen_at,
  learning_sentence
on praticase.user_learning_events
for each row execute function praticase.capture_learning_event_core_sync();

create or replace function praticase.rebuild_core_learning_memory_from_praticase(
  p_user_id uuid default null,
  p_refresh_rollups boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_event record;
  v_user record;
  v_synced_count integer := 0;
  v_user_count integer := 0;
begin
  if to_regproc('public.core_record_learning_event') is null then
    return jsonb_build_object(
      'ok', false,
      'error', 'core_memory_unavailable',
      'synced_count', 0
    );
  end if;

  for v_event in
    select id
    from praticase.user_learning_events
    where p_user_id is null or user_id = p_user_id
    order by last_seen_at asc
  loop
    perform praticase.push_learning_event_to_core(v_event.id, false);
    v_synced_count := v_synced_count + 1;
  end loop;

  for v_user in
    select distinct user_id
    from praticase.user_learning_events
    where p_user_id is null or user_id = p_user_id
  loop
    v_user_count := v_user_count + 1;

    if p_refresh_rollups
       and to_regproc('public.core_refresh_user_learning_memory') is not null then
      perform public.core_refresh_user_learning_memory(v_user.user_id);
    end if;

    perform praticase.sync_praticase_app_memory_summary(
      v_user.user_id,
      'backfill'
    );
  end loop;

  return jsonb_build_object(
    'ok', true,
    'source', 'praticase',
    'synced_count', v_synced_count,
    'user_count', v_user_count,
    'refresh_rollups', coalesce(p_refresh_rollups, true)
  );
end;
$$;

do $$
begin
  if to_regproc('public.core_record_learning_event') is not null then
    perform praticase.rebuild_core_learning_memory_from_praticase(null, true);
  end if;
end;
$$;

grant execute on function praticase.push_learning_event_to_core(uuid, boolean)
to service_role;

grant execute on function praticase.praticase_app_memory_summary(uuid, integer)
to authenticated, service_role;

grant execute on function praticase.sync_praticase_app_memory_summary(uuid, text)
to service_role;

grant execute on function praticase.rebuild_core_learning_memory_from_praticase(uuid, boolean)
to service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605270005', '202605270005_praticase_ecosystem_memory_bridge.sql')
on conflict (version) do nothing;

commit;
