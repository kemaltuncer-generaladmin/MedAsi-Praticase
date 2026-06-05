-- Keep generated OSCE test catalog groups clinically useful for the mobile app.
-- Generated "unnecessary" items remain hidden scoring flags instead of visible
-- exam hints such as "Gereksiz Tetkikler".

create or replace function praticase.generated_jsonb_array(p_value jsonb)
returns jsonb
language sql
immutable
as $$
  select case
    when jsonb_typeof(p_value) = 'array' then p_value
    else '[]'::jsonb
  end;
$$;

create or replace function praticase.generated_test_group_sort_order(p_title text)
returns integer
language sql
immutable
as $$
  select case p_title
    when 'Temel Laboratuvar' then 10
    when 'Biyokimya ve Endokrin' then 20
    when 'İdrar ve Hızlı Testler' then 30
    when 'Mikrobiyoloji / Patoloji' then 40
    when 'Direkt Grafi' then 50
    when 'Ultrasonografi' then 60
    when 'Tomografi ve MR' then 70
    when 'EKG ve Yatak Başı Test' then 80
    when 'Özel Tetkikler / Konsültasyon' then 90
    else 900
  end;
$$;

create or replace function praticase.generated_laboratory_group_title(
  p_item jsonb,
  p_bucket text
)
returns text
language plpgsql
immutable
as $$
declare
  v_text text := concat_ws(
    ' ',
    p_item->>'label',
    p_item->>'testName',
    p_item->>'category',
    p_item->>'subcategory',
    p_item->>'key'
  );
begin
  if v_text ilike '%kültür%' or v_text ilike '%kultur%'
      or v_text ilike '%mikrobiyoloji%' or v_text ilike '%patoloji%'
      or v_text ilike '%klamid%' or v_text ilike '%gonore%'
      or v_text ilike '%servikal%' or p_bucket = 'microbiology' then
    return 'Mikrobiyoloji / Patoloji';
  end if;

  if v_text ilike '%idrar%' or v_text ilike '%ürin%' or v_text ilike '%urin%'
      or v_text ilike '%nitrit%' or v_text ilike '%gebelik test%' then
    return 'İdrar ve Hızlı Testler';
  end if;

  if v_text ilike '%ekg%' or v_text ilike '%elektrokardiyografi%'
      or v_text ilike '%kan gaz%' or v_text ilike '%parmak ucu%'
      or v_text ilike '%poc%' or v_text ilike '%hızlı%' or p_bucket = 'bedside' then
    return 'EKG ve Yatak Başı Test';
  end if;

  if v_text ilike '%hemogram%' or v_text ilike '%tam kan%'
      or v_text ilike '%cbc%' or v_text ilike '%crp%'
      or v_text ilike '%sedim%' or v_text ilike '%pt%'
      or v_text ilike '%inr%' or v_text ilike '%aptt%'
      or v_text ilike '%kan grubu%' or v_text ilike '% rh%' then
    return 'Temel Laboratuvar';
  end if;

  if v_text ilike '%hcg%' or v_text ilike '%β-hcg%'
      or v_text ilike '%beta%' or v_text ilike '%progesteron%'
      or v_text ilike '%fsh%' or v_text ilike '%lh%'
      or v_text ilike '%prolaktin%' or v_text ilike '%tsh%'
      or v_text ilike '%ca-125%' or v_text ilike '%ca 125%'
      or v_text ilike '%amilaz%' or v_text ilike '%lipaz%'
      or v_text ilike '%kreatinin%' or v_text ilike '%bun%'
      or v_text ilike '%üre%' or v_text ilike '%ure%'
      or v_text ilike '%alt%' or v_text ilike '%ast%'
      or v_text ilike '%sodyum%' or v_text ilike '%potasyum%'
      or v_text ilike '%elektrolit%' or v_text ilike '%glukoz%' then
    return 'Biyokimya ve Endokrin';
  end if;

  return 'Temel Laboratuvar';
end;
$$;

create or replace function praticase.generated_imaging_group_title(p_item jsonb)
returns text
language plpgsql
immutable
as $$
declare
  v_text text := concat_ws(
    ' ',
    p_item->>'label',
    p_item->>'imagingName',
    p_item->>'category',
    p_item->>'subcategory',
    p_item->>'key'
  );
begin
  if v_text ilike '%ultrason%' or v_text ilike '%usg%'
      or v_text ilike '%tvusg%' or v_text ilike '%tausg%'
      or v_text ilike '%doppler%' then
    return 'Ultrasonografi';
  end if;

  if v_text ~* '(^|[^[:alnum:]])bt([^[:alnum:]]|$)'
      or v_text ilike '%tomografi%'
      or v_text ~* '(^|[^[:alnum:]])mr([^[:alnum:]]|$)'
      or v_text ilike '%mrg%'
      or v_text ilike '%manyetik rezonans%' then
    return 'Tomografi ve MR';
  end if;

  if v_text ilike '%grafi%' or v_text ilike '%röntgen%'
      or v_text ilike '%rontgen%' or v_text ilike '%x-ray%' then
    return 'Direkt Grafi';
  end if;

  return 'Özel Tetkikler / Konsültasyon';
end;
$$;

