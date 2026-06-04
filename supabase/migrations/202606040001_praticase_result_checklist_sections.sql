-- Sonuç raporunda Tam / Yarım / Sorulmadı checklist tablosu üret.

begin;

alter table praticase.session_result_summaries
  add column if not exists checklist_sections jsonb not null default '[]'::jsonb;

create or replace function praticase.result_checklist_text_status(
  p_label text,
  p_transcript text
)
returns text
language plpgsql
immutable
as $$
declare
  v_label text := praticase.normalize_label(coalesce(p_label, ''));
  v_text text := praticase.normalize_label(coalesce(p_transcript, ''));
  v_total integer := 0;
  v_matched integer := 0;
  v_ratio numeric := 0;
begin
  if v_label = '' or v_text = '' then
    return 'missed';
  end if;

  if position(v_label in v_text) > 0 then
    return 'covered';
  end if;

  select
    count(*)::integer,
    count(*) filter (where position(token.word in v_text) > 0)::integer
    into v_total, v_matched
  from regexp_split_to_table(v_label, '[[:space:]]+') as token(word)
  where length(token.word) >= 4;

  if coalesce(v_total, 0) = 0 then
    return 'missed';
  end if;

  v_ratio := coalesce(v_matched, 0)::numeric / v_total::numeric;
  if v_ratio >= 0.75 then
    return 'covered';
  elsif v_ratio >= 0.35 then
    return 'partial';
  end if;

  return 'missed';
end;
$$;

create or replace function praticase.result_checklist_sections(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_case_id uuid;
  v_transcript text := '';
  v_requested_tests text := '';
  v_history jsonb := '{}'::jsonb;
  v_physical jsonb := '{}'::jsonb;
  v_tests jsonb := '{}'::jsonb;
begin
  select s.case_id into v_case_id
  from praticase.exam_sessions s
  where s.id = p_session_id;

  if v_case_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(string_agg(m.message, ' ' order by m.created_at), '')
    into v_transcript
  from praticase.exam_messages m
  where m.session_id = p_session_id
    and m.sender = 'candidate';

  select coalesce(string_agg(coalesce(o.title, g.title, ''), ' '), '')
    into v_requested_tests
  from praticase.session_requested_tests r
  left join praticase.test_options o
    on r.option_id::text ~ '^[0-9a-fA-F-]{36}$'
   and o.id::text = r.option_id::text
  left join praticase.global_test_options g
    on r.option_id::text = 'global:' || g.id
  where r.session_id = p_session_id;

  with expected as (
    select
      ord::integer,
      praticase.result_item_label(item) as label
    from praticase.cases c,
      lateral jsonb_array_elements(coalesce(c.expected_history, '[]'::jsonb))
        with ordinality as history(item, ord)
    where c.id = v_case_id
  ),
  rows as (
    select
      ord,
      label,
      praticase.result_checklist_text_status(label, v_transcript) as status
    from expected
    where label <> ''
  )
  select jsonb_build_object(
    'title', 'Anamnez',
    'key', 'history',
    'coveredCount', count(*) filter (where status = 'covered'),
    'totalCount', count(*),
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'label', label,
      'status', status,
      'evidence', case
        when status = 'covered' then 'Transkriptte bu başlık tam karşılandı.'
        when status = 'partial' then 'Transkriptte konuya kısmen değinildi.'
        else ''
      end,
      'note', case
        when status = 'missed' then 'Bu anamnez başlığı sorulmadı.'
        when status = 'partial' then 'Başlık açıldı fakat derinleştirilmedi.'
        else ''
      end
    ) order by ord), '[]'::jsonb)
  ) into v_history
  from rows;

  with options as (
    select
      row_number() over (order by o.point_value desc, o.sort_order, o.title)
        as ord,
      o.id,
      o.title as label
    from praticase.case_physical_exam_options_v o
    where o.case_id = v_case_id
      and coalesce(o.point_value, 0) > 0
  ),
  rows as (
    select
      ord,
      label,
      case
        when exists (
          select 1
          from praticase.session_physical_exam_findings f
          where f.session_id = p_session_id
            and f.option_id::text = options.id::text
        ) then 'covered'
        else 'missed'
      end as status
    from options
    where label <> ''
  )
  select jsonb_build_object(
    'title', 'Fizik Muayene',
    'key', 'physical_exam',
    'coveredCount', count(*) filter (where status = 'covered'),
    'totalCount', count(*),
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'label', label,
      'status', status,
      'evidence', case
        when status = 'covered' then 'Muayene seçimlerinde işaretlendi.'
        else ''
      end,
      'note', case
        when status = 'missed' then 'Bu muayene seçilmedi.'
        else ''
      end
    ) order by ord), '[]'::jsonb)
  ) into v_physical
  from rows;

  with expected_from_case as (
    select praticase.result_item_label(item) as title
    from praticase.cases c,
      lateral jsonb_array_elements(coalesce(c.expected_tests, '[]'::jsonb))
        as tests(item)
    where c.id = v_case_id
  ),
  expected_from_catalog as (
    select coalesce(o.title, g.title) as title
    from praticase.case_global_test_relevance rel
    join praticase.global_test_options g
      on g.id = rel.global_option_id
    left join praticase.case_test_options_v o
      on o.case_id = rel.case_id
     and praticase.normalize_label(o.title) = praticase.normalize_label(g.title)
    where rel.case_id = v_case_id
      and rel.relevance = 'recommended'
      and rel.point_value > 0
  ),
  expected as (
    select
      row_number() over (order by title) as ord,
      title
    from (
      select title from expected_from_case where title <> ''
      union
      select title from expected_from_catalog where title <> ''
    ) all_expected
  ),
  requested as (
    select praticase.normalize_label(coalesce(o.title, g.title, '')) as title
    from praticase.session_requested_tests r
    left join praticase.test_options o
      on r.option_id::text ~ '^[0-9a-fA-F-]{36}$'
     and o.id::text = r.option_id::text
    left join praticase.global_test_options g
      on r.option_id::text = 'global:' || g.id
    where r.session_id = p_session_id
  ),
  rows as (
    select
      expected.ord,
      expected.title as label,
      case
        when exists (
          select 1
          from requested
          where requested.title = praticase.normalize_label(expected.title)
        ) then 'covered'
        else praticase.result_checklist_text_status(
          expected.title,
          v_requested_tests
        )
      end as status
    from expected
  )
  select jsonb_build_object(
    'title', 'Tetkikler',
    'key', 'tests',
    'coveredCount', count(*) filter (where status = 'covered'),
    'totalCount', count(*),
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'label', label,
      'status', status,
      'evidence', case
        when status = 'covered' then 'Tetkik seçimlerinde istendi.'
        when status = 'partial' then 'Benzer bir tetkik istendi.'
        else ''
      end,
      'note', case
        when status = 'missed' then 'Bu tetkik istenmedi.'
        when status = 'partial' then 'Tetkik başlığı tam karşılanmadı.'
        else ''
      end
    ) order by ord), '[]'::jsonb)
  ) into v_tests
  from rows;

  return coalesce((
    select jsonb_agg(section)
    from jsonb_array_elements(jsonb_build_array(v_history, v_physical, v_tests))
      as sections(section)
    where jsonb_array_length(coalesce(section -> 'items', '[]'::jsonb)) > 0
  ), '[]'::jsonb);
