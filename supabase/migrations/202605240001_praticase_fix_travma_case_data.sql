-- Fix Travma case (admin-707a6260d78bea8b) data quality issues:
-- 1. Translate English physical exam group titles to Turkish
-- 2. Merge duplicate critical_findings into one Kritik Bulgular group
-- 3. Consolidate duplicate test groups
-- 4. Add management plan options

begin;

do $$
declare
  v_case_id uuid := '5959b3c7-069c-47bf-892a-ca89a153c2a1';
  v_keep_id uuid;
  v_group_title text;
begin

  -- ----------------------------------------------------------------
  -- 1. PHYSICAL EXAM GROUPS: translate English names to Turkish
  -- ----------------------------------------------------------------
  update praticase.physical_exam_groups set title = 'Karın'              where case_id = v_case_id and title = 'Abdomen';
  update praticase.physical_exam_groups set title = 'Göğüs'              where case_id = v_case_id and title = 'Chest';
  update praticase.physical_exam_groups set title = 'Kas-İskelet Sistemi' where case_id = v_case_id and title = 'Musculoskeletal';
  update praticase.physical_exam_groups set title = 'Nörolojik'          where case_id = v_case_id and title = 'Neurological';
  update praticase.physical_exam_groups set title = 'Kritik Bulgular'    where case_id = v_case_id and title = 'critical_findings';

  -- Merge second Kritik Bulgular duplicate into the first
  select id into v_keep_id
  from praticase.physical_exam_groups
  where case_id = v_case_id and title = 'Kritik Bulgular'
  order by id asc limit 1;

  update praticase.physical_exam_options
  set group_id = v_keep_id
  where group_id in (
    select id from praticase.physical_exam_groups
    where case_id = v_case_id and title = 'Kritik Bulgular' and id <> v_keep_id
  );

  delete from praticase.physical_exam_groups
  where case_id = v_case_id and title = 'Kritik Bulgular' and id <> v_keep_id;

  update praticase.physical_exam_groups set sort_order = 90 where id = v_keep_id;

  -- ----------------------------------------------------------------
  -- 2. TEST GROUPS: consolidate duplicates per title (iterative)
  -- ----------------------------------------------------------------
  foreach v_group_title in array array['Laboratuvar','Görüntüleme','Gereksiz Tetkikler','Gereksiz Görüntüleme']
  loop
    -- Keep the first (lowest id) group for this title
    select id into v_keep_id
    from praticase.test_groups
    where case_id = v_case_id and title = v_group_title
    order by id asc limit 1;

    continue when v_keep_id is null;

    -- Re-parent all test_options from duplicate groups to canonical group
    update praticase.test_options
    set group_id = v_keep_id
    where group_id in (
      select id from praticase.test_groups
      where case_id = v_case_id and title = v_group_title and id <> v_keep_id
    );

    -- Remove duplicates
    delete from praticase.test_groups
    where case_id = v_case_id and title = v_group_title and id <> v_keep_id;
  end loop;

  -- Fix sort_order for test groups
  update praticase.test_groups set sort_order = 10 where case_id = v_case_id and title = 'Laboratuvar';
  update praticase.test_groups set sort_order = 20 where case_id = v_case_id and title = 'Görüntüleme';
  update praticase.test_groups set sort_order = 30 where case_id = v_case_id and title = 'Gereksiz Tetkikler';
  update praticase.test_groups set sort_order = 40 where case_id = v_case_id and title = 'Gereksiz Görüntüleme';

  -- ----------------------------------------------------------------
  -- 3. MANAGEMENT PLAN OPTIONS: add Travma-appropriate options
  -- ----------------------------------------------------------------
  delete from praticase.management_plan_options where case_id = v_case_id;

  insert into praticase.management_plan_options(case_id, category, title, point_value, is_recommended, sort_order)
  values
    (v_case_id, 'Hava Yolu ve Solunum', 'Hava yolu değerlendirmesi (ABCDE)',       3, true,  10),
    (v_case_id, 'Hava Yolu ve Solunum', 'Oksijen desteği',                          3, true,  20),
    (v_case_id, 'Hava Yolu ve Solunum', 'Pulse oksimetre takibi',                   2, true,  30),
    (v_case_id, 'Dolaşım ve Sıvı',      'İV damar yolu (2 geniş çaplı)',            3, true,  40),
    (v_case_id, 'Dolaşım ve Sıvı',      'İzotonik IV sıvı tedavisi',                3, true,  50),
    (v_case_id, 'Dolaşım ve Sıvı',      'Vital bulgu monitörizasyonu',              3, true,  60),
    (v_case_id, 'Dolaşım ve Sıvı',      'Kan grubu ve crossmatch',                  2, true,  70),
    (v_case_id, 'Ağrı Kontrolü',         'Analjezi (IV morfin veya parasetamol)',   2, true,  80),
    (v_case_id, 'Ağrı Kontrolü',         'Antiemetik',                              1, false, 90),
    (v_case_id, 'Konsültasyon ve Sevk',  'Genel cerrahi konsültasyonu',             3, true,  100),
    (v_case_id, 'Konsültasyon ve Sevk',  'Ortopedi konsültasyonu (kırık şüphesi)',  2, true,  110),
    (v_case_id, 'Konsültasyon ve Sevk',  'Hastaneye yatış / gözlem',                2, true,  120),
    (v_case_id, 'Gereksiz / Zararlı',    'NSAİİ yüksek doz (GIS kanama riski)',    -1, false, 130),
    (v_case_id, 'Gereksiz / Zararlı',    'Servikal stabilizasyonu atlama',          -2, false, 140);

end $$;

-- Register in schema migrations tracker
insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240001', '202605240001_praticase_fix_travma_case_data.sql')
on conflict (version) do nothing;

commit;
