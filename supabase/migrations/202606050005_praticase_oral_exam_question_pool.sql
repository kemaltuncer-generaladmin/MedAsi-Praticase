-- Admin-managed oral exam question pool.
-- The mobile app never reads this table directly; the Edge Function uses it as
-- hidden question hooks so oral exams stay sharp, fast, and tied to answers.

begin;

create table if not exists praticase.oral_exam_question_pool (
  id text primary key,
  branch_id text references praticase.oral_exam_branches(id) on delete cascade,
  scenario_id text references praticase.oral_exam_scenarios(id) on delete cascade,
  phase text not null default 'follow_up'
    check (
      phase in (
        'opening',
        'history',
        'physical_exam',
        'tests',
        'differential',
        'management',
        'safety',
        'follow_up',
        'wrap_up'
      )
    ),
  question text not null,
  expected_focus jsonb not null default '[]'::jsonb
    check (jsonb_typeof(expected_focus) = 'array'),
  follow_up_hooks jsonb not null default '[]'::jsonb
    check (jsonb_typeof(follow_up_hooks) = 'array'),
  severity text not null default 'important'
    check (severity in ('routine', 'important', 'critical')),
  exam_format text not null default 'any'
    check (exam_format in ('any', 'solo', 'panel')),
  persona_role text not null default 'any'
    check (persona_role in ('any', 'lead', 'second', 'observer')),
  tags jsonb not null default '[]'::jsonb
    check (jsonb_typeof(tags) = 'array'),
  admin_note text not null default '',
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_by_admin_user_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint oral_exam_question_pool_question_len
    check (char_length(trim(question)) between 10 and 500),
  constraint oral_exam_question_pool_scope_check
    check (
      scenario_id is null
      or branch_id is not null
    )
);

alter table praticase.oral_exam_question_pool enable row level security;

revoke all on praticase.oral_exam_question_pool from public, anon, authenticated;
grant select, insert, update, delete on praticase.oral_exam_question_pool
  to service_role;

create index if not exists oral_exam_question_pool_lookup_idx
  on praticase.oral_exam_question_pool(
    is_active,
    exam_format,
    branch_id,
    scenario_id,
    phase,
    severity,
    sort_order
  );

create index if not exists oral_exam_question_pool_role_idx
  on praticase.oral_exam_question_pool(is_active, persona_role, sort_order);

comment on table praticase.oral_exam_question_pool is
  'Hidden, admin-managed question hooks for PratiCase oral exam moderation.';