end;
$$;

create or replace function praticase.refresh_result_checklist_sections()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  if jsonb_array_length(coalesce(new.checklist_sections, '[]'::jsonb)) = 0 then
    new.checklist_sections :=
      praticase.result_checklist_sections(new.session_id);
  end if;
  return new;
end;
$$;

drop trigger if exists refresh_result_checklist_sections
  on praticase.session_result_summaries;
create trigger refresh_result_checklist_sections
before insert or update on praticase.session_result_summaries
for each row execute function praticase.refresh_result_checklist_sections();

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
  summaries.missed_tests,
  summaries.ideal_approach,
  case
    when jsonb_array_length(coalesce(summaries.checklist_sections, '[]'::jsonb))
      > 0 then summaries.checklist_sections
    else praticase.result_checklist_sections(summaries.session_id)
  end
    as checklist_sections
from praticase.session_result_summaries summaries
join praticase.exam_sessions sessions on sessions.id = summaries.session_id
join praticase.cases cases on cases.id = sessions.case_id
where sessions.user_id = auth.uid();

grant select on praticase.session_result_cards to authenticated, service_role;
grant execute on function praticase.result_checklist_text_status(text, text)
  to authenticated, service_role;
grant execute on function praticase.result_checklist_sections(uuid)
  to authenticated, service_role;
grant execute on function praticase.refresh_result_checklist_sections()
  to authenticated, service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202606040001', '202606040001_praticase_result_checklist_sections.sql')
on conflict (version) do nothing;

commit;
