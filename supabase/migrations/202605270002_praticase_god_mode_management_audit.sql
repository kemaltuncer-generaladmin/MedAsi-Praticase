-- Audited, validated write contract for PratiCase God Mode.
-- Existing service-role writes remain functional and are tagged as legacy
-- direct writes; new panel code should use the RPCs below with audit context.

begin;

alter table praticase.contact_requests
  drop constraint if exists contact_requests_status_god_mode_check;

alter table praticase.contact_requests
  add constraint contact_requests_status_god_mode_check
  check (status in ('open', 'in_progress', 'resolved', 'closed')) not valid;

create table if not exists praticase.admin_content_audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  entity_type text not null,
  entity_key text not null,
  operation text not null check (operation in ('INSERT', 'UPDATE', 'DELETE')),
  actor_user_id uuid,
  request_id text,
  reason text not null,
  write_surface text not null default 'legacy_direct',
  before_state jsonb,
  after_state jsonb,
  created_at timestamptz not null default now()
);

alter table praticase.admin_content_audit_events enable row level security;

create index if not exists admin_content_audit_entity_created_idx
  on praticase.admin_content_audit_events (entity_type, entity_key, created_at desc);

create index if not exists admin_content_audit_request_idx
  on praticase.admin_content_audit_events (request_id)
  where request_id is not null;

revoke all on praticase.admin_content_audit_events from public, anon, authenticated;
grant select on praticase.admin_content_audit_events to service_role;

comment on table praticase.admin_content_audit_events is
  'Append-only God Mode mutation audit. Snapshot fields redact or hash clinical/personal payloads.';

create or replace function praticase.god_mode_hash_text(p_value text)
returns text
language sql
immutable
as $$
  select encode(extensions.digest(coalesce(p_value, ''), 'sha256'), 'hex')
$$;

create or replace function praticase.god_mode_audit_snapshot(
  p_entity_type text,
  p_row jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = praticase, public, extensions
as $$
begin
  if p_row is null then
    return null;
  end if;

  case p_entity_type
    when 'home_banner' then
      return p_row - 'image_url';
    when 'exam_mode' then
      return p_row;
    when 'oral_persona' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'title', p_row ->> 'title',
        'difficulty', p_row ->> 'difficulty',
        'description', p_row ->> 'description',
        'voice_style', p_row ->> 'voice_style',
        'patience_level', p_row -> 'patience_level',
        'panel_role', p_row ->> 'panel_role',
        'sort_order', p_row -> 'sort_order',
        'is_active', p_row -> 'is_active',
        'system_prompt_sha256', praticase.god_mode_hash_text(p_row ->> 'system_prompt'),
        'updated_at', p_row -> 'updated_at'
      );
    when 'oral_scenario' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'branch_id', p_row ->> 'branch_id',
        'title', p_row ->> 'title',
        'difficulty_floor', p_row ->> 'difficulty_floor',
        'sort_order', p_row -> 'sort_order',
        'is_active', p_row -> 'is_active',
        'clinical_payload_sha256', praticase.god_mode_hash_text(
          coalesce(p_row ->> 'case_brief', '') ||
          coalesce(p_row ->> 'opening_complaint', '') ||
          coalesce(p_row -> 'learning_objectives', '[]'::jsonb)::text ||
          coalesce(p_row -> 'expected_differentials', '[]'::jsonb)::text ||
          coalesce(p_row -> 'red_flags', '[]'::jsonb)::text ||
          coalesce(p_row -> 'ideal_management', '[]'::jsonb)::text
        ),
        'updated_at', p_row -> 'updated_at'
      );
    when 'store_mapping' then
      return p_row;
    when 'notification_campaign' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'title', p_row ->> 'title',
        'audience', p_row ->> 'audience',
        'deep_link', p_row ->> 'deep_link',
        'is_active', p_row -> 'is_active',
        'sent_at', p_row -> 'sent_at',
        'body_sha256', praticase.god_mode_hash_text(p_row ->> 'body'),
        'target_user_count', case
          when jsonb_typeof(p_row -> 'target_user_ids') = 'array'
            then jsonb_array_length(p_row -> 'target_user_ids')
          else 0
        end,
        'updated_at', p_row -> 'updated_at'
      );
    when 'support_request' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'status', p_row ->> 'status',
        'subject_sha256', praticase.god_mode_hash_text(p_row ->> 'subject'),
        'created_at', p_row -> 'created_at',
        'updated_at', p_row -> 'updated_at'
      );
    when 'case_publication' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'slug', p_row ->> 'slug',
        'title', p_row ->> 'title',
        'branch', p_row ->> 'branch',
        'difficulty', p_row ->> 'difficulty',
        'is_published', p_row -> 'is_published',
        'updated_at', p_row -> 'updated_at'
      );
    when 'generated_checklist' then
      return jsonb_build_object(
        'id', p_row ->> 'id',
        'case_id', p_row ->> 'case_id',
        'course', p_row ->> 'course',
        'case_name', p_row ->> 'case_name',
        'difficulty', p_row ->> 'difficulty',
        'diagnosis_name', p_row ->> 'diagnosis_name',
        'content_type', p_row ->> 'content_type',
        'ai_provider', p_row ->> 'ai_provider',
        'ai_model', p_row ->> 'ai_model',
        'source_format_file', p_row ->> 'source_format_file',
        'payload_sha256', praticase.god_mode_hash_text((p_row -> 'payload')::text),
        'updated_at', p_row -> 'updated_at'
      );
    else
      return '{}'::jsonb;
  end case;
