-- Run after God Mode migrations. This test is read-only and can be run
-- against staging or production without mutating operational data.

begin;

do $$
declare
  v_view text;
begin
  foreach v_view in array array[
    'god_mode_case_publication_v',
    'god_mode_osce_funnel_v',
    'god_mode_oral_funnel_v',
    'god_mode_score_distribution_v',
    'god_mode_dropoff_v',
    'god_mode_active_banners_v',
    'god_mode_open_support_v',
    'god_mode_content_health_v'
  ] loop
    if to_regclass('praticase.' || v_view) is null then
      raise exception 'Missing God Mode view: %', v_view;
    end if;
    if has_table_privilege('authenticated', 'praticase.' || v_view, 'SELECT') then
      raise exception 'Authenticated must not select God Mode view: %', v_view;
    end if;
    if not has_table_privilege('service_role', 'praticase.' || v_view, 'SELECT') then
      raise exception 'Service role must select God Mode view: %', v_view;
    end if;
  end loop;

  if to_regprocedure(
    'praticase.god_mode_analytics_snapshot(timestamp with time zone,timestamp with time zone)'
  ) is null then
    raise exception 'Missing God Mode snapshot RPC';
  end if;
  if has_function_privilege(
    'authenticated',
    'praticase.god_mode_analytics_snapshot(timestamp with time zone,timestamp with time zone)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated must not execute God Mode analytics RPC';
  end if;
  if not has_function_privilege(
    'service_role',
    'praticase.god_mode_analytics_snapshot(timestamp with time zone,timestamp with time zone)',
    'EXECUTE'
  ) then
    raise exception 'Service role must execute God Mode analytics RPC';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'praticase'
      and table_name like 'god_mode_%'
      and column_name in (
        'user_id', 'email', 'message', 'case_brief', 'mentor_summary',
        'moderation_context', 'evaluation_input', 'latest_transaction_id',
        'original_transaction_id'
      )
  ) then
    raise exception 'God Mode analytics surface exposes a sensitive column';
  end if;
end $$;

select praticase.god_mode_analytics_snapshot(
  now() - interval '30 days',
  now()
) ->> 'contractVersion' as contract_version;

rollback;
