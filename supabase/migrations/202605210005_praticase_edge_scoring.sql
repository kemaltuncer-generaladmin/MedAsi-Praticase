begin;

create or replace function praticase.finalize_exam_session(p_session_id uuid)
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
  v_history_score integer;
  v_physical_score integer;
  v_tests_score integer;
  v_diagnosis_score integer;
  v_management_score integer;
  v_total integer;
  v_had_result boolean;
  v_strong jsonb := '[]'::jsonb;
  v_improvement jsonb := '[]'::jsonb;
  v_category_scores jsonb;
begin
  select exam_sessions.user_id, exam_sessions.case_id
    into v_user_id, v_case_id
  from praticase.exam_sessions
  where exam_sessions.id = p_session_id;

  if v_user_id is null or v_user_id <> auth.uid() then
    raise exception 'Exam session not found';
  end if;

  select exists (
    select 1
    from praticase.session_result_summaries
    where session_result_summaries.session_id = p_session_id
  )
  into v_had_result;

  select least(count(*)::integer * 2, 10)
    into v_history_score
  from praticase.exam_messages
  where exam_messages.session_id = p_session_id
    and exam_messages.sender = 'candidate';

  select least(coalesce(sum(physical_exam_options.point_value), 0)::integer, 20)
    into v_physical_score
  from praticase.session_physical_exam_findings findings
  join praticase.physical_exam_options physical_exam_options
    on physical_exam_options.id = findings.option_id
  where findings.session_id = p_session_id;

  select greatest(
      0,
      least(
        coalesce(sum(case when test_options.is_unnecessary then -5 else 5 end), 0)::integer,
        15
      )
    )
    into v_tests_score
  from praticase.session_requested_tests requested_tests
  join praticase.test_options test_options
    on test_options.id = requested_tests.option_id
  where requested_tests.session_id = p_session_id;

  select case
      when exists (
        select 1
        from praticase.session_diagnosis_answers answers
        join unnest(answers.selected_option_ids) as selected_option_id on true
        join praticase.diagnosis_options diagnosis_options
          on diagnosis_options.id = selected_option_id
        where answers.session_id = p_session_id
          and diagnosis_options.is_primary
      ) then 15
      when exists (
        select 1
        from praticase.session_diagnosis_answers answers
        join unnest(answers.selected_option_ids) as selected_option_id on true
        join praticase.diagnosis_options diagnosis_options
          on diagnosis_options.id = selected_option_id
        where answers.session_id = p_session_id
          and diagnosis_options.is_correct
      ) then 10
      else 0
    end
    into v_diagnosis_score;

  select least(coalesce(sum(management_plan_options.point_value), 0)::integer, 10)
    into v_management_score
  from praticase.session_management_plan_items plan_items
  join praticase.management_plan_options management_plan_options
    on management_plan_options.id = plan_items.option_id
  where plan_items.session_id = p_session_id;

  v_total := v_history_score
    + v_physical_score
    + v_tests_score
    + v_diagnosis_score
    + v_management_score;

  if v_history_score >= 8 then
    v_strong := v_strong || jsonb_build_array('Anamnez akışın yeterli düzeyde.');
  else
    v_improvement := v_improvement || jsonb_build_array('Anamnezde ana şikayet, kırmızı bayrak ve özgeçmiş başlıklarını genişlet.');
  end if;

  if v_physical_score >= 15 then
    v_strong := v_strong || jsonb_build_array('Muayene seçimlerin vakayla uyumlu.');
  else
    v_improvement := v_improvement || jsonb_build_array('Fizik muayenede kritik bulguları daha sistematik tara.');
  end if;

  if v_tests_score >= 10 then
    v_strong := v_strong || jsonb_build_array('Tetkik seçiminde maliyet ve klinik yararı dengeledin.');
  else
    v_improvement := v_improvement || jsonb_build_array('Gereksiz tetkikten kaçınarak hedefe yönelik istem yap.');
  end if;

  if v_diagnosis_score >= 15 then
    v_strong := v_strong || jsonb_build_array('Ana tanıyı doğru yakaladın.');
  else
    v_improvement := v_improvement || jsonb_build_array('Ayırıcı tanı listesini kritik tanıyı kaçırmayacak şekilde güçlendir.');
  end if;

  if v_management_score >= 7 then
    v_strong := v_strong || jsonb_build_array('Yönetim planın klinik önceliklerle uyumlu.');
  else
    v_improvement := v_improvement || jsonb_build_array('Tedavi ve izlem planını tanıya göre daha net yapılandır.');
  end if;

  v_category_scores := jsonb_build_array(
    jsonb_build_object('title', 'Anamnez', 'score', v_history_score, 'maxScore', 10),
    jsonb_build_object('title', 'Fizik Muayene', 'score', v_physical_score, 'maxScore', 20),
    jsonb_build_object('title', 'Tetkikler', 'score', v_tests_score, 'maxScore', 15),
    jsonb_build_object('title', 'Tanı', 'score', v_diagnosis_score, 'maxScore', 15),
    jsonb_build_object('title', 'Yönetim', 'score', v_management_score, 'maxScore', 10)
  );

  insert into praticase.session_result_summaries(
    session_id,
    total_score,
    max_score,
    category_scores,
    strong_points,
    improvement_points,
    updated_at
  )
  values (
    p_session_id,
    v_total,
    70,
    v_category_scores,
    v_strong,
    v_improvement,
    now()
  )
  on conflict (session_id) do update set
    total_score = excluded.total_score,
    max_score = excluded.max_score,
    category_scores = excluded.category_scores,
    strong_points = excluded.strong_points,
    improvement_points = excluded.improvement_points,
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
  values (v_user_id, v_case_id, 'completed', 100, round((v_total::numeric / 70::numeric) * 100), now(), now())
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
    values (v_user_id, 1, round((v_total::numeric / 70::numeric) * 100), v_total, 1, now())
    on conflict (user_id) do update set
      solved_case_count = praticase.user_dashboard_stats.solved_case_count + 1,
      success_rate_percent = round((v_total::numeric / 70::numeric) * 100),
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
      case when v_diagnosis_score >= 15 then 100 else 0 end,
      now()
    )
    on conflict (user_id) do update set
      total_points = praticase.leaderboard_scores.total_points + v_total,
      solved_case_count = praticase.leaderboard_scores.solved_case_count + 1,
      correct_diagnosis_rate = case when v_diagnosis_score >= 15 then 100 else 0 end,
      updated_at = now();
  end if;

  return query
  select
    p_session_id,
    v_total,
    70,
    round((v_total::numeric / 70::numeric) * 100)::integer;
end;
$$;

grant execute on function praticase.finalize_exam_session(uuid) to authenticated;

commit;