end;
$$;

create or replace function praticase.god_mode_entity_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_old jsonb := case when TG_OP = 'INSERT' then null else to_jsonb(old) end;
  v_new jsonb := case when TG_OP = 'DELETE' then null else to_jsonb(new) end;
  v_row jsonb := coalesce(v_new, v_old);
  v_entity_type text := coalesce(TG_ARGV[0], TG_TABLE_NAME);
  v_entity_key text;
  v_actor_user_id uuid;
  v_actor_setting text;
begin
  v_entity_key := coalesce(
    nullif(v_row ->> 'id', ''),
    nullif(v_row ->> 'product_code', ''),
    nullif(v_row ->> 'slug', ''),
    'unknown'
  );
  v_actor_setting := nullif(current_setting('praticase.audit.actor_user_id', true), '');
  if v_actor_setting is not null then
    begin
      v_actor_user_id := v_actor_setting::uuid;
    exception when invalid_text_representation then
      v_actor_user_id := null;
    end;
  end if;

  insert into praticase.admin_content_audit_events(
    entity_type,
    entity_key,
    operation,
    actor_user_id,
    request_id,
    reason,
    write_surface,
    before_state,
    after_state
  )
  values (
    v_entity_type,
    v_entity_key,
    TG_OP,
    v_actor_user_id,
    nullif(current_setting('praticase.audit.request_id', true), ''),
    coalesce(
      nullif(current_setting('praticase.audit.reason', true), ''),
      'legacy_direct_write'
    ),
    coalesce(
      nullif(current_setting('praticase.audit.write_surface', true), ''),
      'legacy_direct'
    ),
    praticase.god_mode_audit_snapshot(v_entity_type, v_old),
    praticase.god_mode_audit_snapshot(v_entity_type, v_new)
  );

  if TG_OP = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create or replace function praticase.god_mode_set_audit_context(
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
begin
  if p_actor_user_id is null or not exists (
    select 1 from auth.users users where users.id = p_actor_user_id
  ) then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_ACTOR';
  end if;
  if char_length(trim(coalesce(p_request_id, ''))) < 8
      or char_length(p_request_id) > 120 then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_REQUEST_ID';
  end if;
  if char_length(trim(coalesce(p_reason, ''))) < 5
      or char_length(p_reason) > 500 then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_REASON';
  end if;

  perform set_config('praticase.audit.actor_user_id', p_actor_user_id::text, true);
  perform set_config('praticase.audit.request_id', trim(p_request_id), true);
  perform set_config('praticase.audit.reason', trim(p_reason), true);
  perform set_config('praticase.audit.write_surface', 'god_mode_rpc', true);
end;
$$;

create or replace function praticase.god_mode_valid_route(p_value text)
returns boolean
language sql
immutable
as $$
  select p_value is null
    or trim(p_value) = ''
    or trim(p_value) ~ '^/[A-Za-z0-9/_?=&.-]*$'
    or trim(p_value) ~ '^https://(www\.)?praticase\.medasi\.com\.tr(/[A-Za-z0-9/_?=&.-]*)?$'
$$;

create or replace function praticase.god_mode_upsert_banner(
  p_id uuid,
  p_title text,
  p_subtitle text,
  p_cta_label text,
  p_cta_route text,
  p_deep_link text,
  p_image_storage_path text,
  p_image_url text,
  p_image_alt_text text,
  p_sort_order integer,
  p_is_active boolean,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.home_banners
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.home_banners%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if char_length(trim(coalesce(p_title, ''))) = 0
      or char_length(p_title) > 160 then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_BANNER_TITLE';
  end if;
  if char_length(trim(coalesce(p_cta_label, ''))) = 0
      or char_length(p_cta_label) > 60 then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_BANNER_CTA';
  end if;
  if not praticase.god_mode_valid_route(p_cta_route)
      or not praticase.god_mode_valid_route(p_deep_link) then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_ROUTE';
  end if;
  if p_starts_at is not null and p_ends_at is not null and p_starts_at >= p_ends_at then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_BANNER_WINDOW';
  end if;

  insert into praticase.home_banners(
    id, title, subtitle, cta_label, cta_route, deep_link,
    image_storage_path, image_url, image_alt_text, sort_order, is_active,
    starts_at, ends_at, updated_at
  )
  values (
    coalesce(p_id, extensions.gen_random_uuid()), trim(p_title),
    coalesce(p_subtitle, ''), trim(p_cta_label), nullif(trim(p_cta_route), ''),
    nullif(trim(p_deep_link), ''), nullif(trim(p_image_storage_path), ''),
    nullif(trim(p_image_url), ''), coalesce(p_image_alt_text, ''),
    coalesce(p_sort_order, 0), coalesce(p_is_active, true),
    p_starts_at, p_ends_at, now()
  )
  on conflict (id) do update set
    title = excluded.title,
    subtitle = excluded.subtitle,
    cta_label = excluded.cta_label,
    cta_route = excluded.cta_route,
    deep_link = excluded.deep_link,
    image_storage_path = excluded.image_storage_path,
    image_url = excluded.image_url,
    image_alt_text = excluded.image_alt_text,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    starts_at = excluded.starts_at,
    ends_at = excluded.ends_at,
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function praticase.god_mode_upsert_exam_mode(
  p_id text,
  p_title text,
  p_subtitle text,
  p_icon_key text,
  p_action_key text,
  p_sort_order integer,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.exam_mode_cards
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.exam_mode_cards%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if trim(coalesce(p_id, '')) !~ '^[a-z0-9_:-]{2,80}$'
      or char_length(trim(coalesce(p_title, ''))) = 0
      or trim(coalesce(p_action_key, '')) !~ '^[a-z0-9_:-]{2,80}$' then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_EXAM_MODE';
  end if;

  insert into praticase.exam_mode_cards(
    id, title, subtitle, icon_key, action_key, sort_order, is_active, updated_at
  ) values (
    trim(p_id), trim(p_title), coalesce(p_subtitle, ''),
    coalesce(nullif(trim(p_icon_key), ''), 'exam'), trim(p_action_key),
    coalesce(p_sort_order, 0), coalesce(p_is_active, true), now()
  )
  on conflict (id) do update set
    title = excluded.title,
    subtitle = excluded.subtitle,
    icon_key = excluded.icon_key,
    action_key = excluded.action_key,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function praticase.god_mode_upsert_oral_persona(
  p_id text,
  p_title text,
  p_difficulty text,
  p_description text,
  p_system_prompt text,
  p_voice_style text,
  p_patience_level integer,
  p_panel_role text,
  p_sort_order integer,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.oral_exam_personas
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.oral_exam_personas%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if trim(coalesce(p_id, '')) !~ '^[a-z0-9_:-]{2,80}$'
      or p_difficulty not in ('Kolay', 'Orta', 'Zor')
      or p_panel_role not in ('lead', 'second', 'observer')
      or char_length(trim(coalesce(p_title, ''))) = 0
      or char_length(trim(coalesce(p_description, ''))) = 0
      or char_length(trim(coalesce(p_system_prompt, ''))) < 20
      or p_patience_level not between 1 and 10 then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_ORAL_PERSONA';
  end if;

  insert into praticase.oral_exam_personas(
    id, title, difficulty, description, system_prompt, voice_style,
    patience_level, sort_order, panel_role, is_active, updated_at
  ) values (
    trim(p_id), trim(p_title), p_difficulty, trim(p_description),
    trim(p_system_prompt), coalesce(nullif(trim(p_voice_style), ''), 'neutral'),
    p_patience_level, coalesce(p_sort_order, 0), p_panel_role,
    coalesce(p_is_active, true), now()
  )
  on conflict (id) do update set
    title = excluded.title,
    difficulty = excluded.difficulty,
    description = excluded.description,
    system_prompt = excluded.system_prompt,
    voice_style = excluded.voice_style,
    patience_level = excluded.patience_level,
    sort_order = excluded.sort_order,
    panel_role = excluded.panel_role,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function praticase.god_mode_upsert_oral_scenario(
  p_id text,
  p_branch_id text,
  p_title text,
  p_case_brief text,
  p_opening_complaint text,
  p_learning_objectives jsonb,
  p_expected_differentials jsonb,
  p_red_flags jsonb,
  p_ideal_management jsonb,
  p_difficulty_floor text,
  p_sort_order integer,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.oral_exam_scenarios
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.oral_exam_scenarios%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if trim(coalesce(p_id, '')) !~ '^[a-z0-9_:-]{2,100}$'
      or char_length(trim(coalesce(p_title, ''))) = 0
      or char_length(trim(coalesce(p_case_brief, ''))) < 20
      or char_length(trim(coalesce(p_opening_complaint, ''))) = 0
      or p_difficulty_floor not in ('Kolay', 'Orta', 'Zor')
      or jsonb_typeof(coalesce(p_learning_objectives, '[]'::jsonb)) <> 'array'
      or jsonb_typeof(coalesce(p_expected_differentials, '[]'::jsonb)) <> 'array'
      or jsonb_array_length(coalesce(p_expected_differentials, '[]'::jsonb)) = 0
      or jsonb_typeof(coalesce(p_red_flags, '[]'::jsonb)) <> 'array'
      or jsonb_typeof(coalesce(p_ideal_management, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_ORAL_SCENARIO';
  end if;

  insert into praticase.oral_exam_scenarios(
    id, branch_id, title, case_brief, opening_complaint, learning_objectives,
    expected_differentials, red_flags, ideal_management, difficulty_floor,
    sort_order, is_active, updated_at
  ) values (
    trim(p_id), trim(p_branch_id), trim(p_title), trim(p_case_brief),
    trim(p_opening_complaint), coalesce(p_learning_objectives, '[]'::jsonb),
    coalesce(p_expected_differentials, '[]'::jsonb),
    coalesce(p_red_flags, '[]'::jsonb), coalesce(p_ideal_management, '[]'::jsonb),
    p_difficulty_floor, coalesce(p_sort_order, 0), coalesce(p_is_active, true), now()
  )
  on conflict (id) do update set
    branch_id = excluded.branch_id,
    title = excluded.title,
    case_brief = excluded.case_brief,
    opening_complaint = excluded.opening_complaint,
    learning_objectives = excluded.learning_objectives,
    expected_differentials = excluded.expected_differentials,
    red_flags = excluded.red_flags,
    ideal_management = excluded.ideal_management,
    difficulty_floor = excluded.difficulty_floor,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function praticase.god_mode_upsert_store_mapping(
  p_product_code text,
  p_app_store_product_id text,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.store_product_app_mappings
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.store_product_app_mappings%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if char_length(trim(coalesce(p_product_code, ''))) = 0
      or char_length(trim(coalesce(p_app_store_product_id, ''))) < 3
      or p_app_store_product_id ~ '\s'
      or not exists (
        select 1 from public.store_products products
        where products.code = trim(p_product_code)
      ) then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_STORE_MAPPING';
  end if;

  insert into praticase.store_product_app_mappings(
    product_code, app_store_product_id, is_active, updated_at
  ) values (
    trim(p_product_code), trim(p_app_store_product_id),
    coalesce(p_is_active, true), now()
  )
  on conflict (product_code) do update set
    app_store_product_id = excluded.app_store_product_id,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;
  return v_row;
exception when unique_violation then
  raise exception using errcode = '23505', message = 'GOD_MODE_STORE_PRODUCT_ID_IN_USE';
end;
$$;

create or replace function praticase.god_mode_set_support_status(
  p_request_id uuid,
  p_status text,
  p_actor_user_id uuid,
  p_audit_request_id text,
  p_reason text
)
returns table(request_id uuid, status text, updated_at timestamptz)
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
begin
  perform praticase.god_mode_set_audit_context(
    p_actor_user_id, p_audit_request_id, p_reason
  );
  if p_status not in ('open', 'in_progress', 'resolved', 'closed') then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_SUPPORT_STATUS';
  end if;
  return query
    update praticase.contact_requests requests
    set status = p_status, updated_at = now()
    where requests.id = p_request_id
    returning requests.id, requests.status, requests.updated_at;
  if not found then
    raise exception using errcode = 'P0002', message = 'GOD_MODE_SUPPORT_REQUEST_NOT_FOUND';
  end if;
end;
$$;

create or replace function praticase.god_mode_upsert_notification_campaign(
  p_id uuid,
  p_title text,
  p_body text,
  p_audience text,
  p_target_user_ids uuid[],
  p_deep_link text,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.notification_campaigns
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_row praticase.notification_campaigns%rowtype;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if char_length(trim(coalesce(p_title, ''))) = 0
      or p_audience not in ('all', 'users')
      or (p_audience = 'users' and coalesce(cardinality(p_target_user_ids), 0) = 0)
      or not praticase.god_mode_valid_route(p_deep_link) then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_NOTIFICATION_CAMPAIGN';
  end if;

  insert into praticase.notification_campaigns(
    id, title, body, audience, target_user_ids, deep_link,
    is_active, created_by, updated_at
  ) values (
    coalesce(p_id, extensions.gen_random_uuid()), trim(p_title),
    coalesce(p_body, ''), p_audience,
    case when p_audience = 'users' then p_target_user_ids else null end,
    nullif(trim(p_deep_link), ''), coalesce(p_is_active, true),
    p_actor_user_id, now()
  )
  on conflict (id) do update set
    title = excluded.title,
    body = excluded.body,
    audience = excluded.audience,
    target_user_ids = excluded.target_user_ids,
    deep_link = excluded.deep_link,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;
  return v_row;
end;
$$;

create or replace function praticase.god_mode_upsert_generated_checklist(
  p_content_type text,
  p_id uuid,
  p_course text,
  p_case_name text,
  p_difficulty text,
  p_diagnosis_name text,
  p_payload jsonb,
  p_ai_provider text,
  p_ai_model text,
  p_source_format_file text,
  p_generated_at timestamptz,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_id uuid := coalesce(p_id, extensions.gen_random_uuid());
  v_case_id uuid;
begin
  perform praticase.god_mode_set_audit_context(p_actor_user_id, p_request_id, p_reason);
  if p_content_type not in ('history', 'physical_exam', 'laboratory', 'imaging', 'diagnostic')
      or p_difficulty not in ('Kolay', 'Orta', 'Zor')
      or char_length(trim(coalesce(p_course, ''))) = 0
      or char_length(trim(coalesce(p_case_name, ''))) = 0
      or jsonb_typeof(coalesce(p_payload, '{}'::jsonb)) <> 'object' then
    raise exception using errcode = '22023', message = 'GOD_MODE_INVALID_CHECKLIST';
  end if;

  if p_content_type = 'history' then
    insert into praticase.praticase_history_checklists(
      id, course, case_name, difficulty, diagnosis_name, content_type, payload,
      ai_provider, ai_model, source_format_file, generated_at,
      created_by_admin_user_id
    ) values (
      v_id, trim(p_course), trim(p_case_name), p_difficulty,
      coalesce(p_diagnosis_name, ''), 'history', p_payload,
      coalesce(p_ai_provider, ''), coalesce(p_ai_model, ''),
      coalesce(nullif(trim(p_source_format_file), ''), 'anamnez.json'),
      coalesce(p_generated_at, now()), p_actor_user_id
    ) on conflict (id) do update set
      course = excluded.course, case_name = excluded.case_name,
      difficulty = excluded.difficulty, diagnosis_name = excluded.diagnosis_name,
      payload = excluded.payload, ai_provider = excluded.ai_provider,
      ai_model = excluded.ai_model, source_format_file = excluded.source_format_file,
      generated_at = excluded.generated_at,
      created_by_admin_user_id = excluded.created_by_admin_user_id
    returning case_id into v_case_id;
  elsif p_content_type = 'physical_exam' then
    insert into praticase.praticase_physical_exam_checklists(
      id, course, case_name, difficulty, diagnosis_name, content_type, payload,
      ai_provider, ai_model, source_format_file, generated_at,
      created_by_admin_user_id
    ) values (
      v_id, trim(p_course), trim(p_case_name), p_difficulty,
      coalesce(p_diagnosis_name, ''), 'physicalExam', p_payload,
      coalesce(p_ai_provider, ''), coalesce(p_ai_model, ''),
      coalesce(nullif(trim(p_source_format_file), ''), 'fizik_muayene.json'),
      coalesce(p_generated_at, now()), p_actor_user_id
    ) on conflict (id) do update set
      course = excluded.course, case_name = excluded.case_name,
      difficulty = excluded.difficulty, diagnosis_name = excluded.diagnosis_name,
      payload = excluded.payload, ai_provider = excluded.ai_provider,
      ai_model = excluded.ai_model, source_format_file = excluded.source_format_file,
      generated_at = excluded.generated_at,
      created_by_admin_user_id = excluded.created_by_admin_user_id
    returning case_id into v_case_id;
  elsif p_content_type = 'laboratory' then
    insert into praticase.praticase_laboratory_checklists(
      id, course, case_name, difficulty, diagnosis_name, content_type, payload,
      ai_provider, ai_model, source_format_file, generated_at,
      created_by_admin_user_id
    ) values (
      v_id, trim(p_course), trim(p_case_name), p_difficulty,
      coalesce(p_diagnosis_name, ''), 'laboratory', p_payload,
      coalesce(p_ai_provider, ''), coalesce(p_ai_model, ''),
      coalesce(nullif(trim(p_source_format_file), ''), 'laboratuvar.json'),
      coalesce(p_generated_at, now()), p_actor_user_id
    ) on conflict (id) do update set
      course = excluded.course, case_name = excluded.case_name,
      difficulty = excluded.difficulty, diagnosis_name = excluded.diagnosis_name,
      payload = excluded.payload, ai_provider = excluded.ai_provider,
      ai_model = excluded.ai_model, source_format_file = excluded.source_format_file,
      generated_at = excluded.generated_at,
      created_by_admin_user_id = excluded.created_by_admin_user_id
    returning case_id into v_case_id;
  elsif p_content_type = 'imaging' then
    insert into praticase.praticase_imaging_checklists(
      id, course, case_name, difficulty, diagnosis_name, content_type, payload,
      ai_provider, ai_model, source_format_file, generated_at,
      created_by_admin_user_id
    ) values (
      v_id, trim(p_course), trim(p_case_name), p_difficulty,
      coalesce(p_diagnosis_name, ''), 'imaging', p_payload,
      coalesce(p_ai_provider, ''), coalesce(p_ai_model, ''),
      coalesce(nullif(trim(p_source_format_file), ''), 'goruntuleme.json'),
      coalesce(p_generated_at, now()), p_actor_user_id
    ) on conflict (id) do update set
      course = excluded.course, case_name = excluded.case_name,
      difficulty = excluded.difficulty, diagnosis_name = excluded.diagnosis_name,
      payload = excluded.payload, ai_provider = excluded.ai_provider,
      ai_model = excluded.ai_model, source_format_file = excluded.source_format_file,
      generated_at = excluded.generated_at,
      created_by_admin_user_id = excluded.created_by_admin_user_id
    returning case_id into v_case_id;
  else
    insert into praticase.praticase_diagnostic_checklists(
      id, course, case_name, difficulty, diagnosis_name, content_type, payload,
      ai_provider, ai_model, source_format_file, generated_at,
      created_by_admin_user_id
    ) values (
      v_id, trim(p_course), trim(p_case_name), p_difficulty,
      coalesce(p_diagnosis_name, ''), 'differentialDiagnosis', p_payload,
      coalesce(p_ai_provider, ''), coalesce(p_ai_model, ''),
      coalesce(nullif(trim(p_source_format_file), ''), 'on_tani_ayirici_tani.json'),
      coalesce(p_generated_at, now()), p_actor_user_id
    ) on conflict (id) do update set
      course = excluded.course, case_name = excluded.case_name,
      difficulty = excluded.difficulty, diagnosis_name = excluded.diagnosis_name,
      payload = excluded.payload, ai_provider = excluded.ai_provider,
      ai_model = excluded.ai_model, source_format_file = excluded.source_format_file,
      generated_at = excluded.generated_at,
      created_by_admin_user_id = excluded.created_by_admin_user_id
    returning case_id into v_case_id;
  end if;

  return jsonb_build_object(
    'content_type', p_content_type,
    'record_id', v_id,
    'case_id', v_case_id
  );
end;
$$;

drop trigger if exists god_mode_audit_home_banners on praticase.home_banners;
create trigger god_mode_audit_home_banners
after insert or update or delete on praticase.home_banners
for each row execute function praticase.god_mode_entity_audit_trigger('home_banner');

drop trigger if exists god_mode_audit_exam_mode_cards on praticase.exam_mode_cards;
create trigger god_mode_audit_exam_mode_cards
after insert or update or delete on praticase.exam_mode_cards
for each row execute function praticase.god_mode_entity_audit_trigger('exam_mode');

drop trigger if exists god_mode_audit_oral_personas on praticase.oral_exam_personas;
create trigger god_mode_audit_oral_personas
after insert or update or delete on praticase.oral_exam_personas
for each row execute function praticase.god_mode_entity_audit_trigger('oral_persona');

drop trigger if exists god_mode_audit_oral_scenarios on praticase.oral_exam_scenarios;
create trigger god_mode_audit_oral_scenarios
after insert or update or delete on praticase.oral_exam_scenarios
for each row execute function praticase.god_mode_entity_audit_trigger('oral_scenario');

drop trigger if exists god_mode_audit_store_mappings on praticase.store_product_app_mappings;
create trigger god_mode_audit_store_mappings
after insert or update or delete on praticase.store_product_app_mappings
for each row execute function praticase.god_mode_entity_audit_trigger('store_mapping');

drop trigger if exists god_mode_audit_notification_campaigns on praticase.notification_campaigns;
create trigger god_mode_audit_notification_campaigns
after insert or update or delete on praticase.notification_campaigns
for each row execute function praticase.god_mode_entity_audit_trigger('notification_campaign');

drop trigger if exists god_mode_audit_contact_requests on praticase.contact_requests;
create trigger god_mode_audit_contact_requests
after update of status on praticase.contact_requests
for each row execute function praticase.god_mode_entity_audit_trigger('support_request');

drop trigger if exists god_mode_audit_case_publication on praticase.cases;
create trigger god_mode_audit_case_publication
after insert or update of is_published or delete on praticase.cases
for each row execute function praticase.god_mode_entity_audit_trigger('case_publication');

drop trigger if exists god_mode_audit_history_checklists
  on praticase.praticase_history_checklists;
create trigger god_mode_audit_history_checklists
after insert or update or delete on praticase.praticase_history_checklists
for each row execute function praticase.god_mode_entity_audit_trigger('generated_checklist');

drop trigger if exists god_mode_audit_physical_checklists
  on praticase.praticase_physical_exam_checklists;
create trigger god_mode_audit_physical_checklists
after insert or update or delete on praticase.praticase_physical_exam_checklists
for each row execute function praticase.god_mode_entity_audit_trigger('generated_checklist');

drop trigger if exists god_mode_audit_laboratory_checklists
  on praticase.praticase_laboratory_checklists;
create trigger god_mode_audit_laboratory_checklists
after insert or update or delete on praticase.praticase_laboratory_checklists
for each row execute function praticase.god_mode_entity_audit_trigger('generated_checklist');

drop trigger if exists god_mode_audit_imaging_checklists
  on praticase.praticase_imaging_checklists;
create trigger god_mode_audit_imaging_checklists
after insert or update or delete on praticase.praticase_imaging_checklists
for each row execute function praticase.god_mode_entity_audit_trigger('generated_checklist');

drop trigger if exists god_mode_audit_diagnostic_checklists
  on praticase.praticase_diagnostic_checklists;
create trigger god_mode_audit_diagnostic_checklists
after insert or update or delete on praticase.praticase_diagnostic_checklists
for each row execute function praticase.god_mode_entity_audit_trigger('generated_checklist');

revoke all on function praticase.god_mode_set_audit_context(uuid, text, text)
  from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_banner(
  uuid, text, text, text, text, text, text, text, text, integer, boolean,
  timestamptz, timestamptz, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_exam_mode(
  text, text, text, text, text, integer, boolean, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_oral_persona(
  text, text, text, text, text, text, integer, text, integer, boolean,
  uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_oral_scenario(
  text, text, text, text, text, jsonb, jsonb, jsonb, jsonb, text,
  integer, boolean, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_store_mapping(
  text, text, boolean, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_set_support_status(
  uuid, text, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_notification_campaign(
  uuid, text, text, text, uuid[], text, boolean, uuid, text, text
) from public, anon, authenticated;
revoke all on function praticase.god_mode_upsert_generated_checklist(
  text, uuid, text, text, text, text, jsonb, text, text, text,
  timestamptz, uuid, text, text
) from public, anon, authenticated;

grant execute on function praticase.god_mode_set_audit_context(uuid, text, text)
  to service_role;
grant execute on function praticase.god_mode_upsert_banner(
  uuid, text, text, text, text, text, text, text, text, integer, boolean,
  timestamptz, timestamptz, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_exam_mode(
  text, text, text, text, text, integer, boolean, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_oral_persona(
  text, text, text, text, text, text, integer, text, integer, boolean,
  uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_oral_scenario(
  text, text, text, text, text, jsonb, jsonb, jsonb, jsonb, text,
  integer, boolean, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_store_mapping(
  text, text, boolean, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_set_support_status(
  uuid, text, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_notification_campaign(
  uuid, text, text, text, uuid[], text, boolean, uuid, text, text
) to service_role;
grant execute on function praticase.god_mode_upsert_generated_checklist(
  text, uuid, text, text, text, text, jsonb, text, text, text,
  timestamptz, uuid, text, text
) to service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values (
  '202605270002_praticase_god_mode_management_audit',
  '202605270002_praticase_god_mode_management_audit.sql'
)
on conflict (version) do nothing;

commit;
