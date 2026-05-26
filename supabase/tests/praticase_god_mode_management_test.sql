-- Transactional management/audit smoke test. All temporary writes roll back.
-- It requires at least one existing auth user for the audited actor contract.

begin;

do $$
declare
  v_actor uuid;
  v_banner_id uuid := extensions.gen_random_uuid();
  v_request_id text := 'god-mode-test-' || extensions.gen_random_uuid()::text;
begin
  select id into v_actor from auth.users order by created_at limit 1;
  if v_actor is null then
    raise notice 'No auth user present; management RPC write smoke test skipped.';
    return;
  end if;

  perform praticase.god_mode_upsert_banner(
    v_banner_id,
    'God Mode Test Banner',
    'Rolled back after verification.',
    'Aç',
    '/cases',
    null,
    null,
    null,
    '',
    9999,
    false,
    null,
    null,
    v_actor,
    v_request_id,
    'Transactional audit contract test'
  );

  if not exists (
    select 1
    from praticase.admin_content_audit_events audit
    where audit.request_id = v_request_id
      and audit.entity_type = 'home_banner'
      and audit.write_surface = 'god_mode_rpc'
      and audit.actor_user_id = v_actor
  ) then
    raise exception 'God Mode audited write did not create an audit event';
  end if;

  begin
    perform praticase.god_mode_upsert_banner(
      extensions.gen_random_uuid(),
      '',
      '',
      'Aç',
      '/cases',
      null,
      null,
      null,
      '',
      0,
      false,
      null,
      null,
      v_actor,
      v_request_id || '-invalid',
      'Expected invalid banner validation'
    );
    raise exception 'Invalid banner unexpectedly succeeded';
  exception when sqlstate '22023' then
    null;
  end;
end $$;

rollback;
