begin;

-- The mobile app must expose only cases generated from the PratiCase admin
-- import flow. Legacy seed/demo cases are removed so they cannot appear in
-- the case library, home recommendations, favorites, or direct case reads.
delete from praticase.cases
where slug not like 'admin-%';

drop policy if exists "Public can read published PratiCase cases" on praticase.cases;
drop policy if exists "Public can read published admin-generated PratiCase cases" on praticase.cases;
create policy "Public can read published admin-generated PratiCase cases"
on praticase.cases for select
using (is_published and slug like 'admin-%');

create or replace view praticase.user_home_case_progress
with (security_invoker = true) as
select
  progress.user_id,
  progress.case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  progress.progress_percent,
  progress.updated_at
from praticase.user_case_progress as progress
join praticase.cases as cases on cases.id = progress.case_id
where progress.status = 'in_progress'
  and cases.is_published
  and cases.slug like 'admin-%';

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
  ) as is_bookmarked
from praticase.user_case_recommendations as recommendations
join praticase.cases as cases on cases.id = recommendations.case_id
where cases.is_published
  and cases.slug like 'admin-%';

create or replace view praticase.user_case_library
with (security_invoker = true) as
select
  cases.id as case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.setting,
  cases.duration_minutes,
  cases.points,
  cases.icon_key,
  cases.summary,
  cases.solved_count,
  progress.progress_percent,
  progress.last_score,
  exists (
    select 1 from praticase.user_bookmarked_cases bookmarks
    where bookmarks.user_id = auth.uid()
      and bookmarks.case_id = cases.id
  ) as is_bookmarked
from praticase.cases
left join praticase.user_case_progress progress
  on progress.case_id = cases.id
  and progress.user_id = auth.uid()
where cases.is_published
  and cases.slug like 'admin-%';

create or replace view praticase.user_favorite_cases
with (security_invoker = true) as
select
  cases.id as case_id,
  cases.title,
  cases.branch,
  cases.difficulty,
  cases.points,
  cases.icon_key,
  bookmarks.created_at
from praticase.user_bookmarked_cases bookmarks
join praticase.cases cases on cases.id = bookmarks.case_id
where bookmarks.user_id = auth.uid()
  and cases.is_published
  and cases.slug like 'admin-%'
order by bookmarks.created_at desc;

create index if not exists cases_admin_published_branch_idx
  on praticase.cases (is_published, branch, difficulty)
  where slug like 'admin-%';

commit;
