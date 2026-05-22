begin;

create or replace view praticase.user_badge_summary
with (security_invoker = true) as
select
  auth.uid() as user_id,
  case
    when count(user_badges.badge_id) filter (where user_badges.earned_at is not null) > 0
      then count(user_badges.badge_id) filter (where user_badges.earned_at is not null)::text || ' rozet kazandın'
    else 'İlk rozetine yakınsın'
  end as title,
  case
    when count(user_badges.badge_id) filter (where user_badges.earned_at is not null) > 0
      then 'Başarılarını ve sıradaki hedeflerini incele.'
    else 'Sınav çözdükçe başarı rozetlerin canlı olarak burada oluşacak.'
  end as subtitle,
  'Rozetlerim' as action_label
from praticase.badge_definitions badges
left join praticase.user_badges
  on user_badges.badge_id = badges.id
  and user_badges.user_id = auth.uid()
where badges.is_active;

grant select on praticase.user_badge_summary to anon, authenticated, service_role;

commit;
