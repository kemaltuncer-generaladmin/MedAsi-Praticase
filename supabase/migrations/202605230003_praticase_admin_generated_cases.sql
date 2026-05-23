begin;

create table if not exists praticase.praticase_history_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  course text not null default '',
  case_name text not null default '',
  difficulty text not null default 'Orta',
  diagnosis_name text not null default '',
  content_type text not null default 'history',
  payload jsonb not null default '{}'::jsonb,
  ai_provider text not null default '',
  ai_model text not null default '',
  source_format_file text not null default 'anamnez.json',
  generated_at timestamptz not null default now(),
  created_by_admin_user_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.praticase_physical_exam_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  course text not null default '',
  case_name text not null default '',
  difficulty text not null default 'Orta',
  diagnosis_name text not null default '',
  content_type text not null default 'physicalExam',
  payload jsonb not null default '{}'::jsonb,
  ai_provider text not null default '',
  ai_model text not null default '',
  source_format_file text not null default 'fizik_muayene.json',
  generated_at timestamptz not null default now(),
  created_by_admin_user_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.praticase_laboratory_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  course text not null default '',
  case_name text not null default '',
  difficulty text not null default 'Orta',
  diagnosis_name text not null default '',
  content_type text not null default 'laboratory',
  payload jsonb not null default '{}'::jsonb,
  ai_provider text not null default '',
  ai_model text not null default '',
  source_format_file text not null default 'laboratuvar.json',
  generated_at timestamptz not null default now(),
  created_by_admin_user_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.praticase_imaging_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  course text not null default '',
  case_name text not null default '',
  difficulty text not null default 'Orta',
  diagnosis_name text not null default '',
  content_type text not null default 'imaging',
  payload jsonb not null default '{}'::jsonb,
  ai_provider text not null default '',
  ai_model text not null default '',
  source_format_file text not null default 'goruntuleme.json',
  generated_at timestamptz not null default now(),
  created_by_admin_user_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists praticase.praticase_diagnostic_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  course text not null default '',
  case_name text not null default '',
  difficulty text not null default 'Orta',
  diagnosis_name text not null default '',
  content_type text not null default 'differentialDiagnosis',
  payload jsonb not null default '{}'::jsonb,
  ai_provider text not null default '',
  ai_model text not null default '',
  source_format_file text not null default 'on_tani_ayirici_tani.json',
  generated_at timestamptz not null default now(),
  created_by_admin_user_id uuid,
  case_id uuid references praticase.cases(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table praticase.praticase_history_checklists enable row level security;
alter table praticase.praticase_physical_exam_checklists enable row level security;
alter table praticase.praticase_laboratory_checklists enable row level security;
alter table praticase.praticase_imaging_checklists enable row level security;
alter table praticase.praticase_diagnostic_checklists enable row level security;

drop policy if exists "Public can read published generated history" on praticase.praticase_history_checklists;
create policy "Public can read published generated history"
on praticase.praticase_history_checklists for select
using (case_id is not null and exists (
  select 1 from praticase.cases
  where cases.id = praticase_history_checklists.case_id
    and cases.is_published
));

drop policy if exists "Public can read published generated physical" on praticase.praticase_physical_exam_checklists;
create policy "Public can read published generated physical"
on praticase.praticase_physical_exam_checklists for select
using (case_id is not null and exists (
  select 1 from praticase.cases
  where cases.id = praticase_physical_exam_checklists.case_id
    and cases.is_published
));

drop policy if exists "Public can read published generated laboratory" on praticase.praticase_laboratory_checklists;
create policy "Public can read published generated laboratory"
on praticase.praticase_laboratory_checklists for select
using (case_id is not null and exists (
  select 1 from praticase.cases
  where cases.id = praticase_laboratory_checklists.case_id
    and cases.is_published
));

drop policy if exists "Public can read published generated imaging" on praticase.praticase_imaging_checklists;
create policy "Public can read published generated imaging"
on praticase.praticase_imaging_checklists for select
using (case_id is not null and exists (
  select 1 from praticase.cases
  where cases.id = praticase_imaging_checklists.case_id
    and cases.is_published
));

drop policy if exists "Public can read published generated diagnostic" on praticase.praticase_diagnostic_checklists;
create policy "Public can read published generated diagnostic"
on praticase.praticase_diagnostic_checklists for select
using (case_id is not null and exists (
  select 1 from praticase.cases
  where cases.id = praticase_diagnostic_checklists.case_id
    and cases.is_published
));

create or replace function praticase.safe_slug(p_text text)
returns text
language sql
immutable
as $$
  select trim(both '-' from regexp_replace(lower(coalesce(p_text, '')), '[^a-z0-9]+', '-', 'g'))
$$;

create or replace function praticase.generated_case_key(
  p_course text,
  p_case_name text,
  p_difficulty text,
  p_diagnosis_name text
)
returns text
language sql
immutable
as $$
  select md5(
    lower(trim(coalesce(p_course, ''))) || '|' ||
    lower(trim(coalesce(p_case_name, ''))) || '|' ||
    lower(trim(coalesce(p_difficulty, 'Orta'))) || '|' ||
    lower(trim(coalesce(p_diagnosis_name, '')))
  )
$$;

create or replace function praticase.generated_case_slug(
  p_course text,
  p_case_name text,
  p_difficulty text,
  p_diagnosis_name text
)
returns text
language sql
immutable
as $$
  select 'admin-' || left(praticase.generated_case_key(p_course, p_case_name, p_difficulty, p_diagnosis_name), 16)
$$;

create or replace function praticase.payload_text(p_payload jsonb, variadic p_path text[])
returns text
language sql
immutable
as $$
  select coalesce(nullif(trim(p_payload #>> p_path), ''), '')
$$;

create or replace function praticase.payload_text_array(p_value jsonb)
returns text[]
language sql
immutable
as $$
  select coalesce(array_agg(item.value), '{}')
  from jsonb_array_elements_text(coalesce(p_value, '[]'::jsonb)) as item(value)
$$;

create or replace function praticase.safe_json_int(p_value text, p_default integer default 0)
returns integer
language sql
immutable
as $$
  select case
    when trim(coalesce(p_value, '')) ~ '^-?[0-9]+$' then trim(p_value)::integer
    else p_default
  end
$$;

create or replace function praticase.safe_json_bool(p_value text, p_default boolean default false)
returns boolean
language sql
immutable
as $$
  select case
    when lower(trim(coalesce(p_value, ''))) in ('true', 't', '1', 'yes') then true
    when lower(trim(coalesce(p_value, ''))) in ('false', 'f', '0', 'no') then false
    else p_default
  end
$$;

create or replace function praticase.generated_case_profile(
  p_case_name text,
  p_diagnosis_name text,
  p_payload jsonb
)
returns jsonb
language sql
immutable
as $$
  select jsonb_build_object(
    'name', 'PratiCase Hastası',
    'age', coalesce(p_payload #>> '{caseAssumptions,defaultPatientAge}', ''),
    'gender', coalesce(p_payload #>> '{caseAssumptions,defaultPatientSex}', ''),
    'mainComplaint', coalesce(p_payload #>> '{caseAssumptions,mainComplaint}', p_diagnosis_name, ''),
    'openingLine', coalesce(p_payload #>> '{caseAssumptions,openingStatement}', 'Hocam merhaba, şikayetim için geldim.'),
    'applicationSetting', coalesce(p_payload #>> '{caseAssumptions,defaultSetting}', ''),
    'complaintDuration', '',
    'caseName', coalesce(p_case_name, ''),
    'diagnosisName', coalesce(p_diagnosis_name, '')
  )
$$;

create or replace function praticase.upsert_generated_case_shell(
  p_course text,
  p_case_name text,
  p_difficulty text,
  p_diagnosis_name text,
  p_payload jsonb
)
returns uuid
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_slug text;
  v_case_id uuid;
  v_title text;
  v_branch text;
  v_difficulty text;
  v_setting text;
  v_prompt text;
begin
  v_slug := praticase.generated_case_slug(p_course, p_case_name, p_difficulty, p_diagnosis_name);
  v_title := coalesce(nullif(trim(p_case_name), ''), nullif(trim(p_diagnosis_name), ''), 'PratiCase Vakası');
  v_branch := coalesce(nullif(trim(p_course), ''), praticase.payload_text(p_payload, 'course'), 'Genel');
  v_difficulty := case
    when trim(coalesce(p_difficulty, '')) in ('Kolay', 'Orta', 'Zor') then trim(p_difficulty)
    else 'Orta'
  end;
  v_setting := coalesce(nullif(praticase.payload_text(p_payload, 'caseAssumptions', 'defaultSetting'), ''), 'OSCE');
  v_prompt := 'Bu istasyonda ' || v_title || ' olgusunu OSCE yaklaşımıyla değerlendiriniz.';

  insert into praticase.cases(
    slug,
    title,
    branch,
    difficulty,
    duration_minutes,
    setting,
    candidate_prompt,
    patient_profile,
    rubric,
    points,
    icon_key,
    is_published,
    summary,
    flow_steps,
    goals
  )
  values (
    v_slug,
    v_title,
    v_branch,
    v_difficulty,
    7,
    v_setting,
    v_prompt,
    praticase.generated_case_profile(v_title, p_diagnosis_name, p_payload),
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    100,
    'stethoscope',
    false,
    coalesce(nullif(praticase.payload_text(p_payload, 'caseAssumptions', 'mainComplaint'), ''), p_diagnosis_name, ''),
    '[{"title":"Anamnez","iconKey":"chat"},{"title":"Muayene","iconKey":"stethoscope"},{"title":"Tetkik","iconKey":"test-tube"},{"title":"Tanı","iconKey":"target"},{"title":"Karne","iconKey":"award"}]'::jsonb,
    '[{"title":"Klinik performans","points":100}]'::jsonb
  )
  on conflict (slug) do update set
    title = excluded.title,
    branch = excluded.branch,
    difficulty = excluded.difficulty,
    setting = excluded.setting,
    candidate_prompt = excluded.candidate_prompt,
    patient_profile = excluded.patient_profile,
    rubric = excluded.rubric,
    points = excluded.points,
    is_published = false,
    summary = excluded.summary,
    flow_steps = excluded.flow_steps,
    goals = excluded.goals,
    updated_at = now()
  returning id into v_case_id;

  return v_case_id;
end;
$$;

create or replace function praticase.refresh_generated_case_publication(p_case_id uuid)
returns void
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_complete boolean;
begin
  select
    exists (select 1 from praticase.praticase_history_checklists where case_id = p_case_id) and
    exists (select 1 from praticase.praticase_physical_exam_checklists where case_id = p_case_id) and
    exists (select 1 from praticase.praticase_laboratory_checklists where case_id = p_case_id) and
    exists (select 1 from praticase.praticase_imaging_checklists where case_id = p_case_id) and
    exists (select 1 from praticase.praticase_diagnostic_checklists where case_id = p_case_id)
  into v_complete;

  update praticase.cases
  set is_published = v_complete,
      updated_at = now()
  where id = p_case_id
    and slug like 'admin-%';
end;
$$;

create or replace function praticase.refresh_generated_case_publication_trigger()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
begin
  if TG_OP = 'DELETE' then
    perform praticase.refresh_generated_case_publication(old.case_id);
  else
    perform praticase.refresh_generated_case_publication(new.case_id);
  end if;
  return null;
end;
$$;

create or replace function praticase.sync_generated_history()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_items jsonb;
  v_item jsonb;
  v_rule_id uuid;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(new.course, new.case_name, new.difficulty, new.diagnosis_name, new.payload);

  delete from praticase.case_patient_response_rules where case_id = new.case_id;

  v_items := coalesce(new.payload->'historyItems', '[]'::jsonb)
    || coalesce(new.payload->'redFlags', '[]'::jsonb)
    || coalesce(new.payload->'negativeFindings', '[]'::jsonb);

  for v_item in select * from jsonb_array_elements(v_items) loop
    if coalesce(v_item->>'patientAnswer', '') <> '' then
      insert into praticase.case_patient_response_rules(case_id, match_terms, response, sort_order)
      values (
        new.case_id,
        praticase.payload_text_array(v_item->'expectedQuestionExamples'),
        v_item->>'patientAnswer',
        praticase.safe_json_int(v_item->>'sortOrder')
      )
      returning id into v_rule_id;
    end if;
  end loop;

  return new;
end;
$$;

create or replace function praticase.sync_generated_physical()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_items jsonb;
  v_item jsonb;
  v_group_id uuid;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(new.course, new.case_name, new.difficulty, new.diagnosis_name, new.payload);

  delete from praticase.physical_exam_groups where case_id = new.case_id;

  v_items := coalesce(new.payload->'physicalExamItems', '[]'::jsonb)
    || coalesce(new.payload->'criticalFindings', '[]'::jsonb)
    || coalesce(new.payload->'negativeFindings', '[]'::jsonb);

  for v_item in select * from jsonb_array_elements(v_items) loop
    insert into praticase.physical_exam_groups(case_id, title, sort_order)
    values (
      new.case_id,
      coalesce(nullif(v_item->>'category', ''), 'Fizik Muayene'),
      praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_group_id;

    insert into praticase.physical_exam_options(group_id, title, finding, point_value, is_critical, sort_order)
    values (
      v_group_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'examAction', ''), 'Muayene'),
      coalesce(v_item->>'finding', ''),
      praticase.safe_json_int(v_item->>'scorePoints'),
      praticase.safe_json_bool(v_item->>'isCritical'),
      praticase.safe_json_int(v_item->>'sortOrder')
    );
  end loop;

  return new;
end;
$$;

create or replace function praticase.sync_generated_laboratory()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_items jsonb;
  v_item jsonb;
  v_group_id uuid;
  v_option_id uuid;
  v_unnecessary boolean;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(new.course, new.case_name, new.difficulty, new.diagnosis_name, new.payload);

  delete from praticase.test_groups where case_id = new.case_id and title in ('Laboratuvar', 'Yatak Başı Test', 'Mikrobiyoloji/Patoloji', 'Gereksiz Tetkikler');

  v_items := coalesce(new.payload->'laboratoryItems', '[]'::jsonb)
    || coalesce(new.payload->'bedsideTests', '[]'::jsonb)
    || coalesce(new.payload->'microbiologyPathologyTests', '[]'::jsonb)
    || coalesce(new.payload->'unnecessaryOrHarmfulTests', '[]'::jsonb);

  for v_item in select * from jsonb_array_elements(v_items) loop
    v_unnecessary := coalesce((v_item->>'relevance') = 'unnecessary', false)
      or praticase.safe_json_int(v_item->>'penaltyPoints') > 0
      or coalesce(v_item->>'category', '') = 'unnecessary_or_harmful';

    insert into praticase.test_groups(case_id, title, sort_order)
    values (
      new.case_id,
      case when v_unnecessary then 'Gereksiz Tetkikler' else 'Laboratuvar' end,
      praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_group_id;

    insert into praticase.test_options(group_id, title, result, point_cost, is_unnecessary, sort_order)
    values (
      v_group_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'testName', ''), 'Tetkik'),
      coalesce(v_item->>'resultText', v_item->>'whyUnnecessary', ''),
      greatest(0, praticase.safe_json_int(v_item->>'penaltyPoints')),
      v_unnecessary,
      praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_option_id;

    insert into praticase.lab_result_details(test_option_id, title, parameters, interpretation)
    values (
      v_option_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'testName', ''), 'Tetkik'),
      case when jsonb_typeof(v_item->'resultJson') = 'object' then jsonb_build_array(v_item->'resultJson') else '[]'::jsonb end,
      coalesce(v_item->>'interpretation', v_item->>'whyUnnecessary', '')
    );
  end loop;

  return new;
end;
$$;

create or replace function praticase.sync_generated_imaging()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_items jsonb;
  v_item jsonb;
  v_group_id uuid;
  v_option_id uuid;
  v_unnecessary boolean;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(new.course, new.case_name, new.difficulty, new.diagnosis_name, new.payload);

  delete from praticase.test_groups where case_id = new.case_id and title in ('Görüntüleme', 'Gereksiz Görüntüleme');

  v_items := coalesce(new.payload->'imagingItems', '[]'::jsonb)
    || coalesce(new.payload->'negativeOrNormalImagingFindings', '[]'::jsonb)
    || coalesce(new.payload->'redFlagImaging', '[]'::jsonb)
    || coalesce(new.payload->'unnecessaryImaging', '[]'::jsonb);

  for v_item in select * from jsonb_array_elements(v_items) loop
    v_unnecessary := praticase.safe_json_int(v_item->>'penaltyPoints') > 0
      or coalesce(v_item->>'category', '') = 'unnecessary_imaging';

    insert into praticase.test_groups(case_id, title, sort_order)
    values (
      new.case_id,
      case when v_unnecessary then 'Gereksiz Görüntüleme' else 'Görüntüleme' end,
      praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_group_id;

    insert into praticase.test_options(group_id, title, result, point_cost, is_unnecessary, sort_order)
    values (
      v_group_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'imagingName', ''), 'Görüntüleme'),
      coalesce(v_item->>'expectedResult', v_item->>'whyUnnecessary', ''),
      greatest(0, praticase.safe_json_int(v_item->>'penaltyPoints')),
      v_unnecessary,
      praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_option_id;

    insert into praticase.imaging_result_details(test_option_id, title, report, conclusion)
    values (
      v_option_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'imagingName', ''), 'Görüntüleme'),
      coalesce(v_item->>'expectedResult', ''),
      coalesce(v_item->>'clinicalReason', v_item->>'whyUnnecessary', '')
    );
  end loop;

  return new;
end;
$$;

create or replace function praticase.sync_generated_diagnostic()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_items jsonb;
  v_item jsonb;
  v_primary jsonb;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(new.course, new.case_name, new.difficulty, new.diagnosis_name, new.payload);

  delete from praticase.diagnosis_options where case_id = new.case_id;

  v_primary := new.payload->'primaryDiagnosis';
  if jsonb_typeof(v_primary) = 'object' then
    insert into praticase.diagnosis_options(case_id, title, is_primary, is_correct, sort_order)
    values (
      new.case_id,
      coalesce(nullif(v_primary->>'label', ''), nullif(v_primary->>'diagnosisName', ''), new.diagnosis_name),
      true,
      true,
      praticase.safe_json_int(v_primary->>'sortOrder', 1)
    );
  end if;

  v_items := coalesce(new.payload->'differentialDiagnoses', '[]'::jsonb)
    || coalesce(new.payload->'mustNotMissDiagnoses', '[]'::jsonb)
    || coalesce(new.payload->'exclusionDiagnoses', '[]'::jsonb);

  for v_item in select * from jsonb_array_elements(v_items) loop
    insert into praticase.diagnosis_options(case_id, title, is_primary, is_correct, sort_order)
    values (
      new.case_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'diagnosisName', ''), 'Ön tanı'),
      false,
      not praticase.safe_json_int(v_item->>'penaltyPoints') > 0,
      praticase.safe_json_int(v_item->>'sortOrder')
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists sync_generated_history on praticase.praticase_history_checklists;
create trigger sync_generated_history
before insert or update on praticase.praticase_history_checklists
for each row execute function praticase.sync_generated_history();

drop trigger if exists refresh_generated_history_publication on praticase.praticase_history_checklists;
create trigger refresh_generated_history_publication
after insert or update or delete on praticase.praticase_history_checklists
for each row execute function praticase.refresh_generated_case_publication_trigger();

drop trigger if exists sync_generated_physical on praticase.praticase_physical_exam_checklists;
create trigger sync_generated_physical
before insert or update on praticase.praticase_physical_exam_checklists
for each row execute function praticase.sync_generated_physical();

drop trigger if exists refresh_generated_physical_publication on praticase.praticase_physical_exam_checklists;
create trigger refresh_generated_physical_publication
after insert or update or delete on praticase.praticase_physical_exam_checklists
for each row execute function praticase.refresh_generated_case_publication_trigger();

drop trigger if exists sync_generated_laboratory on praticase.praticase_laboratory_checklists;
create trigger sync_generated_laboratory
before insert or update on praticase.praticase_laboratory_checklists
for each row execute function praticase.sync_generated_laboratory();

drop trigger if exists refresh_generated_laboratory_publication on praticase.praticase_laboratory_checklists;
create trigger refresh_generated_laboratory_publication
after insert or update or delete on praticase.praticase_laboratory_checklists
for each row execute function praticase.refresh_generated_case_publication_trigger();

drop trigger if exists sync_generated_imaging on praticase.praticase_imaging_checklists;
create trigger sync_generated_imaging
before insert or update on praticase.praticase_imaging_checklists
for each row execute function praticase.sync_generated_imaging();

drop trigger if exists refresh_generated_imaging_publication on praticase.praticase_imaging_checklists;
create trigger refresh_generated_imaging_publication
after insert or update or delete on praticase.praticase_imaging_checklists
for each row execute function praticase.refresh_generated_case_publication_trigger();

drop trigger if exists sync_generated_diagnostic on praticase.praticase_diagnostic_checklists;
create trigger sync_generated_diagnostic
before insert or update on praticase.praticase_diagnostic_checklists
for each row execute function praticase.sync_generated_diagnostic();

drop trigger if exists refresh_generated_diagnostic_publication on praticase.praticase_diagnostic_checklists;
create trigger refresh_generated_diagnostic_publication
after insert or update or delete on praticase.praticase_diagnostic_checklists
for each row execute function praticase.refresh_generated_case_publication_trigger();

create index if not exists praticase_history_generated_group_idx
  on praticase.praticase_history_checklists (course, difficulty, diagnosis_name, case_name, generated_at desc);
create index if not exists praticase_physical_generated_group_idx
  on praticase.praticase_physical_exam_checklists (course, difficulty, diagnosis_name, case_name, generated_at desc);
create index if not exists praticase_laboratory_generated_group_idx
  on praticase.praticase_laboratory_checklists (course, difficulty, diagnosis_name, case_name, generated_at desc);
create index if not exists praticase_imaging_generated_group_idx
  on praticase.praticase_imaging_checklists (course, difficulty, diagnosis_name, case_name, generated_at desc);
create index if not exists praticase_diagnostic_generated_group_idx
  on praticase.praticase_diagnostic_checklists (course, difficulty, diagnosis_name, case_name, generated_at desc);

grant select on
  praticase.praticase_history_checklists,
  praticase.praticase_physical_exam_checklists,
  praticase.praticase_laboratory_checklists,
  praticase.praticase_imaging_checklists,
  praticase.praticase_diagnostic_checklists
to anon, authenticated, service_role;

grant insert, update, delete on
  praticase.praticase_history_checklists,
  praticase.praticase_physical_exam_checklists,
  praticase.praticase_laboratory_checklists,
  praticase.praticase_imaging_checklists,
  praticase.praticase_diagnostic_checklists
to authenticated, service_role;

commit;
