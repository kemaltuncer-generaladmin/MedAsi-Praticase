begin;

alter table praticase.session_result_summaries
  add column if not exists critical_mistakes jsonb not null default '[]'::jsonb,
  add column if not exists unnecessary_tests jsonb not null default '[]'::jsonb,
  add column if not exists missed_history jsonb not null default '[]'::jsonb,
  add column if not exists missed_physical_exam jsonb not null default '[]'::jsonb,
  add column if not exists ideal_approach text not null default '';

create or replace view praticase.session_result_cards
with (security_invoker = true) as
select
  summaries.session_id,
  cases.title as case_title,
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

create or replace function praticase.finalize_exam_session_ai(
  p_session_id uuid,
  p_total_score integer,
  p_max_score integer,
  p_category_scores jsonb,
  p_strong_points jsonb,
  p_improvement_points jsonb,
  p_critical_mistakes jsonb default '[]'::jsonb,
  p_unnecessary_tests jsonb default '[]'::jsonb,
  p_missed_history jsonb default '[]'::jsonb,
  p_missed_physical_exam jsonb default '[]'::jsonb,
  p_ideal_approach text default ''
)
returns table(
  session_id uuid,
  total_score integer,
  max_score integer,
  percentage integer
)
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_user_id uuid;
  v_case_id uuid;
  v_had_result boolean;
  v_total integer;
  v_max integer;
  v_percentage integer;
  v_diagnosis_score integer := 0;
begin
  select exam_sessions.user_id, exam_sessions.case_id
    into v_user_id, v_case_id
  from praticase.exam_sessions
  where exam_sessions.id = p_session_id;

  if v_user_id is null or v_user_id <> auth.uid() then
    raise exception 'Exam session not found';
  end if;

  v_total := greatest(0, least(coalesce(p_total_score, 0), 100));
  v_max := greatest(coalesce(p_max_score, 100), 1);
  v_percentage := round((v_total::numeric / v_max::numeric) * 100)::integer;

  select exists (
    select 1
    from praticase.session_result_summaries
    where session_result_summaries.session_id = p_session_id
  )
  into v_had_result;

  select coalesce((score_item->>'score')::integer, 0)
    into v_diagnosis_score
  from jsonb_array_elements(coalesce(p_category_scores, '[]'::jsonb)) score_item
  where lower(score_item->>'title') in ('ön tanılar', 'tanı', 'ayırıcı tanı')
  limit 1;

  insert into praticase.session_result_summaries(
    session_id,
    total_score,
    max_score,
    category_scores,
    strong_points,
    improvement_points,
    critical_mistakes,
    unnecessary_tests,
    missed_history,
    missed_physical_exam,
    ideal_approach,
    updated_at
  )
  values (
    p_session_id,
    v_total,
    v_max,
    coalesce(p_category_scores, '[]'::jsonb),
    coalesce(p_strong_points, '[]'::jsonb),
    coalesce(p_improvement_points, '[]'::jsonb),
    coalesce(p_critical_mistakes, '[]'::jsonb),
    coalesce(p_unnecessary_tests, '[]'::jsonb),
    coalesce(p_missed_history, '[]'::jsonb),
    coalesce(p_missed_physical_exam, '[]'::jsonb),
    coalesce(p_ideal_approach, ''),
    now()
  )
  on conflict (session_id) do update set
    total_score = excluded.total_score,
    max_score = excluded.max_score,
    category_scores = excluded.category_scores,
    strong_points = excluded.strong_points,
    improvement_points = excluded.improvement_points,
    critical_mistakes = excluded.critical_mistakes,
    unnecessary_tests = excluded.unnecessary_tests,
    missed_history = excluded.missed_history,
    missed_physical_exam = excluded.missed_physical_exam,
    ideal_approach = excluded.ideal_approach,
    updated_at = now();

  update praticase.exam_sessions
  set current_step = 'completed',
      status = 'completed',
      ended_at = coalesce(ended_at, now()),
      updated_at = now()
  where id = p_session_id;

  insert into praticase.user_case_progress(
    user_id,
    case_id,
    status,
    progress_percent,
    last_score,
    completed_at,
    updated_at
  )
  values (v_user_id, v_case_id, 'completed', 100, v_percentage, now(), now())
  on conflict (user_id, case_id) do update set
    status = 'completed',
    progress_percent = 100,
    last_score = excluded.last_score,
    completed_at = coalesce(praticase.user_case_progress.completed_at, now()),
    updated_at = now();

  if not v_had_result then
    update praticase.cases
    set solved_count = solved_count + 1,
        updated_at = now()
    where id = v_case_id;

    insert into praticase.user_dashboard_stats(
      user_id,
      solved_case_count,
      success_rate_percent,
      total_points,
      daily_streak,
      updated_at
    )
    values (v_user_id, 1, v_percentage, v_total, 1, now())
    on conflict (user_id) do update set
      solved_case_count = praticase.user_dashboard_stats.solved_case_count + 1,
      success_rate_percent = v_percentage,
      total_points = praticase.user_dashboard_stats.total_points + v_total,
      daily_streak = greatest(praticase.user_dashboard_stats.daily_streak, 1),
      updated_at = now();

    insert into praticase.leaderboard_scores(
      user_id,
      display_name,
      total_points,
      solved_case_count,
      correct_diagnosis_rate,
      updated_at
    )
    values (
      v_user_id,
      coalesce((select email from auth.users where id = v_user_id), 'PratiCase Öğrencisi'),
      v_total,
      1,
      case when v_diagnosis_score >= 12 then 100 else 0 end,
      now()
    )
    on conflict (user_id) do update set
      total_points = praticase.leaderboard_scores.total_points + v_total,
      solved_case_count = praticase.leaderboard_scores.solved_case_count + 1,
      correct_diagnosis_rate = case when v_diagnosis_score >= 12 then 100 else 0 end,
      updated_at = now();
  end if;

  return query
  select p_session_id, v_total, v_max, v_percentage;
end;
$$;

grant execute on function praticase.finalize_exam_session_ai(
  uuid,
  integer,
  integer,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  jsonb,
  text
) to authenticated;

commit;
