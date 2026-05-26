-- Read-only analytics contract for the PratiCase God Mode admin panel.
-- The views intentionally expose aggregate operational data only. Session
-- transcripts, result narratives, user identities and subscription links are
-- not included in this surface.

begin;

alter table praticase.oral_exam_personas
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

alter table praticase.oral_exam_scenarios
  add column if not exists is_active boolean not null default true,
  add column if not exists updated_at timestamptz not null default now();

alter table praticase.contact_requests
  add column if not exists updated_at timestamptz not null default now();

drop policy if exists "Public can read oral exam personas"
  on praticase.oral_exam_personas;
drop policy if exists "Public can read active oral exam personas"
  on praticase.oral_exam_personas;
create policy "Public can read active oral exam personas"
on praticase.oral_exam_personas for select to anon, authenticated
using (is_active);

drop policy if exists "Public can read oral exam scenarios"
  on praticase.oral_exam_scenarios;
drop policy if exists "Public can read active oral exam scenarios"
  on praticase.oral_exam_scenarios;
create policy "Public can read active oral exam scenarios"
on praticase.oral_exam_scenarios for select to anon, authenticated
using (is_active);

create index if not exists exam_sessions_god_mode_funnel_idx
  on praticase.exam_sessions (started_at desc, status, mode, current_step);

create index if not exists oral_exam_sessions_god_mode_funnel_idx
  on praticase.oral_exam_sessions (
    started_at desc,
    status,
    exam_format,
    persona_id,
    scenario_id
  );

create index if not exists contact_requests_god_mode_open_idx
  on praticase.contact_requests (status, created_at desc);

create index if not exists oral_exam_personas_active_order_idx
  on praticase.oral_exam_personas (is_active, sort_order);

create index if not exists oral_exam_scenarios_active_branch_idx
  on praticase.oral_exam_scenarios (is_active, branch_id, sort_order);

create or replace view praticase.god_mode_case_publication_v
with (security_invoker = true) as
with content_counts as (
  select
    cases.id as case_id,
    (select count(*) from praticase.praticase_history_checklists c where c.case_id = cases.id) as history_count,
    (select count(*) from praticase.praticase_physical_exam_checklists c where c.case_id = cases.id) as physical_exam_count,
    (select count(*) from praticase.praticase_laboratory_checklists c where c.case_id = cases.id) as laboratory_count,
    (select count(*) from praticase.praticase_imaging_checklists c where c.case_id = cases.id) as imaging_count,
    (select count(*) from praticase.praticase_diagnostic_checklists c where c.case_id = cases.id) as diagnostic_count
  from praticase.cases cases
)
select
  cases.id as case_id,
  cases.slug,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.is_published,
  counts.history_count,
  counts.physical_exam_count,
  counts.laboratory_count,
  counts.imaging_count,
  counts.diagnostic_count,
  (
    counts.history_count +
    counts.physical_exam_count +
    counts.laboratory_count +
    counts.imaging_count +
    counts.diagnostic_count
  )::integer as checklist_record_count,
  array_remove(array[
    case when counts.history_count = 0 then 'history' end,
    case when counts.physical_exam_count = 0 then 'physical_exam' end,
    case when counts.laboratory_count = 0 then 'laboratory' end,
    case when counts.imaging_count = 0 then 'imaging' end,
    case when counts.diagnostic_count = 0 then 'diagnostic' end
  ]::text[], null) as missing_content_types,
  case
    when cases.slug not like 'admin-%' then 'legacy_content'
    when cases.is_published
      and counts.history_count > 0
      and counts.physical_exam_count > 0
      and counts.laboratory_count > 0
      and counts.imaging_count > 0
      and counts.diagnostic_count > 0 then 'healthy'
    when cases.is_published then 'published_incomplete'
    when counts.history_count > 0
      and counts.physical_exam_count > 0
      and counts.laboratory_count > 0
      and counts.imaging_count > 0
      and counts.diagnostic_count > 0 then 'ready_unpublished'
    else 'draft_incomplete'
  end as health_status,
  cases.created_at,
  cases.updated_at
from praticase.cases cases
join content_counts counts on counts.case_id = cases.id;

