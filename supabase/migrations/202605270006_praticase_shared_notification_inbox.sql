begin;

-- PratiCase retains its local projection for older clients, while the shared
-- Medasi inbox remains owned and served by Qlinik.
create table if not exists praticase.shared_notification_delivery_links (
  local_notification_id uuid primary key
    references praticase.user_notifications(id) on delete cascade,
  shared_message_id uuid not null,
  shared_delivery_id uuid not null unique,
  synced_at timestamptz not null default now()
);

alter table praticase.shared_notification_delivery_links enable row level security;
revoke all on praticase.shared_notification_delivery_links
  from public, anon, authenticated;
grant select, insert, update, delete
  on praticase.shared_notification_delivery_links to service_role;

create or replace function praticase.sync_user_notifications_to_shared(
  p_campaign_id uuid default null
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_notification record;
  v_shared jsonb;
  v_synced integer := 0;
begin
  for v_notification in
    select
      local_notification.id,
      local_notification.user_id,
      local_notification.title,
      local_notification.body,
      local_notification.is_read,
      local_notification.created_at,
      local_notification.campaign_id,
      local_notification.deep_link,
      campaign.created_by
    from praticase.user_notifications local_notification
    left join praticase.notification_campaigns campaign
      on campaign.id = local_notification.campaign_id
    left join praticase.shared_notification_delivery_links link
      on link.local_notification_id = local_notification.id
    where link.local_notification_id is null
      and char_length(trim(local_notification.title)) > 0
      and (
        p_campaign_id is null
        or local_notification.campaign_id = p_campaign_id
      )
    order by local_notification.created_at, local_notification.id
  loop
    v_shared := public.publish_shared_inbox_notification(
      p_user_id => v_notification.user_id,
      p_title => left(trim(v_notification.title), 120),
      p_body => left(
        coalesce(nullif(trim(v_notification.body), ''), trim(v_notification.title)),
        500
      ),
      p_data => jsonb_strip_nulls(jsonb_build_object(
        'source_app_code', 'praticase',
        'route', nullif(trim(v_notification.deep_link), ''),
        'campaign_id', v_notification.campaign_id,
        'local_notification_id', v_notification.id
      )),
      p_created_by => v_notification.created_by,
      p_created_at => v_notification.created_at,
      p_read_at => case
        when v_notification.is_read then v_notification.created_at
        else null
      end
    );

    insert into praticase.shared_notification_delivery_links(
      local_notification_id,
      shared_message_id,
      shared_delivery_id
    )
    values (
      v_notification.id,
      (v_shared ->> 'message_id')::uuid,
      (v_shared ->> 'delivery_id')::uuid
    );
    v_synced := v_synced + 1;
  end loop;

  return v_synced;
end;
$$;

revoke all on function praticase.sync_user_notifications_to_shared(uuid)
  from public, anon, authenticated;
grant execute on function praticase.sync_user_notifications_to_shared(uuid)
  to service_role;

create or replace function praticase.materialize_notification_campaign(
  p_campaign_id uuid
)
returns integer
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_campaign praticase.notification_campaigns%rowtype;
  v_inserted integer := 0;
begin
  select *
    into v_campaign
  from praticase.notification_campaigns
  where id = p_campaign_id
    and is_active;

  if not found then
    raise exception 'Notification campaign not found';
  end if;

  with recipients as (
    select profiles.id as user_id
    from public.profiles
    where v_campaign.audience = 'all'
      or (
        v_campaign.audience = 'users'
        and profiles.id = any(coalesce(v_campaign.target_user_ids, array[]::uuid[]))
      )
  ),
  inserted as (
    insert into praticase.user_notifications(
      user_id,
      campaign_id,
      title,
      body,
      deep_link,
      created_at
    )
    select
      recipients.user_id,
      v_campaign.id,
      v_campaign.title,
      v_campaign.body,
      v_campaign.deep_link,
      now()
    from recipients
    on conflict do nothing
    returning 1
  )
  select count(*)::integer into v_inserted from inserted;

  perform praticase.sync_user_notifications_to_shared(v_campaign.id);

  update praticase.notification_campaigns
  set sent_at = coalesce(sent_at, now()),
      updated_at = now()
  where id = v_campaign.id;

  return v_inserted;
end;
$$;

grant execute on function praticase.materialize_notification_campaign(uuid)
  to service_role;

-- Publish historical in-app notifications once, preserving read state. New
-- campaign materializations publish as part of their transaction.
do $$
begin
  perform praticase.sync_user_notifications_to_shared(null);
end;
$$;

insert into praticase.self_hosted_schema_migrations(version, filename)
values (
  '202605270006_praticase_shared_notification_inbox',
  '202605270006_praticase_shared_notification_inbox.sql'
)
on conflict (version) do nothing;

commit;