create or replace function praticase.sync_generated_laboratory()
returns trigger
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_item jsonb;
  v_group_id uuid;
  v_option_id uuid;
  v_group_title text;
  v_group_order integer;
  v_unnecessary boolean;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(
    new.course,
    new.case_name,
    new.difficulty,
    new.diagnosis_name,
    new.payload
  );

  delete from praticase.test_groups
  where case_id = new.case_id
    and title in (
      'Laboratuvar',
      'Yatak Başı Test',
      'Mikrobiyoloji/Patoloji',
      'Mikrobiyoloji / Patoloji',
      'Gereksiz Tetkikler',
      'Temel Laboratuvar',
      'Biyokimya ve Endokrin',
      'İdrar ve Hızlı Testler',
      'EKG ve Yatak Başı Test',
      'Diğer'
    );

  for v_item in
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'laboratoryItems')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'bedsideTests')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'microbiologyPathologyTests')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'unnecessaryOrHarmfulTests')
    ) as item
  loop
    v_unnecessary := coalesce((v_item->>'relevance') = 'unnecessary', false)
      or praticase.safe_json_int(v_item->>'penaltyPoints') > 0
      or coalesce(v_item->>'category', '') in (
        'unnecessary_or_harmful',
        'unnecessary',
        'harmful'
      );
    v_group_title := praticase.generated_laboratory_group_title(
      v_item,
      coalesce(v_item->>'category', '')
    );
    v_group_order := praticase.generated_test_group_sort_order(v_group_title);

    select id into v_group_id
    from praticase.test_groups
    where case_id = new.case_id
      and praticase.normalize_label(title) = praticase.normalize_label(v_group_title)
    order by sort_order, id
    limit 1;

    if v_group_id is null then
      insert into praticase.test_groups(case_id, title, sort_order)
      values (new.case_id, v_group_title, v_group_order)
      returning id into v_group_id;
    end if;

    insert into praticase.test_options(
      group_id,
      title,
      result,
      point_cost,
      is_unnecessary,
      sort_order
    )
    values (
      v_group_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'testName', ''), 'Tetkik'),
      coalesce(v_item->>'resultText', v_item->>'whyUnnecessary', ''),
      greatest(0, praticase.safe_json_int(v_item->>'penaltyPoints')),
      v_unnecessary,
      v_group_order + praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_option_id;

    insert into praticase.lab_result_details(
      test_option_id,
      title,
      parameters,
      interpretation
    )
    values (
      v_option_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'testName', ''), 'Tetkik'),
      case
        when jsonb_typeof(v_item->'resultJson') = 'array' then v_item->'resultJson'
        when jsonb_typeof(v_item->'resultJson') = 'object' then jsonb_build_array(v_item->'resultJson')
        else '[]'::jsonb
      end,
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
  v_item jsonb;
  v_group_id uuid;
  v_option_id uuid;
  v_group_title text;
  v_group_order integer;
  v_unnecessary boolean;
begin
  new.updated_at := now();
  new.case_id := praticase.upsert_generated_case_shell(
    new.course,
    new.case_name,
    new.difficulty,
    new.diagnosis_name,
    new.payload
  );

  delete from praticase.test_groups
  where case_id = new.case_id
    and title in (
      'Görüntüleme',
      'Gereksiz Görüntüleme',
      'Direkt Grafi',
      'Ultrasonografi',
      'Tomografi ve MR',
      'Özel Tetkikler / Konsültasyon'
    );

  for v_item in
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'imagingItems')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'negativeOrNormalImagingFindings')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'redFlagImaging')
    ) as item
    union all
    select item from jsonb_array_elements(
      praticase.generated_jsonb_array(new.payload->'unnecessaryImaging')
    ) as item
  loop
    v_unnecessary := praticase.safe_json_int(v_item->>'penaltyPoints') > 0
      or coalesce(v_item->>'category', '') in (
        'unnecessary_imaging',
        'unnecessary',
        'harmful'
      );
    v_group_title := praticase.generated_imaging_group_title(v_item);
    v_group_order := praticase.generated_test_group_sort_order(v_group_title);

    select id into v_group_id
    from praticase.test_groups
    where case_id = new.case_id
      and praticase.normalize_label(title) = praticase.normalize_label(v_group_title)
    order by sort_order, id
    limit 1;

    if v_group_id is null then
      insert into praticase.test_groups(case_id, title, sort_order)
      values (new.case_id, v_group_title, v_group_order)
      returning id into v_group_id;
    end if;

    insert into praticase.test_options(
      group_id,
      title,
      result,
      point_cost,
      is_unnecessary,
      sort_order
    )
    values (
      v_group_id,
      coalesce(nullif(v_item->>'label', ''), nullif(v_item->>'imagingName', ''), 'Görüntüleme'),
      coalesce(v_item->>'expectedResult', v_item->>'whyUnnecessary', ''),
      greatest(0, praticase.safe_json_int(v_item->>'penaltyPoints')),
      v_unnecessary,
      v_group_order + praticase.safe_json_int(v_item->>'sortOrder')
    )
    returning id into v_option_id;

    insert into praticase.imaging_result_details(
      test_option_id,
      title,
      report,
      conclusion
    )
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

-- Repair the Amenore cases generated from adminpanelv2 by replaying their
-- latest generated payloads through the corrected triggers.
do $$
declare
  v_case_ids uuid[];
begin
  select array_agg(id) into v_case_ids
  from praticase.cases
  where title ilike '%Amenore%'
    or slug ilike '%amenore%';

  if v_case_ids is not null then
    update praticase.praticase_laboratory_checklists
    set payload = payload
    where case_id = any(v_case_ids);

    update praticase.praticase_imaging_checklists
    set payload = payload
    where case_id = any(v_case_ids);
  end if;
end $$;

insert into praticase.self_hosted_schema_migrations(version, filename)
values (
  '202606050001_praticase_generated_test_group_normalization',
  '202606050001_praticase_generated_test_group_normalization.sql'
)
on conflict (version) do nothing;