create or replace view praticase.god_mode_osce_funnel_v
with (security_invoker = true) as
select
  timezone('UTC', sessions.started_at)::date as metric_day,
  sessions.mode,
  sessions.case_id,
  cases.title as case_title,
  cases.branch as case_branch,
  count(*)::integer as started_count,
  count(*) filter (where sessions.status = 'completed')::integer as completed_count,
  count(*) filter (where sessions.status = 'abandoned')::integer as abandoned_count,
  count(*) filter (where sessions.status = 'active')::integer as active_count,
  round(
    100.0 * count(*) filter (where sessions.status = 'completed') /
    nullif(count(*), 0),
    2
  ) as completion_rate_percent,
  round(avg(results.percentage) filter (where sessions.status = 'completed'), 2)
    as average_completed_score
from praticase.exam_sessions sessions
join praticase.cases cases on cases.id = sessions.case_id
left join praticase.session_result_summaries results
  on results.session_id = sessions.id
group by
  timezone('UTC', sessions.started_at)::date,
  sessions.mode,
  sessions.case_id,
  cases.title,
  cases.branch;

create or replace view praticase.god_mode_oral_funnel_v
with (security_invoker = true) as
select
  timezone('UTC', sessions.started_at)::date as metric_day,
  sessions.exam_format,
  sessions.persona_id,
  sessions.branch_id,
  sessions.scenario_id,
  count(*)::integer as started_count,
  count(*) filter (where sessions.status = 'completed')::integer as completed_count,
  count(*) filter (where sessions.status = 'abandoned')::integer as abandoned_count,
  count(*) filter (where sessions.status = 'active')::integer as active_count,
  round(
    100.0 * count(*) filter (where sessions.status = 'completed') /
    nullif(count(*), 0),
    2
  ) as completion_rate_percent,
  round(avg(sessions.total_score) filter (where sessions.status = 'completed'), 2)
    as average_completed_score
from praticase.oral_exam_sessions sessions
group by
  timezone('UTC', sessions.started_at)::date,
  sessions.exam_format,
  sessions.persona_id,
  sessions.branch_id,
  sessions.scenario_id;

create or replace view praticase.god_mode_score_distribution_v
with (security_invoker = true) as
with scored_sessions as (
  select
    timezone('UTC', sessions.ended_at)::date as metric_day,
    'osce'::text as exam_kind,
    results.percentage::integer as score
  from praticase.exam_sessions sessions
  join praticase.session_result_summaries results on results.session_id = sessions.id
  where sessions.status = 'completed'
    and sessions.ended_at is not null
  union all
  select
    timezone('UTC', sessions.ended_at)::date as metric_day,
    'oral_exam'::text as exam_kind,
    round(
      sessions.total_score::numeric * 100 /
      nullif(sessions.max_score, 0)
    )::integer as score
  from praticase.oral_exam_sessions sessions
  where sessions.status = 'completed'
    and sessions.ended_at is not null
    and sessions.total_score is not null
)
select
  metric_day,
  exam_kind,
  case
    when score < 20 then '00-19'
    when score < 40 then '20-39'
    when score < 60 then '40-59'
    when score < 80 then '60-79'
    else '80-100'
  end as score_band,
  count(*)::integer as session_count,
  round(avg(score), 2) as average_score
from scored_sessions
group by
  metric_day,
  exam_kind,
  case
    when score < 20 then '00-19'
    when score < 40 then '20-39'
    when score < 60 then '40-59'
    when score < 80 then '60-79'
    else '80-100'
  end;

create or replace view praticase.god_mode_dropoff_v
with (security_invoker = true) as
with oral_turn_counts as (
  select
    turns.session_id,
    count(*) filter (where turns.speaker = 'candidate')::integer
      as candidate_turn_count
  from praticase.oral_exam_turns turns
  group by turns.session_id
),
dropoffs as (
  select
    timezone('UTC', sessions.started_at)::date as metric_day,
    'osce'::text as exam_kind,
    sessions.current_step as dropoff_step,
    'explicit_abandonment'::text as abandonment_type
  from praticase.exam_sessions sessions
  where sessions.status = 'abandoned'
  union all
  select
    timezone('UTC', sessions.started_at)::date as metric_day,
    'oral_exam'::text as exam_kind,
    case
      when coalesce(turns.candidate_turn_count, 0) = 0 then 'before_first_answer'
      else 'after_candidate_answer'
    end as dropoff_step,
    'explicit_abandonment'::text as abandonment_type
  from praticase.oral_exam_sessions sessions
  left join oral_turn_counts turns on turns.session_id = sessions.id
  where sessions.status = 'abandoned'
)
select
  metric_day,
  exam_kind,
  dropoff_step,
  abandonment_type,
  count(*)::integer as session_count
