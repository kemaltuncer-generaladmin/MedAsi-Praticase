begin;

create or replace function praticase.refresh_user_badges(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'Badge refresh is only allowed for current user';
  end if;

  with user_results as (
    select
      summaries.session_id,
      summaries.percentage,
      summaries.category_scores,
      summaries.unnecessary_tests,
      sessions.started_at,
      sessions.ended_at
    from praticase.session_result_summaries summaries
    join praticase.exam_sessions sessions on sessions.id = summaries.session_id
    where sessions.user_id = p_user_id
  ),
  metrics as (
    select
      count(*)::integer as solved_count,
      count(*) filter (
        where exists (
          select 1
          from jsonb_array_elements(coalesce(user_results.category_scores, '[]'::jsonb)) score_item
          where lower(score_item->>'title') in ('ön tanılar', 'tanı', 'ayırıcı tanı')
            and coalesce((score_item->>'score')::integer, 0) >= 12
        )
      )::integer as correct_diagnosis_count,
      count(*) filter (
        where jsonb_array_length(coalesce(user_results.unnecessary_tests, '[]'::jsonb)) = 0
      )::integer as clean_test_count,
      count(*) filter (where user_results.percentage >= 90)::integer as excellent_count,
      count(*) filter (
        where user_results.ended_at is not null
          and user_results.started_at is not null
          and user_results.ended_at <= user_results.started_at + interval '5 minutes'
      )::integer as fast_count
    from user_results
  ),
  badge_progress as (
    select
      badges.id as badge_id,
      badges.target_count,
      greatest(0, case
        when badges.title = 'İlk Vakam' then metrics.solved_count
        when badges.title = 'Tanı Ustası' then metrics.correct_diagnosis_count
        when badges.title = 'Tetkik Uzmanı' then metrics.clean_test_count
        when badges.title = 'Mükemmel Doktor' then metrics.excellent_count
        when badges.title = 'Hızlı Çözücü' then metrics.fast_count
        else 0
      end) as progress_count
    from praticase.badge_definitions badges
    cross join metrics
    where badges.is_active
  )
  insert into praticase.user_badges(
    user_id,
    badge_id,
    progress_count,
    earned_at,
    updated_at
  )
  select
    p_user_id,
    badge_progress.badge_id,
    least(badge_progress.progress_count, badge_progress.target_count),
    case
      when badge_progress.progress_count >= badge_progress.target_count
        then coalesce(existing.earned_at, now())
      else null
    end,
    now()
  from badge_progress
  left join praticase.user_badges existing
    on existing.user_id = p_user_id
    and existing.badge_id = badge_progress.badge_id
  on conflict (user_id, badge_id) do update set
    progress_count = excluded.progress_count,
    earned_at = case
      when praticase.user_badges.earned_at is not null
        then praticase.user_badges.earned_at
      when excluded.earned_at is not null
        then excluded.earned_at
      else null
    end,
    updated_at = now();
end;
$$;

create or replace function praticase.refresh_user_badges_for_result()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_user_id uuid;
begin
  select sessions.user_id
    into v_user_id
  from praticase.exam_sessions sessions
  where sessions.id = new.session_id;

  if v_user_id is not null then
    perform praticase.refresh_user_badges(v_user_id);
  end if;

  return new;
end;
$$;

drop trigger if exists refresh_user_badges_after_result
  on praticase.session_result_summaries;

create trigger refresh_user_badges_after_result
after insert or update on praticase.session_result_summaries
for each row
execute function praticase.refresh_user_badges_for_result();

grant execute on function praticase.refresh_user_badges(uuid)
  to authenticated, service_role;

commit;
