begin;

create or replace function praticase.user_badge_metric_snapshot(p_user_id uuid)
returns table (
  solved_count integer,
  correct_diagnosis_count integer,
  clean_test_count integer,
  excellent_count integer,
  fast_count integer
)
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
begin
  if p_user_id is null then
    return;
  end if;

  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'Badge metrics are only available for current user';
  end if;

  return query
  with user_results as (
    select
      summaries.session_id,
      summaries.percentage,
      case
        when jsonb_typeof(coalesce(summaries.category_scores, '[]'::jsonb)) = 'array'
          then coalesce(summaries.category_scores, '[]'::jsonb)
        else '[]'::jsonb
      end as category_scores,
      case
        when jsonb_typeof(coalesce(summaries.unnecessary_tests, '[]'::jsonb)) = 'array'
          then coalesce(summaries.unnecessary_tests, '[]'::jsonb)
        else '[]'::jsonb
      end as unnecessary_tests,
      sessions.started_at,
      coalesce(sessions.ended_at, summaries.updated_at) as ended_at
    from praticase.session_result_summaries summaries
    join praticase.exam_sessions sessions on sessions.id = summaries.session_id
    where sessions.user_id = p_user_id
  )
  select
    count(*)::integer as solved_count,
    count(*) filter (
      where exists (
        select 1
        from jsonb_array_elements(user_results.category_scores) score_item
        where (
          coalesce(score_item->>'title', '') ilike '%tanı%'
          or coalesce(score_item->>'title', '') ilike '%diagnosis%'
        )
        and coalesce(nullif(score_item->>'maxScore', '')::numeric, 0) > 0
        and (
          coalesce(nullif(score_item->>'score', '')::numeric, 0) /
          coalesce(nullif(score_item->>'maxScore', '')::numeric, 1)
        ) >= 0.80
      )
    )::integer as correct_diagnosis_count,
    count(*) filter (
      where jsonb_array_length(user_results.unnecessary_tests) = 0
    )::integer as clean_test_count,
    count(*) filter (where coalesce(user_results.percentage, 0) >= 90)::integer
      as excellent_count,
    count(*) filter (
      where user_results.ended_at is not null
        and user_results.started_at is not null
        and user_results.ended_at <= user_results.started_at + interval '5 minutes'
    )::integer as fast_count
  from user_results;
end;
$$;

create or replace function praticase.refresh_user_badges(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
begin
  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if auth.uid() is not null and auth.uid() <> p_user_id then
    raise exception 'Badge refresh is only allowed for current user';
  end if;

  with metrics as (
    select * from praticase.user_badge_metric_snapshot(p_user_id)
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

create or replace view praticase.user_badge_cards
with (security_invoker = true) as
with metrics as (
  select * from praticase.user_badge_metric_snapshot(auth.uid())
),
badge_progress as (
  select
    badges.id as badge_id,
    greatest(0, case
      when badges.title = 'İlk Vakam' then metrics.solved_count
      when badges.title = 'Tanı Ustası' then metrics.correct_diagnosis_count
      when badges.title = 'Tetkik Uzmanı' then metrics.clean_test_count
      when badges.title = 'Mükemmel Doktor' then metrics.excellent_count
      when badges.title = 'Hızlı Çözücü' then metrics.fast_count
      else 0
    end) as live_progress_count
  from praticase.badge_definitions badges
  cross join metrics
  where badges.is_active
)
select
  badges.id as badge_id,
  badges.title,
  badges.subtitle,
  badges.icon_key,
  badges.tier,
  badges.target_count,
  least(
    badges.target_count,
    greatest(
      coalesce(badge_progress.live_progress_count, 0),
      coalesce(user_badges.progress_count, 0)
    )
  ) as progress_count,
  case
    when greatest(
      coalesce(badge_progress.live_progress_count, 0),
      coalesce(user_badges.progress_count, 0)
    ) >= badges.target_count
      then coalesce(user_badges.earned_at, user_badges.updated_at, now())
    else user_badges.earned_at
  end as earned_at,
  badges.sort_order
from praticase.badge_definitions badges
left join badge_progress on badge_progress.badge_id = badges.id
left join praticase.user_badges
  on user_badges.badge_id = badges.id
  and user_badges.user_id = auth.uid()
where badges.is_active;

create or replace view praticase.user_badge_summary
with (security_invoker = true) as
with cards as (
  select
    badge_id,
    progress_count,
    target_count,
    earned_at
  from praticase.user_badge_cards
),
totals as (
  select
    count(*)::integer as total_count,
    count(*) filter (where earned_at is not null)::integer as earned_count,
    count(*) filter (
      where earned_at is null and progress_count > 0
    )::integer as active_count
  from cards
)
select
  auth.uid() as user_id,
  case
    when totals.total_count = 0 then 'Başarı hedefleri hazırlanıyor'
    when totals.earned_count > 0
      then totals.earned_count::text || ' rozet kazandın'
    else 'İlk rozetine yakınsın'
  end as title,
  case
    when totals.total_count = 0
      then 'Sınav sonuçların geldikçe başarıların canlı hesaplanacak.'
    when totals.earned_count > 0
      then 'Başarıların canlı sonuçlarına göre güncelleniyor.'
    when totals.active_count > 0
      then 'Sıradaki başarı hedefin canlı ilerlemeyle takip ediliyor.'
    else 'Sınav çözdükçe başarı rozetlerin canlı olarak burada oluşacak.'
  end as subtitle,
  'Başarılarım' as action_label
from totals;

grant execute on function praticase.user_badge_metric_snapshot(uuid)
  to authenticated, service_role;
grant execute on function praticase.refresh_user_badges(uuid)
  to authenticated, service_role;
grant select on praticase.user_badge_cards
  to authenticated, service_role;
grant select on praticase.user_badge_summary
  to authenticated, service_role;

commit;
