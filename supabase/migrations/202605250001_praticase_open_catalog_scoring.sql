-- Keep the complete clinical test catalog available to the candidate, while
-- allowing each case to score relevant and unnecessary global requests.

begin;

create table if not exists praticase.case_global_test_relevance (
  case_id uuid not null references praticase.cases(id) on delete cascade,
  global_option_id text not null references praticase.global_test_options(id) on delete cascade,
  relevance text not null check (relevance in ('recommended', 'acceptable', 'unnecessary')),
  point_value integer not null default 0 check (point_value between -5 and 5),
  rationale text not null default '',
  primary key (case_id, global_option_id)
);

alter table praticase.case_global_test_relevance enable row level security;
grant all on praticase.case_global_test_relevance to service_role;

update praticase.cases
set patient_profile = jsonb_set(
      coalesce(patient_profile, '{}'::jsonb),
      '{openingLine}',
      to_jsonb(
        'Hocam, arabayla kaza yaptım; göğsüm ve boynum çok ağrıyor, nefes almakta zorlanıyorum.'::text
      ),
      true
    ),
    updated_at = now()
where id = '5959b3c7-069c-47bf-892a-ca89a153c2a1'
  and title = 'Travma';

update praticase.global_test_options
set default_result =
  'Plevral kayma izleniyor; pnömotoraks lehine bulgu saptanmadı. B-line artışı yok.'
where id = 'toraks_usg';

insert into praticase.case_global_test_relevance(
  case_id, global_option_id, relevance, point_value, rationale
) values
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'toraks_usg', 'recommended', 5, 'Toraks travmasında yatak başı pnömotoraks değerlendirmesi.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'batin_usg', 'recommended', 5, 'Travmada serbest sıvı açısından hızlı değerlendirme.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'akc_grafi', 'recommended', 5, 'Toraks yaralanmasının ilk görüntüleme basamaklarından biri.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'servikal_grafi', 'recommended', 5, 'Boyun ağrısı olan travma hastasında servikal yaralanma değerlendirmesi.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'kan_gazi', 'acceptable', 0, 'Solunum sıkıntısı ve instabilitede klinik kararla istenebilir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'ekg', 'acceptable', 0, 'Künt toraks travmasında klinik şüpheye göre istenebilir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'toraks_bt', 'acceptable', 0, 'Stabil hastada ileri görüntüleme olarak düşünülebilir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'pelvik_usg', 'unnecessary', -5, 'Bu erkek toraks travması istasyonunda öncelikli değerlendirme değildir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'skrotal_usg', 'unnecessary', -5, 'Skrotal yakınma veya bulgu olmadan endike değildir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'beta_hcg', 'unnecessary', -5, 'Erkek hasta için uygun değildir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'hizli_strep', 'unnecessary', -5, 'Travma değerlendirmesine katkı sağlamaz.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'tsh', 'unnecessary', -5, 'Akut travma yaklaşımında gerekli değildir.'),
  ('5959b3c7-069c-47bf-892a-ca89a153c2a1', 'endoskopi', 'unnecessary', -5, 'Bu başlangıç travma değerlendirmesinde endike değildir.')
on conflict (case_id, global_option_id) do update set
  relevance = excluded.relevance,
  point_value = excluded.point_value,
  rationale = excluded.rationale;

drop function if exists praticase.finalize_exam_session(uuid) cascade;

create function praticase.finalize_exam_session(p_session_id uuid)
returns table(
  out_session_id uuid,
  out_total_score integer,
  out_max_score integer,
  out_percentage integer
)
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

  if v_caller is not null and v_caller <> v_user_id then
    raise exception 'EXAM_SESSION_FORBIDDEN: oturum sahibi farklı';
  end if;

  select exists(
    select 1 from praticase.session_result_summaries r
    where r.session_id = p_session_id
  ) into v_had_result;

  select count(*)::integer into v_candidate_message_count
  from praticase.exam_messages m
  where m.session_id = p_session_id and m.sender = 'candidate';
  v_communication := least(coalesce(v_candidate_message_count, 0), 10);
  v_history := least(coalesce(v_candidate_message_count, 0) * 3, 30);

  begin
    select least(coalesce(sum(coalesce(o.point_value, 0)), 0)::integer, 20)
    into v_physical
    from praticase.session_physical_exam_findings f
    left join praticase.physical_exam_options o
      on f.option_id::text ~ '^[0-9a-fA-F-]{36}$'
      and o.id::text = f.option_id::text
    where f.session_id = p_session_id;
  exception when others then
    v_physical := 0;
  end;

  begin
    with selected_tests as (
      select
        coalesce(o.title, g.title) as title,
        case
          when o.id is not null then coalesce(o.is_unnecessary, false)
          else coalesce(rel.relevance = 'unnecessary', false)
        end as is_unnecessary,
        case
          when o.id is not null then
            case when coalesce(o.is_unnecessary, false) then -5 else 5 end
          when rel.relevance = 'recommended' then rel.point_value
          when rel.relevance = 'unnecessary' then rel.point_value
          else 0
        end as score_value
      from praticase.session_requested_tests r
      left join praticase.test_options o
        on r.option_id::text ~ '^[0-9a-fA-F-]{36}$'
        and o.id::text = r.option_id::text
      left join praticase.global_test_options g
        on r.option_id::text = 'global:' || g.id
      left join praticase.case_global_test_relevance rel
        on rel.case_id = v_case_id and rel.global_option_id = g.id
      where r.session_id = p_session_id
    )
    select greatest(0, least(coalesce(sum(score_value), 0)::integer, 15)),
      coalesce(jsonb_agg(title) filter (where is_unnecessary), '[]'::jsonb)
    into v_tests, v_unnecessary
    from selected_tests;
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
    select least(coalesce(sum(o.point_value), 0)::integer, 10)
    into v_management
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

  insert into praticase.session_result_summaries as srs(
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
          (select jsonb_agg(jsonb_build_object('sender', em.sender, 'message', em.message, 'createdAt', em.created_at) order by em.created_at)
           from praticase.exam_messages em where em.session_id = p_session_id),
          '[]'::jsonb),
        'physicalExamOptionIds', coalesce(
          (select jsonb_agg(pef.option_id::text) from praticase.session_physical_exam_findings pef where pef.session_id = p_session_id),
          '[]'::jsonb),
        'testOptionIds', coalesce(
          (select jsonb_agg(srt.option_id::text) from praticase.session_requested_tests srt where srt.session_id = p_session_id),
          '[]'::jsonb),
        'diagnosis', coalesce((select to_jsonb(a) from praticase.session_diagnosis_answers a where a.session_id = p_session_id), '{}'::jsonb),
        'management', coalesce((select to_jsonb(n) from praticase.session_management_notes n where n.session_id = p_session_id), '{}'::jsonb)
      ),
      jsonb_build_object('totalScore', v_total, 'maxScore', 100, 'categoryScores', v_scores)
    on conflict (session_id) do nothing;
  exception when others then
    null;
  end;

  return query
    select p_session_id, v_total, 100, v_total;
end;
$$;

grant execute on function praticase.finalize_exam_session(uuid) to authenticated, service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605250001', '202605250001_praticase_open_catalog_scoring.sql')
on conflict (version) do nothing;

commit;