from dropoffs
group by metric_day, exam_kind, dropoff_step, abandonment_type;

create or replace view praticase.god_mode_active_banners_v
with (security_invoker = true) as
select
  banners.id as banner_id,
  banners.title,
  banners.cta_label,
  banners.cta_route,
  banners.deep_link,
  banners.sort_order,
  banners.is_active,
  banners.starts_at,
  banners.ends_at,
  case
    when not banners.is_active then 'inactive'
    when banners.starts_at is not null and banners.starts_at > now() then 'scheduled'
    when banners.ends_at is not null and banners.ends_at < now() then 'expired'
    else 'live'
  end as delivery_status,
  (
    banners.is_active
    and (banners.starts_at is null or banners.starts_at <= now())
    and (banners.ends_at is null or banners.ends_at >= now())
  ) as is_live_now,
  banners.updated_at
from praticase.home_banners banners;

create or replace view praticase.god_mode_open_support_v
with (security_invoker = true) as
select
  coalesce(nullif(trim(requests.status), ''), 'open') as status,
  timezone('UTC', requests.created_at)::date as opened_day,
  count(*)::integer as request_count,
  min(requests.created_at) as oldest_opened_at,
  max(requests.created_at) as newest_opened_at
from praticase.contact_requests requests
where coalesce(nullif(trim(requests.status), ''), 'open')
  not in ('resolved', 'closed')
group by
  coalesce(nullif(trim(requests.status), ''), 'open'),
  timezone('UTC', requests.created_at)::date;

create or replace view praticase.god_mode_content_health_v
with (security_invoker = true) as
select
  'case'::text as entity_type,
  publication.case_id::text as entity_key,
  publication.title,
  publication.is_published as is_active,
  publication.health_status,
  publication.missing_content_types as issue_codes,
  publication.updated_at
from praticase.god_mode_case_publication_v publication
union all
select
  'banner',
  banners.banner_id::text,
  banners.title,
  banners.is_active,
  case
    when nullif(trim(coalesce(banners.cta_route, banners.deep_link, '')), '') is null
      then 'missing_route'
    when banners.delivery_status = 'expired' then 'expired'
    else 'healthy'
  end,
  array_remove(array[
    case when nullif(trim(coalesce(banners.cta_route, banners.deep_link, '')), '') is null
      then 'missing_route' end,
    case when banners.delivery_status = 'expired' then 'expired' end
  ]::text[], null),
  banners.updated_at
from praticase.god_mode_active_banners_v banners
union all
select
  'exam_mode',
  modes.id,
  modes.title,
  modes.is_active,
  case
    when nullif(trim(modes.action_key), '') is null then 'missing_action'
    else 'healthy'
  end,
  array_remove(array[
    case when nullif(trim(modes.action_key), '') is null then 'missing_action' end
  ]::text[], null),
  modes.updated_at
from praticase.exam_mode_cards modes
union all
select
  'oral_persona',
  personas.id,
  personas.title,
  personas.is_active,
  case
    when nullif(trim(personas.system_prompt), '') is null then 'missing_prompt'
    else 'healthy'
  end,
  array_remove(array[
    case when nullif(trim(personas.system_prompt), '') is null then 'missing_prompt' end
  ]::text[], null),
  personas.updated_at
from praticase.oral_exam_personas personas
union all
select
  'oral_scenario',
  scenarios.id,
  scenarios.title,
  scenarios.is_active,
  case
    when nullif(trim(scenarios.case_brief), '') is null then 'missing_case_brief'
    when jsonb_array_length(scenarios.expected_differentials) = 0
      then 'missing_differentials'
    else 'healthy'
  end,
  array_remove(array[
    case when nullif(trim(scenarios.case_brief), '') is null then 'missing_case_brief' end,
    case when jsonb_array_length(scenarios.expected_differentials) = 0
      then 'missing_differentials' end
  ]::text[], null),
  scenarios.updated_at
