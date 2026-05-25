-- Global options remain visible in every station, but an inappropriate
-- request must not produce an anatomically impossible report for the case.

begin;

create table if not exists praticase.case_global_test_result_overrides (
  case_id uuid not null references praticase.cases(id) on delete cascade,
  global_option_id text not null references praticase.global_test_options(id) on delete cascade,
  result text not null check (length(trim(result)) > 0),
  primary key (case_id, global_option_id)
);

alter table praticase.case_global_test_result_overrides enable row level security;

drop policy if exists "Published test result overrides are readable"
  on praticase.case_global_test_result_overrides;
create policy "Published test result overrides are readable"
on praticase.case_global_test_result_overrides for select to anon, authenticated
using (
  exists (
    select 1 from praticase.cases c
    where c.id = case_id and c.is_published
  )
);

grant select on praticase.case_global_test_result_overrides to anon, authenticated, service_role;
grant all on praticase.case_global_test_result_overrides to service_role;

insert into praticase.case_global_test_result_overrides(case_id, global_option_id, result)
values
  (
    '5959b3c7-069c-47bf-892a-ca89a153c2a1',
    'pelvik_usg',
    'Bu erkek travma hastasında pelvik/transvajinal USG uygun bir istem değildir; uterus veya adneks değerlendirmesi yapılamaz.'
  ),
  (
    '5959b3c7-069c-47bf-892a-ca89a153c2a1',
    'beta_hcg',
    'Bu erkek hasta için Beta-hCG istemi klinik olarak uygun değildir.'
  )
on conflict (case_id, global_option_id) do update set result = excluded.result;

create or replace view praticase.case_test_options_v
with (security_invoker = true) as
with case_groups as (
  select cases.id as case_id, g.id::text as case_group_id, g.title as group_title
  from praticase.cases cases
  join praticase.test_groups g on g.case_id = cases.id
  where cases.is_published
), case_options as (
  select
    cg.case_id,
    o.id::text as id,
    cg.case_group_id as group_id,
    o.title,
    o.result,
    o.point_cost,
    o.is_unnecessary,
    o.sort_order
  from case_groups cg
  join praticase.test_options o on o.group_id = cg.case_group_id::uuid
), global_groups as (
  select cases.id as case_id, g.id as global_group_id, g.title as group_title
  from praticase.cases cases
  cross join praticase.global_test_groups g
  where cases.is_published
), global_options as (
  select
    gg.case_id,
    'global:' || o.id as id,
    case
      when exists (
        select 1 from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
      ) then (
        select cg.case_group_id from case_groups cg
        where cg.case_id = gg.case_id
          and praticase.normalize_label(cg.group_title) = praticase.normalize_label(gg.group_title)
        limit 1
      )
      else 'global:' || gg.global_group_id
    end as group_id,
    o.title,
    coalesce(overrides.result, o.default_result) as result,
    0 as point_cost,
    false as is_unnecessary,
    o.sort_order + 1000 as sort_order
  from global_groups gg
  join praticase.global_test_options o on o.group_id = gg.global_group_id
  left join praticase.case_global_test_result_overrides overrides
    on overrides.case_id = gg.case_id and overrides.global_option_id = o.id
)
select * from case_options
union all
select * from global_options g
where not exists (
  select 1 from case_options c
  where c.case_id = g.case_id
    and c.group_id = g.group_id
    and praticase.normalize_label(c.title) = praticase.normalize_label(g.title)
);

grant select on praticase.case_test_options_v to anon, authenticated, service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605250002', '202605250002_praticase_catalog_case_results.sql')
on conflict (version) do nothing;

commit;
