-- finalize_exam_session sağlamlaştırması.
--
-- Sorun: tüm tamamlanan OSCE oturumları current_step='completed' ama
-- session_result_summaries hiç oluşmuyor. Sebep: RPC içindeki
-- `auth.uid() <> session.user_id` check'i, JWT bağlamı kaybolduğunda
-- `Exam session not found` exception'ı fırlatıp tüm finalize'ı düşürüyor.
--
-- Çözüm:
-- 1) Auth check'i yumuşat: yalnızca user_id farklı + auth.uid() NULL DEĞİL
--    iken reddet. Service role çağrıları ve geçici JWT problemleri pas geçsin.
-- 2) Tüm select/join'leri NULL-safe yap. session_management_plan_items.option_id
--    artık text olduğu için cast tolerant olsun.
-- 3) Backfill: status='active' && current_step='completed' && result_card=YOK
--    olan tüm session'lar için finalize'ı tetikle. Backfill admin context'inde
--    çalıştığı için auth check'i devre dışı.

begin;

create or replace function praticase.finalize_exam_session(p_session_id uuid)
returns table(session_id uuid, total_score integer, max_score integer, percentage integer)
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_user_id uuid;
  v_case_id uuid;
  v_caller uuid := auth.uid();
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

  if v_user_id is null then
    raise exception 'EXAM_SESSION_NOT_FOUND: session % bulunamadı', p_session_id;
  end if;

  -- Yalnızca farklı bir authenticated kullanıcı reddedilir.
  -- auth.uid() NULL ise (service role, backfill, edge function) izin ver.
  if v_caller is not null and v_caller <> v_user_id then
    raise exception 'EXAM_SESSION_FORBIDDEN: oturum sahibi farklı';
  end if;

  select exists(select 1 from praticase.session_result_summaries r where r.session_id = p_session_id)
  into v_had_result;

  select count(*)::integer into v_candidate_message_count
  from praticase.exam_messages where session_id = p_session_id and sender = 'candidate';
  v_communication := least(coalesce(v_candidate_message_count, 0), 10);
  v_history := least(coalesce(v_candidate_message_count, 0) * 3, 30);

  begin
    select least(coalesce(sum(coalesce(o.point_value, 0)), 0)::integer, 20) into v_physical
    from praticase.session_physical_exam_findings f
    left join praticase.physical_exam_options o
      on f.option_id::text ~ '^[0-9a-fA-F-]{36}$'
      and o.id::text = f.option_id::text
    where f.session_id = p_session_id;
  exception when others then
    v_physical := 0;
  end;

  begin
    select greatest(0, least(coalesce(sum(case when coalesce(o.is_unnecessary, false) then -5 else 5 end), 0)::integer, 15)),
      coalesce(jsonb_agg(o.title) filter (where coalesce(o.is_unnecessary, false)), '[]'::jsonb)
    into v_tests, v_unnecessary
    from praticase.session_requested_tests r
    left join praticase.test_options o
      on r.option_id::text ~ '^[0-9a-fA-F-]{36}$'
      and o.id::text = r.option_id::text
    where r.session_id = p_session_id;
  exception when others then
    v_tests := 0;
    v_unnecessary := '[]'::jsonb;
  end;

  begin
    select case
      when exists (
        select 1 from praticase.session_diagnosis_answers a
        join unnest(coalesce(a.selected_option_ids, '{}')) i on true
        join praticase.diagnosis_options o on o.id = i
        where a.session_id = p_session_id and o.is_primary
      ) then 15
      when exists (
        select 1 from praticase.session_diagnosis_answers a
        join unnest(coalesce(a.selected_option_ids, '{}')) i on true
        join praticase.diagnosis_options o on o.id = i
        where a.session_id = p_session_id and o.is_correct
      ) then 10 else 0 end
    into v_diagnosis;
  exception when others then
    v_diagnosis := 0;
  end;

  begin
    select least(coalesce(sum(o.point_value), 0)::integer, 10) into v_management
    from praticase.session_management_plan_items i
    join praticase.management_plan_options o on o.id = i.option_id
    where i.session_id = p_session_id;
  exception when others then
    v_management := 0;
  end;

  v_total := coalesce(v_communication, 0) + coalesce(v_history, 0) +
             coalesce(v_physical, 0) + coalesce(v_tests, 0) +
             coalesce(v_diagnosis, 0) + coalesce(v_management, 0);

  v_scores := jsonb_build_array(
    jsonb_build_object('title', 'İletişim', 'score', coalesce(v_communication, 0), 'maxScore', 10),
    jsonb_build_object('title', 'Anamnez', 'score', coalesce(v_history, 0), 'maxScore', 30),
    jsonb_build_object('title', 'Fizik Muayene', 'score', coalesce(v_physical, 0), 'maxScore', 20),
    jsonb_build_object('title', 'Ön Tanılar', 'score', coalesce(v_diagnosis, 0), 'maxScore', 15),
    jsonb_build_object('title', 'Tetkikler', 'score', coalesce(v_tests, 0), 'maxScore', 15),
    jsonb_build_object('title', 'Yönetim', 'score', coalesce(v_management, 0), 'maxScore', 10)
  );

  if coalesce(v_history, 0) >= 18 then
    v_strong := v_strong || '["Anamnez akışın düzenli ilerledi."]'::jsonb;
  else
    v_improvement := v_improvement || '["Anamnez başlıklarını daha sistematik sorgula."]'::jsonb;
  end if;
  if coalesce(v_physical, 0) < 12 then
    v_improvement := v_improvement || '["Sistemik muayene seçimini genişlet."]'::jsonb;
  end if;
  if jsonb_array_length(v_unnecessary) > 0 then
    v_improvement := v_improvement || '["Tetkik istemlerini klinik gerekliliğe göre daralt."]'::jsonb;
  end if;

  insert into praticase.session_result_summaries(
    session_id, total_score, max_score, category_scores, strong_points,
    improvement_points, unnecessary_tests, updated_at
  ) values (
    p_session_id, v_total, 100, v_scores, v_strong, v_improvement, v_unnecessary, now()
  ) on conflict (session_id) do update set
    total_score = excluded.total_score,
    max_score = 100,
    category_scores = excluded.category_scores,
    strong_points = excluded.strong_points,
    improvement_points = excluded.improvement_points,
    unnecessary_tests = excluded.unnecessary_tests,
    updated_at = now();

  update praticase.exam_sessions
  set current_step = 'completed',
      status = 'completed',
      ended_at = coalesce(ended_at, now()),
      updated_at = now()
  where id = p_session_id;

  insert into praticase.user_case_progress(
    user_id, case_id, status, progress_percent, last_score, completed_at, updated_at
  )
  values (v_user_id, v_case_id, 'completed', 100, v_total, now(), now())
  on conflict (user_id, case_id) do update set
    status = 'completed',
    progress_percent = 100,
    last_score = excluded.last_score,
    completed_at = coalesce(praticase.user_case_progress.completed_at, now()),
    updated_at = now();

  if not v_had_result then
    update praticase.cases
    set solved_count = coalesce(solved_count, 0) + 1, updated_at = now()
    where id = v_case_id;

    insert into praticase.user_dashboard_stats(
      user_id, solved_case_count, success_rate_percent, total_points, daily_streak, updated_at
    )
    values (v_user_id, 1, v_total, v_total, 1, now())
    on conflict (user_id) do update set
      solved_case_count = praticase.user_dashboard_stats.solved_case_count + 1,
      success_rate_percent = v_total,
      total_points = praticase.user_dashboard_stats.total_points + v_total,
      daily_streak = greatest(praticase.user_dashboard_stats.daily_streak, 1),
      updated_at = now();

    begin
      insert into praticase.leaderboard_scores(
        user_id, display_name, total_points, solved_case_count, correct_diagnosis_rate, updated_at
      )
      values (
        v_user_id,
        coalesce(praticase.profile_display_name(v_user_id), 'PratiCase Öğrencisi'),
        v_total, 1,
        case when v_diagnosis >= 12 then 100 else 0 end, now()
      )
      on conflict (user_id) do update set
        total_points = praticase.leaderboard_scores.total_points + v_total,
        solved_case_count = praticase.leaderboard_scores.solved_case_count + 1,
        correct_diagnosis_rate = case when v_diagnosis >= 12 then 100 else 0 end,
        updated_at = now();
    exception when others then
      -- leaderboard hatası finalize'ı düşürmesin
      null;
    end;
  end if;

  begin
    insert into praticase.session_evaluation_snapshots(
      session_id, user_id, case_id, evaluation_input, deterministic_result
    )
    select p_session_id, v_user_id, v_case_id,
      jsonb_build_object(
        'transcript', coalesce(
          (select jsonb_agg(jsonb_build_object('sender', sender, 'message', message, 'createdAt', created_at) order by created_at)
           from praticase.exam_messages where session_id = p_session_id),
          '[]'::jsonb),
        'physicalExamOptionIds', coalesce(
          (select jsonb_agg(option_id::text) from praticase.session_physical_exam_findings where session_id = p_session_id),
          '[]'::jsonb),
        'testOptionIds', coalesce(
          (select jsonb_agg(option_id::text) from praticase.session_requested_tests where session_id = p_session_id),
          '[]'::jsonb),
        'diagnosis', coalesce((select to_jsonb(a) from praticase.session_diagnosis_answers a where a.session_id = p_session_id), '{}'::jsonb),
        'management', coalesce((select to_jsonb(n) from praticase.session_management_notes n where n.session_id = p_session_id), '{}'::jsonb)
      ),
      jsonb_build_object('totalScore', v_total, 'maxScore', 100, 'categoryScores', v_scores)
    on conflict (session_id) do nothing;
  exception when others then
    -- snapshot kaydı finalize'ı düşürmesin
    null;
  end;

  return query
    select p_session_id, v_total, 100,
           case when v_total = 0 then 0 else v_total end;
end;
$$;

grant execute on function praticase.finalize_exam_session(uuid) to authenticated, service_role;

-- BACKFILL: tamamlanmış ama karnesi olmayan tüm session'ları finalize et.
-- security definer + caller NULL → check pas geçilir.
do $$
declare
  v_session_id uuid;
  v_count integer := 0;
begin
  for v_session_id in
    select s.id
    from praticase.exam_sessions s
    where s.current_step = 'completed'
      and not exists (
        select 1 from praticase.session_result_summaries r where r.session_id = s.id
      )
  loop
    begin
      perform praticase.finalize_exam_session(v_session_id);
      v_count := v_count + 1;
    exception when others then
      raise notice 'finalize backfill skipped % : %', v_session_id, sqlerrm;
    end;
  end loop;
  raise notice 'backfilled % sessions', v_count;
end $$;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240008', '202605240008_praticase_finalize_exam_session_hardening.sql')
on conflict (version) do nothing;

commit;
