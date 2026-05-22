begin;

insert into praticase.home_banners(
  title,
  subtitle,
  cta_label,
  cta_route,
  sort_order,
  is_active
)
values
  (
    'Pratik yap, gelişimini takip et, hedeflerine ulaş!',
    'Vaka çöz, puan kazan, rozetlerini topla ve sıralamada yerini al.',
    'Vaka Çözmeye Başla',
    '/cases',
    10,
    true
  )
on conflict do nothing;

insert into praticase.cases(
  slug,
  title,
  branch,
  difficulty,
  duration_minutes,
  setting,
  candidate_prompt,
  patient_profile,
  expected_history,
  expected_physical_exam,
  expected_differentials,
  expected_tests,
  unnecessary_tests,
  management_steps,
  critical_mistakes,
  rubric,
  points,
  icon_key,
  is_published,
  summary,
  flow_steps,
  goals
)
values
  (
    'acute-appendicitis-001',
    'Akut Batın Vakası',
    'Genel Cerrahi',
    'Orta',
    7,
    'Acil Servis',
    'Ani başlayan karın ağrısı ile başvuran hastayı değerlendiriniz.',
    '{
      "name": "Mehmet Yılmaz",
      "age": "45",
      "gender": "Erkek",
      "mainComplaint": "Karın ağrısı",
      "openingLine": "Doktor bey, karnım çok ağrıyor.",
      "applicationSetting": "Acil Servis",
      "complaintDuration": "6 saat"
    }'::jsonb,
    '["Ağrının başlangıcı", "Ağrının yeri ve yayılımı", "Bulantı-kusma", "Ateş", "İştah kaybı", "Geçirilmiş ameliyat"]'::jsonb,
    '["Vital bulgular", "Batın inspeksiyonu", "Sağ alt kadran hassasiyeti", "Defans", "Rebound", "Rovsing"]'::jsonb,
    '["Akut apandisit", "Meckel divertiküliti", "Gastroenterit", "Üriner kolik"]'::jsonb,
    '["Tam kan sayımı", "CRP", "Tam idrar tahlili", "Batın USG"]'::jsonb,
    '["Rutin tümör belirteçleri", "Endikasyonsuz tüm batın MR"]'::jsonb,
    '["Ağızdan alımı kes", "IV sıvı başla", "Analjezi ver", "Genel cerrahi konsültasyonu iste", "Apendektomi planını değerlendir"]'::jsonb,
    '["Peritonit bulgularını atlamak", "Gebelik olasılığını uygun hastada değerlendirmemek", "Cerrahi konsültasyonu geciktirmek"]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    120,
    'lungs',
    true,
    'Ani başlayan karın ağrısı ile başvuran bir hastada akut batın yaklaşımı.',
    '[
      {"title":"Anamnez","iconKey":"chat"},
      {"title":"Muayene","iconKey":"stethoscope"},
      {"title":"Tetkikler","iconKey":"tube"},
      {"title":"Tanı","iconKey":"brain"},
      {"title":"Yönetim","iconKey":"clipboard"}
    ]'::jsonb,
    '[
      {"title":"Doğru tanıya ulaş","points":80},
      {"title":"Uygun tetkik iste","points":60},
      {"title":"Doğru yönetim planı yap","points":60}
    ]'::jsonb
  ),
  (
    'stemi-management-001',
    'STEMI Yönetimi',
    'Kardiyoloji',
    'Zor',
    8,
    'Acil',
    'Göğüs ağrısı ile başvuran hastayı değerlendiriniz ve ilk yönetimi planlayınız.',
    '{"name":"Ali Demir","age":"58","gender":"Erkek","mainComplaint":"Göğüs ağrısı","openingLine":"Göğsümde baskı var, sol koluma vuruyor.","applicationSetting":"Acil","complaintDuration":"45 dakika"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["STEMI","NSTEMI","Aort diseksiyonu","Pulmoner emboli"]'::jsonb,
    '["EKG","Troponin","Tam kan sayımı","Biyokimya"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    150,
    'heart',
    true,
    'Akut koroner sendrom şüphesi olan hastada hızlı değerlendirme ve reperfüzyon kararı.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'ischemic-stroke-001',
    'İnme Vakası',
    'Nöroloji',
    'Orta',
    7,
    'Dahiliye',
    'Ani gelişen nörolojik defisit ile gelen hastayı değerlendiriniz.',
    '{"name":"Zeynep Kaya","age":"63","gender":"Kadın","mainComplaint":"Konuşma bozukluğu","openingLine":"Kelimeleri çıkaramıyorum, sağ kolum güçsüz.","applicationSetting":"Acil","complaintDuration":"2 saat"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["İskemik inme","Hemorajik inme","Hipoglisemi","Todd paralizisi"]'::jsonb,
    '["Kan şekeri","Beyin BT","EKG","Koagülasyon"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    110,
    'brain',
    true,
    'Akut inme şüphesinde zaman penceresi ve nörolojik değerlendirme.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'copd-exacerbation-001',
    'KOAH Atak',
    'Göğüs Hastalıkları',
    'Kolay',
    6,
    'Acil',
    'Nefes darlığı artan hastada alevlenme yönetimini planlayınız.',
    '{"name":"Mustafa Arslan","age":"67","gender":"Erkek","mainComplaint":"Nefes darlığı","openingLine":"Son iki gündür nefesim çok daralıyor.","applicationSetting":"Acil","complaintDuration":"2 gün"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["KOAH alevlenmesi","Pnömoni","Kalp yetmezliği","Pulmoner emboli"]'::jsonb,
    '["Kan gazı","Akciğer grafisi","CRP","Tam kan sayımı"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    80,
    'lungs',
    true,
    'KOAH alevlenmesinde oksijen, bronkodilatör ve enfeksiyon değerlendirmesi.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'ectopic-pregnancy-001',
    'Ektopik Gebelik',
    'Kadın Doğum',
    'Zor',
    8,
    'Acil',
    'Alt karın ağrısı ve gecikmiş adet öyküsü olan hastayı değerlendiriniz.',
    '{"name":"Elif Nur","age":"29","gender":"Kadın","mainComplaint":"Alt karın ağrısı","openingLine":"Adetim gecikti, karnımın altı ağrıyor.","applicationSetting":"Acil","complaintDuration":"1 gün"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["Ektopik gebelik","Düşük tehdidi","Over torsiyonu","Pelvik inflamatuar hastalık"]'::jsonb,
    '["Beta-hCG","Transvajinal USG","Tam kan sayımı","Kan grubu"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    140,
    'heart',
    true,
    'Gebelik olasılığı olan hastada hayatı tehdit eden akut karın nedenleri.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'testicular-torsion-001',
    'Testis Torsiyonu',
    'Üroloji',
    'Zor',
    7,
    'Acil',
    'Ani başlayan skrotal ağrı ile gelen hastayı değerlendiriniz.',
    '{"name":"Burak Çelik","age":"18","gender":"Erkek","mainComplaint":"Testis ağrısı","openingLine":"Birden testisim çok ağrımaya başladı.","applicationSetting":"Acil","complaintDuration":"3 saat"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["Testis torsiyonu","Epididimit","İnguinal herni","Travma"]'::jsonb,
    '["Skrotal Doppler USG","Tam idrar tahlili","Tam kan sayımı"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    140,
    'urology',
    true,
    'Skrotal ağrıda zaman kritik torsiyon yaklaşımı.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'urinary-tract-infection-001',
    'İdrar Yolu Enfeksiyonu',
    'Dahiliye',
    'Kolay',
    5,
    'Poliklinik',
    'Dizüri ve sık idrara çıkma yakınması olan hastayı değerlendiriniz.',
    '{"name":"Ayşe Kaya","age":"34","gender":"Kadın","mainComplaint":"İdrarda yanma","openingLine":"İdrar yaparken yanma oluyor.","applicationSetting":"Poliklinik","complaintDuration":"2 gün"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["Sistit","Piyelonefrit","Vajinit","Üretrit"]'::jsonb,
    '["Tam idrar tahlili","İdrar kültürü"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    70,
    'kidney',
    true,
    'Alt üriner sistem semptomlarında komplike durumları ayırma.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'vaginal-discharge-001',
    'Vajinal Akıntı',
    'Kadın Doğum',
    'Orta',
    6,
    'Poliklinik',
    'Vajinal akıntı yakınması ile başvuran hastayı değerlendiriniz.',
    '{"name":"Ece Yılmaz","age":"26","gender":"Kadın","mainComplaint":"Vajinal akıntı","openingLine":"Son günlerde kötü kokulu akıntım var.","applicationSetting":"Poliklinik","complaintDuration":"1 hafta"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["Bakteriyel vajinozis","Kandidiyazis","Trikomonas","Servisit"]'::jsonb,
    '["Vajinal pH","Mikroskopi","NAAT"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    90,
    'gynecology',
    true,
    'Akıntı yakınmasında öykü, risk değerlendirmesi ve uygun test seçimi.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'biliary-colic-001',
    'Safra Koliği',
    'Genel Cerrahi',
    'Orta',
    6,
    'Acil',
    'Sağ üst kadran ağrısı olan hastayı değerlendiriniz.',
    '{"name":"Deniz T.","age":"42","gender":"Kadın","mainComplaint":"Sağ üst karın ağrısı","openingLine":"Yağlı yemekten sonra sağ tarafım ağrıyor.","applicationSetting":"Acil","complaintDuration":"5 saat"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["Safra koliği","Akut kolesistit","Pankreatit","Peptik ülser"]'::jsonb,
    '["Karaciğer fonksiyon testleri","Amilaz lipaz","Batın USG","Tam kan sayımı"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    100,
    'abdomen',
    true,
    'Sağ üst kadran ağrısında biliyer patoloji yaklaşımı.',
    '[]'::jsonb,
    '[]'::jsonb
  ),
  (
    'bph-001',
    'BPH Değerlendirme',
    'Üroloji',
    'Kolay',
    6,
    'Poliklinik',
    'Alt üriner sistem semptomları olan hastayı değerlendiriniz.',
    '{"name":"Mert Çelik","age":"66","gender":"Erkek","mainComplaint":"İdrar yapmada zorlanma","openingLine":"İdrara başlamakta zorlanıyorum.","applicationSetting":"Poliklinik","complaintDuration":"6 ay"}'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '["BPH","Prostat kanseri","Üretra darlığı","Mesane disfonksiyonu"]'::jsonb,
    '["Tam idrar tahlili","PSA","Kreatinin","USG"]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '[]'::jsonb,
    '{"communication":10,"history":30,"physicalExam":20,"differentialDiagnosis":15,"tests":15,"management":10}'::jsonb,
    80,
    'urology',
    true,
    'BPH semptom sorgulaması ve komplikasyon değerlendirmesi.',
    '[]'::jsonb,
    '[]'::jsonb
  )