insert into praticase.oral_exam_question_pool(
  id,
  branch_id,
  phase,
  question,
  expected_focus,
  follow_up_hooks,
  severity,
  persona_role,
  tags,
  sort_order
) values
  (
    'oral_q_global_stability_001',
    null,
    'safety',
    'Bu hastanın stabil olduğunu hangi vital veya klinik bulguyla kanıtlıyorsun?',
    '["hemodinami", "vital bulgular", "hasta güvenliği"]'::jsonb,
    '["stabil", "instabil", "vital", "hipotansiyon"]'::jsonb,
    'critical',
    'lead',
    '["hasta_guvenligi", "klinik_oncelik"]'::jsonb,
    10
  ),
  (
    'oral_q_global_reasoning_001',
    null,
    'follow_up',
    'Bu önceliği seçmene neden olan en güçlü bulgu hangisi?',
    '["kanıta dayalı gerekçe", "önceliklendirme"]'::jsonb,
    '["öncelik", "ilk", "başlarım", "düşünürüm"]'::jsonb,
    'important',
    'second',
    '["gerekce", "akil_yurutme"]'::jsonb,
    20
  ),
  (
    'oral_q_global_tests_001',
    null,
    'tests',
    'İstediğin tetkik hangi tanıyı doğrulayacak veya hangi tehlikeli tanıyı dışlayacak?',
    '["tetkik endikasyonu", "ayırıcı tanı", "gereksiz tetkik"]'::jsonb,
    '["tetkik", "test", "laboratuvar", "bt", "usg", "hemogram", "troponin"]'::jsonb,
    'important',
    'any',
    '["tetkik", "ayirici_tani"]'::jsonb,
    30
  ),
  (
    'oral_q_global_management_001',
    null,
    'management',
    'Bu tedaviyi şimdi vermeni gerektiren klinik eşik nedir?',
    '["tedavi endikasyonu", "zamanlama", "risk"]'::jsonb,
    '["tedavi", "antibiyotik", "antikoagülan", "sıvı", "insülin", "operasyon"]'::jsonb,
    'important',
    'lead',
    '["yonetim", "endikasyon"]'::jsonb,
    40
  ),
  (
    'oral_q_acil_first_001',
    'acil',
    'opening',
    'İlk 10 dakikada hangi üç şeyi aynı anda yaparsın?',
    '["ABC", "monitörizasyon", "EKG veya kritik tetkik"]'::jsonb,
    '["acil", "ilk yaklaşım", "öncelik"]'::jsonb,
    'critical',
    'lead',
    '["acil", "ilk_10_dakika"]'::jsonb,
    100
  ),
  (
    'oral_q_acil_aks_001',
    'acil',
    'follow_up',
    'AKS diyorsun; ilk EKG’de hangi bulgu yönetimini değiştirir?',
    '["ST elevasyonu", "resiprok değişiklik", "ritim", "sağ ventrikül infarktı"]'::jsonb,
    '["aks", "stemi", "nstemi", "göğüs ağrısı", "troponin", "ekg"]'::jsonb,
    'critical',
    'lead',
    '["aks", "ekg", "reperfuzyon"]'::jsonb,
    110
  ),
  (
    'oral_q_cerrahi_acute_abdomen_001',
    'cerrahi',
    'follow_up',
    'Akut batın diyorsun; hangi muayene bulgusu seni perforasyon açısından uyarır?',
    '["defans", "rebound", "tahta karın", "peritonit"]'::jsonb,
    '["akut batın", "apandisit", "perforasyon", "rebound", "defans"]'::jsonb,
    'critical',
    'lead',
    '["cerrahi", "akut_batin"]'::jsonb,
    120
  ),
  (
    'oral_q_dahiliye_metabolic_001',
    'dahiliye',
    'management',
    'Bu tabloda tedaviye başlamadan önce hangi elektrolit sonucunu görmeden insülin veremezsin?',
    '["potasyum", "DKA güvenli yönetim", "aritmi riski"]'::jsonb,
    '["dka", "insülin", "ketoasidoz", "glukoz", "potasyum"]'::jsonb,
    'critical',
    'lead',
    '["dahiliye", "dka", "hasta_guvenligi"]'::jsonb,
    130
  ),
  (
    'oral_q_kadin_pregnancy_001',
    'kadin_dogum',
    'safety',
    'Üreme çağındaki bu hastada hangi tanıyı dışlamadan güvenle ilerleyemezsin?',
    '["gebelik", "ektopik gebelik", "beta-hCG", "hasta güvenliği"]'::jsonb,
    '["amenore", "pelvik ağrı", "kanama", "gebelik", "beta hcg"]'::jsonb,
    'critical',
    'lead',
    '["kadin_dogum", "ektopik"]'::jsonb,
    140
  ),
  (
    'oral_q_cocuk_red_flag_001',
    'cocuk',
    'safety',
    'Bu çocukta yatış kararı verdirecek kırmızı bayrak hangisi?',
    '["hipoksemi", "beslenememe", "dehidratasyon", "toksik görünüm"]'::jsonb,
    '["çocuk", "bebek", "ateş", "nefes darlığı", "yatış"]'::jsonb,
    'critical',
    'lead',
    '["pediatri", "yatış", "kirmizi_bayrak"]'::jsonb,
    150
  )
on conflict (id) do update set
  branch_id = excluded.branch_id,
  phase = excluded.phase,
  question = excluded.question,
  expected_focus = excluded.expected_focus,
  follow_up_hooks = excluded.follow_up_hooks,
  severity = excluded.severity,
  persona_role = excluded.persona_role,
  tags = excluded.tags,
  sort_order = excluded.sort_order,
  is_active = true,
  updated_at = now();

create or replace function praticase.god_mode_upsert_oral_question_pool(
  p_id text,
  p_branch_id text,
  p_scenario_id text,
  p_phase text,
  p_question text,
  p_expected_focus jsonb,
  p_follow_up_hooks jsonb,
  p_severity text,
  p_exam_format text,
  p_persona_role text,
  p_tags jsonb,
  p_admin_note text,
  p_sort_order integer,
  p_is_active boolean,
  p_actor_user_id uuid,
  p_request_id text,
  p_reason text
)
returns praticase.oral_exam_question_pool
language plpgsql
security definer
set search_path = praticase, public, auth, extensions
as $$
declare
  v_before jsonb;
  v_after jsonb;
  v_row praticase.oral_exam_question_pool%rowtype;
  v_operation text;
