-- OSCE karnesinde "ne sormalıydım / ne istemeliydim" ayrıntıları canlı
-- sonuç verisine yazılsın.

begin;

alter table praticase.session_result_summaries
  add column if not exists missed_tests jsonb not null default '[]'::jsonb;

create or replace function praticase.result_item_label(p_item jsonb)
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
      p_item ->> 'description'
    );
    return trim(coalesce(v_label, ''));
  end if;

  return trim(p_item #>> '{}');
end;
$$;

create or replace function praticase.refresh_result_detail_gaps()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_case_id uuid;
  v_transcript text := '';
  v_history_score integer := 0;
  v_history_max integer := 30;
begin
  select s.case_id into v_case_id
  from praticase.exam_sessions s
  where s.id = new.session_id;

  if v_case_id is null then
    return new;
  end if;

  select coalesce(string_agg(lower(m.message), ' '), '')
    into v_transcript
  from praticase.exam_messages m
  where m.session_id = new.session_id
    and m.sender = 'candidate';

  select
    coalesce((item ->> 'score')::integer, 0),
    coalesce((item ->> 'maxScore')::integer, 30)
    into v_history_score, v_history_max
  from jsonb_array_elements(coalesce(new.category_scores, '[]'::jsonb)) item
  where lower(item ->> 'title') like '%anamnez%'
  limit 1;

  if jsonb_array_length(coalesce(new.missed_history, '[]'::jsonb)) = 0
     and coalesce(v_history_score, 0) < coalesce(v_history_max, 30) then
    select coalesce(jsonb_agg(label), '[]'::jsonb)
      into new.missed_history
    from (
      select label
      from (
        select praticase.result_item_label(item) as label
        from praticase.cases c,
          lateral jsonb_array_elements(coalesce(c.expected_history, '[]'::jsonb)) item
        where c.id = v_case_id
      ) labels
      where label <> ''
        and (
          v_transcript = ''
          or position(praticase.normalize_label(label) in praticase.normalize_label(v_transcript)) = 0
        )
      limit 8
    ) missed;
  end if;

  if jsonb_array_length(coalesce(new.missed_physical_exam, '[]'::jsonb)) = 0 then
    select coalesce(jsonb_agg(title), '[]'::jsonb)
      into new.missed_physical_exam
    from (
      select o.title
      from praticase.case_physical_exam_options_v o
      where o.case_id = v_case_id
        and coalesce(o.point_value, 0) > 0
        and not exists (
          select 1
          from praticase.session_physical_exam_findings f
          where f.session_id = new.session_id
            and f.option_id::text = o.id::text
        )
      order by o.point_value desc, o.sort_order
      limit 8
    ) missed;
  end if;

  if jsonb_array_length(coalesce(new.missed_tests, '[]'::jsonb)) = 0 then
    select coalesce(jsonb_agg(title), '[]'::jsonb)
      into new.missed_tests
    from (
      with expected as (
        select praticase.result_item_label(item) as title
        from praticase.cases c,
          lateral jsonb_array_elements(coalesce(c.expected_tests, '[]'::jsonb)) item
        where c.id = v_case_id
      ),
      requested as (
        select praticase.normalize_label(coalesce(o.title, g.title, '')) as title
        from praticase.session_requested_tests r
        left join praticase.test_options o
          on r.option_id::text ~ '^[0-9a-fA-F-]{36}$'
         and o.id::text = r.option_id::text
        left join praticase.global_test_options g
          on r.option_id::text = 'global:' || g.id
        where r.session_id = new.session_id
      ),
      fallback_expected as (
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
      )
      select title
      from (
        select title from expected where title <> ''
        union
        select title from fallback_expected where title <> ''
      ) candidates
      where not exists (
        select 1
        from requested
        where requested.title = praticase.normalize_label(candidates.title)
      )
      limit 8
    ) missed;
  end if;

  if coalesce(trim(new.ideal_approach), '') = '' then
    new.ideal_approach :=
      'İdeal yaklaşım; yapılandırılmış anamnez, hedefe yönelik muayene, klinik gerekçeli tetkik istemi, ön tanı/ayırıcı tanı ve güvenli yönetim planını birlikte içerir.';
  end if;

  return new;
end;
$$;

drop trigger if exists refresh_result_detail_gaps
  on praticase.session_result_summaries;
create trigger refresh_result_detail_gaps
before insert or update on praticase.session_result_summaries
for each row execute function praticase.refresh_result_detail_gaps();

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
  summaries.ideal_approach
from praticase.session_result_summaries summaries
join praticase.exam_sessions sessions on sessions.id = summaries.session_id
join praticase.cases cases on cases.id = sessions.case_id
where sessions.user_id = auth.uid();

grant select on praticase.session_result_cards to authenticated, service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605250005', '202605250005_praticase_result_detail_gaps.sql')
on conflict (version) do nothing;

commit;