on conflict (slug) do update set
  title = excluded.title,
  branch = excluded.branch,
  difficulty = excluded.difficulty,
  duration_minutes = excluded.duration_minutes,
  setting = excluded.setting,
  candidate_prompt = excluded.candidate_prompt,
  patient_profile = excluded.patient_profile,
  expected_history = excluded.expected_history,
  expected_physical_exam = excluded.expected_physical_exam,
  expected_differentials = excluded.expected_differentials,
  expected_tests = excluded.expected_tests,
  unnecessary_tests = excluded.unnecessary_tests,
  management_steps = excluded.management_steps,
  critical_mistakes = excluded.critical_mistakes,
  rubric = excluded.rubric,
  points = excluded.points,
  icon_key = excluded.icon_key,
  is_published = excluded.is_published,
  summary = excluded.summary,
  flow_steps = excluded.flow_steps,
  goals = excluded.goals,
  updated_at = now();

do $$
declare
  v_case_id uuid;
  v_exam_group_id uuid;
  v_test_group_id uuid;
begin
  select id into v_case_id
  from praticase.cases
  where slug = 'acute-appendicitis-001';

  delete from praticase.case_patient_response_rules where case_id = v_case_id;
  insert into praticase.case_patient_response_rules(case_id, match_terms, response, sort_order)
  values
    (v_case_id, array['başladı', 'ne zaman', 'süre'], 'Dün akşam saatlerinde başladı.', 10),
    (v_case_id, array['neresi', 'yeri', 'taraf'], 'Göbeğimin sağ alt tarafında daha çok.', 20),
    (v_case_id, array['bulantı', 'kusma'], 'Evet, 2-3 defa kustum.', 30),
    (v_case_id, array['ateş'], 'Ateşim oldu mu bilmiyorum ama üşüme geldi.', 40),
    (v_case_id, array['iştah'], 'Hiç iştahım yok.', 50),
    (v_case_id, array[]::text[], 'Tam olarak anlayamadım hocam, biraz daha açık sorar mısınız?', 999);

  delete from praticase.physical_exam_groups where case_id = v_case_id;
  insert into praticase.physical_exam_groups(case_id, title, sort_order)
  values (v_case_id, 'Batın', 10)
  returning id into v_exam_group_id;

  insert into praticase.physical_exam_options(group_id, title, finding, point_value, is_critical, sort_order)
  values
    (v_exam_group_id, 'Hassasiyet', 'Sağ alt kadranda belirgin hassasiyet mevcut.', 5, true, 10),
    (v_exam_group_id, 'Defans', 'Sağ alt kadranda istemli defans alınıyor.', 5, true, 20),
    (v_exam_group_id, 'Rebound', 'Rebound pozitif.', 5, true, 30),
    (v_exam_group_id, 'Rovsing', 'Rovsing bulgusu pozitif.', 3, false, 40),
    (v_exam_group_id, 'Psoas', 'Psoas bulgusu hafif pozitif.', 2, false, 50),
    (v_exam_group_id, 'Obturator', 'Obturator bulgusu negatif.', 1, false, 60);

  delete from praticase.test_groups where case_id = v_case_id;
  insert into praticase.test_groups(case_id, title, sort_order)
  values (v_case_id, 'Laboratuvar', 10)
  returning id into v_test_group_id;

  insert into praticase.test_options(group_id, title, result, point_cost, is_unnecessary, sort_order)
  values
    (v_test_group_id, 'Tam Kan Sayımı (Hemogram)', 'Lökosit 14.600/mm3, nötrofil hakimiyeti mevcut.', 15, false, 10),
    (v_test_group_id, 'CRP', 'CRP 78 mg/L ile yüksek.', 15, false, 20),
    (v_test_group_id, 'Biyokimya Paneli', 'Böbrek ve karaciğer fonksiyonları olağan sınırlarda.', 20, false, 30),
    (v_test_group_id, 'İdrar Tahlili', 'Belirgin hematüri veya piyüri saptanmadı.', 10, false, 40),
    (v_test_group_id, 'Laktat', 'Laktat 1.8 mmol/L.', 20, false, 50),
    (v_test_group_id, 'Kan Gazı', 'Metabolik asidoz bulgusu yok.', 20, false, 60);

  insert into praticase.test_groups(case_id, title, sort_order)
  values (v_case_id, 'Görüntüleme', 20)
  returning id into v_test_group_id;

  insert into praticase.test_options(group_id, title, result, point_cost, is_unnecessary, sort_order)
  values
    (v_test_group_id, 'Abdominal USG', 'Apendiks çapı 9 mm, çevresinde ekojen yağ dokusu ve minimal serbest sıvı.', 25, false, 10),
    (v_test_group_id, 'Tüm Batın MR', 'Bu aşamada rutin gerekli değil.', 40, true, 20);

  delete from praticase.diagnosis_options where case_id = v_case_id;
  insert into praticase.diagnosis_options(case_id, title, is_primary, is_correct, sort_order)
  values
    (v_case_id, 'Akut Apandisit', true, true, 10),
    (v_case_id, 'Meckel Divertiküliti', false, true, 20),
    (v_case_id, 'Gastroenterit', false, true, 30),
    (v_case_id, 'Üriner Kolik', false, false, 40),
    (v_case_id, 'İnflamatuvar Barsak Hastalığı', false, true, 50),
    (v_case_id, 'Over Kist Rüptürü', false, false, 60);

  delete from praticase.management_plan_options where case_id = v_case_id;
  insert into praticase.management_plan_options(case_id, category, title, point_value, is_recommended, sort_order)
  values
    (v_case_id, 'Başlangıç Tedavisi', 'IV sıvı tedavisi', 2, true, 10),
    (v_case_id, 'Başlangıç Tedavisi', 'Ağrı kontrolü (NSAİİ)', 2, true, 20),
    (v_case_id, 'Başlangıç Tedavisi', 'Geniş spektrumlu antibiyotik', 2, true, 30),
    (v_case_id, 'Başlangıç Tedavisi', 'Antiemetik', 1, false, 40),
    (v_case_id, 'Kesin Tedavi', 'Apendektomi (Laparoskopik)', 4, true, 50),
    (v_case_id, 'Kesin Tedavi', 'Apendektomi (Açık)', 3, false, 60),
    (v_case_id, 'Kesin Tedavi', 'Non-operatif takip', 1, false, 70),
    (v_case_id, 'Ek Yönetim', 'Hastaneye yatış', 2, true, 80),
    (v_case_id, 'Ek Yönetim', 'Oral alım kes', 2, true, 90),
    (v_case_id, 'Ek Yönetim', 'DVT profilaksisi', 1, false, 100);