begin
  perform praticase.god_mode_set_audit_context(
    p_actor_user_id,
    p_request_id,
    p_reason
  );

  if trim(coalesce(p_id, '')) !~ '^[a-z0-9_:-]{2,120}$'
      or char_length(trim(coalesce(p_question, ''))) < 10
      or coalesce(p_phase, '') not in (
        'opening',
        'history',
        'physical_exam',
        'tests',
        'differential',
        'management',
        'safety',
        'follow_up',
        'wrap_up'
      )
      or coalesce(p_severity, '') not in ('routine', 'important', 'critical')
      or coalesce(p_exam_format, '') not in ('any', 'solo', 'panel')
      or coalesce(p_persona_role, '') not in ('any', 'lead', 'second', 'observer')
      or jsonb_typeof(coalesce(p_expected_focus, '[]'::jsonb)) <> 'array'
      or jsonb_typeof(coalesce(p_follow_up_hooks, '[]'::jsonb)) <> 'array'
      or jsonb_typeof(coalesce(p_tags, '[]'::jsonb)) <> 'array' then
    raise exception using errcode = '22023',
      message = 'GOD_MODE_INVALID_ORAL_QUESTION';
  end if;

  select to_jsonb(existing.*)
    into v_before
  from praticase.oral_exam_question_pool existing
  where existing.id = trim(p_id);
  v_operation := case when v_before is null then 'INSERT' else 'UPDATE' end;

  insert into praticase.oral_exam_question_pool(
    id,
    branch_id,
    scenario_id,
    phase,
    question,
    expected_focus,
    follow_up_hooks,
    severity,
    exam_format,
    persona_role,
    tags,
    admin_note,
    sort_order,
    is_active,
    created_by_admin_user_id,
    updated_at
  ) values (
    trim(p_id),
    nullif(trim(coalesce(p_branch_id, '')), ''),
    nullif(trim(coalesce(p_scenario_id, '')), ''),
    p_phase,
    trim(p_question),
    coalesce(p_expected_focus, '[]'::jsonb),
    coalesce(p_follow_up_hooks, '[]'::jsonb),
    p_severity,
    p_exam_format,
    p_persona_role,
    coalesce(p_tags, '[]'::jsonb),
    trim(coalesce(p_admin_note, '')),
    coalesce(p_sort_order, 0),
    coalesce(p_is_active, true),
    p_actor_user_id,
    now()
  )
  on conflict (id) do update set
    branch_id = excluded.branch_id,
    scenario_id = excluded.scenario_id,
    phase = excluded.phase,
    question = excluded.question,
    expected_focus = excluded.expected_focus,
    follow_up_hooks = excluded.follow_up_hooks,
    severity = excluded.severity,
    exam_format = excluded.exam_format,
    persona_role = excluded.persona_role,
    tags = excluded.tags,
    admin_note = excluded.admin_note,
    sort_order = excluded.sort_order,
    is_active = excluded.is_active,
    updated_at = now()
  returning * into v_row;

  v_after := to_jsonb(v_row);
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
  ) values (
    'oral_question_pool',
    v_row.id,
    v_operation,
    p_actor_user_id,
    trim(p_request_id),
    trim(p_reason),
    'god_mode_rpc',
    case when v_before is null then null else jsonb_build_object(
      'id', v_before ->> 'id',
      'branch_id', v_before ->> 'branch_id',
      'scenario_id', v_before ->> 'scenario_id',
      'phase', v_before ->> 'phase',
      'severity', v_before ->> 'severity',
      'exam_format', v_before ->> 'exam_format',
      'persona_role', v_before ->> 'persona_role',
      'is_active', v_before -> 'is_active',
      'question_sha256', praticase.god_mode_hash_text(v_before ->> 'question'),
      'expected_focus_count',
        jsonb_array_length(coalesce(v_before -> 'expected_focus', '[]'::jsonb)),
      'follow_up_hooks_count',
        jsonb_array_length(coalesce(v_before -> 'follow_up_hooks', '[]'::jsonb))
    ) end,
    jsonb_build_object(
      'id', v_after ->> 'id',
      'branch_id', v_after ->> 'branch_id',
      'scenario_id', v_after ->> 'scenario_id',
      'phase', v_after ->> 'phase',
      'severity', v_after ->> 'severity',
      'exam_format', v_after ->> 'exam_format',
      'persona_role', v_after ->> 'persona_role',
      'is_active', v_after -> 'is_active',
      'question_sha256', praticase.god_mode_hash_text(v_after ->> 'question'),
      'expected_focus_count',
        jsonb_array_length(coalesce(v_after -> 'expected_focus', '[]'::jsonb)),
      'follow_up_hooks_count',
        jsonb_array_length(coalesce(v_after -> 'follow_up_hooks', '[]'::jsonb))
    )
  );

  return v_row;
end;
$$;

revoke all on function praticase.god_mode_upsert_oral_question_pool(
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb,
  text,
  text,
  text,
  jsonb,
  text,
  integer,
  boolean,
  uuid,
  text,
  text
) from public, anon, authenticated;
grant execute on function praticase.god_mode_upsert_oral_question_pool(
  text,
  text,
  text,
  text,
  text,
  jsonb,
  jsonb,
  text,
  text,
  text,
  jsonb,
  text,
  integer,
  boolean,
  uuid,
  text,
  text
) to service_role;

insert into praticase.self_hosted_schema_migrations(version, filename)
values (
  '202606050005',
  '202606050005_praticase_oral_exam_question_pool.sql'
)
on conflict (version) do nothing;

commit;
