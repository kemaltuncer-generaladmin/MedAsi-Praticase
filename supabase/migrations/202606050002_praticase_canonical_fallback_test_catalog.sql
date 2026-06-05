-- The published-case fallback catalog must use the same canonical group names
-- as case_test_groups_v. Generic groups such as "Laboratuvar", "Görüntüleme"
-- and "Diğer" create duplicate, non-systematic sections in the mobile app.

create or replace function praticase.ensure_case_clinical_catalog(p_case_id uuid)
returns void
language plpgsql
security definer
set search_path = praticase, public, extensions
as $$
declare
  v_item record;
  v_group_id uuid;
begin
  update praticase.physical_exam_groups
  set title = case
    when lower(title) in ('neurological', 'neurologic', 'nörolojik muayene') then 'Nörolojik'
    when lower(title) in ('head_neck', 'baş boyun', 'baş-boyun muayenesi') then 'Baş-Boyun'
    when lower(title) in ('thorax', 'respiratory', 'toraks muayenesi') then 'Toraks / Solunum'
    when lower(title) in ('cardiovascular', 'kvs muayenesi') then 'Kardiyovasküler'
    when lower(title) in ('abdomen', 'batın muayenesi') then 'Batın'
    when lower(title) in ('extremity', 'ekstremite muayenesi') then 'Ekstremite / Kas-İskelet'
    when lower(title) in ('vitals', 'general', 'genel görünüm') then 'Genel Değerlendirme / Vital Bulgular'
    else title end
  where case_id = p_case_id;

  for v_item in
    select * from (values
      ('Genel Değerlendirme / Vital Bulgular', 'Genel değerlendirme ve vital bulgular', 'Hasta genel olarak stabil görünümde, vital bulgular normal sınırlarda.', 10),
      ('Baş-Boyun', 'Baş-boyun muayenesi', 'Baş-boyun muayenesinde patolojik bulgu saptanmadı.', 20),
      ('Toraks / Solunum', 'Toraks ve solunum muayenesi', 'Solunum sesleri doğal, ek solunum bulgusu yok.', 30),
      ('Kardiyovasküler', 'Kardiyovasküler muayene', 'Kalp sesleri doğal, periferik dolaşım bulguları normal.', 40),
      ('Batın', 'Batın muayenesi', 'Batın muayenesinde ek patolojik bulgu saptanmadı.', 50),
      ('Nörolojik', 'Nörolojik muayene', 'Nörolojik muayenede belirgin patolojik bulgu saptanmadı.', 60),
      ('Ekstremite / Kas-İskelet', 'Ekstremite muayenesi', 'Ekstremite ve kas-iskelet değerlendirmesi doğal.', 70)
    ) as defaults(title, option_title, finding, sort_order)
  loop
    select id into v_group_id
    from praticase.physical_exam_groups
    where case_id = p_case_id
      and praticase.normalize_label(title) = praticase.normalize_label(v_item.title)
    order by sort_order, id
    limit 1;

    if v_group_id is null then
      insert into praticase.physical_exam_groups(case_id, title, sort_order)
      values (p_case_id, v_item.title, v_item.sort_order)
      returning id into v_group_id;
    end if;

    if not exists (
      select 1 from praticase.physical_exam_options
      where group_id = v_group_id
        and praticase.normalize_label(title) = praticase.normalize_label(v_item.option_title)
    ) then
      insert into praticase.physical_exam_options(
        group_id,
        title,
        finding,
        point_value,
        is_critical,
        sort_order
      )
      values (v_group_id, v_item.option_title, v_item.finding, 0, false, 999);
    end if;

    v_group_id := null;
  end loop;

  for v_item in
    select * from (values
      ('Temel Laboratuvar', 'Hemogram', 'Referans aralığı dışında anlamlı değer saptanmadı.', 10),
      ('Temel Laboratuvar', 'CRP', 'Normal sınırlarda.', 20),
      ('İdrar ve Hızlı Testler', 'Tam İdrar Tahlili', 'Patolojik bulgu saptanmadı.', 30),
      ('Ultrasonografi', 'Ultrasonografi', 'Patolojik görüntüleme bulgusu saptanmadı.', 10),
      ('Tomografi ve MR', 'Bilgisayarlı Tomografi', 'Akut patolojik bulgu saptanmadı.', 20),
      ('EKG ve Yatak Başı Test', 'Elektrokardiyografi', 'Sinüs ritmi, akut patolojik değişiklik yok.', 10)
    ) as defaults(group_title, option_title, result_text, sort_order)
  loop
    select id into v_group_id
    from praticase.test_groups
    where case_id = p_case_id
      and praticase.normalize_label(title) = praticase.normalize_label(v_item.group_title)
    order by sort_order, id
    limit 1;

    if v_group_id is null then
      insert into praticase.test_groups(case_id, title, sort_order)
      values (
        p_case_id,
        v_item.group_title,
        praticase.generated_test_group_sort_order(v_item.group_title)
      )
      returning id into v_group_id;
    end if;

    if not exists (
      select 1 from praticase.test_options
      where group_id = v_group_id
        and praticase.normalize_label(title) = praticase.normalize_label(v_item.option_title)
    ) then
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
        v_item.option_title,
        v_item.result_text,
        0,
        false,
        praticase.generated_test_group_sort_order(v_item.group_title) + v_item.sort_order
      );
    end if;

    v_group_id := null;
  end loop;
end;
$$;

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
  '202606050002_praticase_canonical_fallback_test_catalog',
  '202606050002_praticase_canonical_fallback_test_catalog.sql'
)
on conflict (version) do nothing;