end $$;

insert into praticase.badge_definitions(title, subtitle, icon_key, tier, target_count, sort_order, is_active)
values
  ('İlk Vakam', 'İlk vakamı tamamla', 'shield', 'silver', 1, 10, true),
  ('Tanı Ustası', '10 vakada doğru tanı koy', 'star', 'purple', 10, 20, true),
  ('Tetkik Uzmanı', '5 vakada gereksiz tetkik isteme', 'lab', 'green', 5, 30, true),
  ('Mükemmel Doktor', '%90+ puan al', 'gold', 'gold', 5, 40, true),
  ('Hızlı Çözücü', '5 vakayı 5 dk altında tamamla', 'timer', 'purple', 5, 50, true)
on conflict do nothing;

insert into praticase.support_topics(title, icon_key, sort_order, is_active)
values
  ('Kullanım Rehberi', 'book', 10, true),
  ('Vaka Nasıl Çözülür?', 'clipboard', 20, true),
  ('Puanlama Sistemi', 'chart', 30, true),
  ('Rozetler ve Başarılar', 'badge', 40, true),
  ('Teknik Destek', 'help', 50, true)
on conflict do nothing;

insert into praticase.faq_items(question, answer, sort_order, is_active)
values
  ('Vaka çözme nasıl çalışır?', 'Önce hastadan anamnez alır, sonra muayene, tetkik, tanı ve yönetim adımlarını tamamlarsın.', 10, true),
  ('Puanlar nasıl hesaplanır?', 'Puanlama anamnez, muayene, tetkik, tanı ve yönetim seçimlerinin rubrik karşılığına göre hesaplanır.', 20, true),
  ('Rozetler nasıl kazanılır?', 'Vaka tamamlama, doğru tanı ve gereksiz tetkikten kaçınma gibi hedeflerle kazanılır.', 30, true)
on conflict do nothing;

insert into praticase.announcements(title, body, icon_key, is_active, published_at)
values
  ('Yeni Vaka Serisi Yayında!', 'PratiCase başlangıç OSCE vaka paketi kullanıma açıldı.', 'badge', true, now()),
  ('Mobil Uygulama Güncellendi', 'iPhone safe-area uyumlu canlı PratiCase ekranları yayında.', 'phone', true, now())
on conflict do nothing;

commit;