from praticase.oral_exam_scenarios scenarios
union all
select
  'store_mapping',
  mappings.product_code,
  mappings.product_code,
  mappings.is_active,
  case
    when nullif(trim(mappings.app_store_product_id), '') is null
      then 'missing_store_product_id'
    else 'healthy'
  end,
  array_remove(array[
    case when nullif(trim(mappings.app_store_product_id), '') is null
      then 'missing_store_product_id' end
  ]::text[], null),
  mappings.updated_at
from praticase.store_product_app_mappings mappings;

create or replace function praticase.god_mode_analytics_snapshot(
  p_from timestamptz default (now() - interval '30 days'),
  p_to timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path = praticase, public, extensions
as $$
begin
  if p_from is null or p_to is null or p_from >= p_to then
    raise exception using
      errcode = '22023',
      message = 'GOD_MODE_INVALID_DATE_RANGE';
  end if;
  if p_to - p_from > interval '366 days' then
    raise exception using
      errcode = '22023',
      message = 'GOD_MODE_DATE_RANGE_TOO_LARGE';
  end if;

  return jsonb_build_object(
    'contractVersion', 'praticase-god-mode-analytics-v1',
    'generatedAt', now(),
    'from', p_from,
    'to', p_to,
    'casePublication', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.updated_at desc)
      from praticase.god_mode_case_publication_v items
    ), '[]'::jsonb),
    'osceFunnel', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.metric_day desc)
      from praticase.god_mode_osce_funnel_v items
      where items.metric_day between timezone('UTC', p_from)::date
        and timezone('UTC', p_to)::date
    ), '[]'::jsonb),
    'oralFunnel', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.metric_day desc)
      from praticase.god_mode_oral_funnel_v items
      where items.metric_day between timezone('UTC', p_from)::date
        and timezone('UTC', p_to)::date
    ), '[]'::jsonb),
    'scoreDistribution', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.metric_day desc)
      from praticase.god_mode_score_distribution_v items
      where items.metric_day between timezone('UTC', p_from)::date
        and timezone('UTC', p_to)::date
    ), '[]'::jsonb),
    'dropoff', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.metric_day desc)
      from praticase.god_mode_dropoff_v items
      where items.metric_day between timezone('UTC', p_from)::date
        and timezone('UTC', p_to)::date
    ), '[]'::jsonb),
    'activeBanners', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.sort_order, items.updated_at desc)
      from praticase.god_mode_active_banners_v items
      where items.is_live_now
    ), '[]'::jsonb),
    'openSupport', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.oldest_opened_at)
      from praticase.god_mode_open_support_v items
    ), '[]'::jsonb),
    'contentHealth', coalesce((
      select jsonb_agg(to_jsonb(items) order by items.entity_type, items.entity_key)
      from praticase.god_mode_content_health_v items
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on
  praticase.god_mode_case_publication_v,
  praticase.god_mode_osce_funnel_v,
  praticase.god_mode_oral_funnel_v,
  praticase.god_mode_score_distribution_v,
  praticase.god_mode_dropoff_v,
  praticase.god_mode_active_banners_v,
  praticase.god_mode_open_support_v,
  praticase.god_mode_content_health_v
from public, anon, authenticated;

grant select on
  praticase.god_mode_case_publication_v,
  praticase.god_mode_osce_funnel_v,
  praticase.god_mode_oral_funnel_v,
  praticase.god_mode_score_distribution_v,
  praticase.god_mode_dropoff_v,
  praticase.god_mode_active_banners_v,
  praticase.god_mode_open_support_v,
  praticase.god_mode_content_health_v
to service_role;

revoke all on function praticase.god_mode_analytics_snapshot(timestamptz, timestamptz)
  from public, anon, authenticated;
grant execute on function praticase.god_mode_analytics_snapshot(timestamptz, timestamptz)
  to service_role;

comment on function praticase.god_mode_analytics_snapshot(timestamptz, timestamptz) is
  'Service-role-only aggregate analytics surface for PratiCase God Mode; excludes transcripts, narratives, user identity and subscription link data.';

insert into praticase.self_hosted_schema_migrations(version, filename)
values (
  '202605270001_praticase_god_mode_analytics',
  '202605270001_praticase_god_mode_analytics.sql'
)
on conflict (version) do nothing;

commit;
