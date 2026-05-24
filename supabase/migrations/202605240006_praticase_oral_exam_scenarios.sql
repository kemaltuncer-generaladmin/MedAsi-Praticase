-- Sözlü sınav senaryo bankası: her branş için 3 kürasyon edilmiş vaka.
-- Kullanıcı Setup ekranında "AI rastgele üretsin" veya "Hazır senaryo seç"
-- seçeneklerinden birini kullanabilir. Hazır senaryolar Türk tıp fakültesi
-- sözlü sınavlarının klasik OSCE vakalarıdır.

begin;

create table if not exists praticase.oral_exam_scenarios (
  id text primary key,
  branch_id text not null references praticase.oral_exam_branches(id) on delete cascade,
  title text not null,
  case_brief text not null,
  opening_complaint text not null default '',
  learning_objectives jsonb not null default '[]'::jsonb,
  expected_differentials jsonb not null default '[]'::jsonb,
  red_flags jsonb not null default '[]'::jsonb,
  ideal_management jsonb not null default '[]'::jsonb,
  difficulty_floor text not null default 'Kolay'
    check (difficulty_floor in ('Kolay', 'Orta', 'Zor')),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table praticase.oral_exam_scenarios enable row level security;

drop policy if exists "Public can read oral exam scenarios"
  on praticase.oral_exam_scenarios;
create policy "Public can read oral exam scenarios"
on praticase.oral_exam_scenarios for select to anon, authenticated using (true);

grant select on praticase.oral_exam_scenarios to anon, authenticated, service_role;
grant all on praticase.oral_exam_scenarios to service_role;

-- DAHİLİYE
insert into praticase.oral_exam_scenarios(
  id, branch_id, title, case_brief, opening_complaint,
  learning_objectives, expected_differentials, red_flags, ideal_management,
  difficulty_floor, sort_order
) values
  (
    'dahiliye_kky',
    'dahiliye',
    'KKY Alevlenmesi',
    '65 yaşında erkek hasta, son üç gündür artan nefes darlığı ve bacaklarda şişlik yakınmasıyla polikliniğe başvuruyor. Geçmişinde hipertansiyon, koroner arter hastalığı (10 yıl önce stentlenmiş) ve atriyal fibrilasyon var. Tuza dikkat etmemiş, ilaçlarını düzensiz almış. Muayenede TA 150/90, nabız 110 (düzensiz), SS 24, SpO2 %91. Bilateral akciğer bazallerinde raller ve pretibial 2+ ödem mevcut.',
    'Hocam üç gündür merdiven çıkamıyorum, gece nefes alamayıp uyanıyorum.',
    '["Sistolik vs diyastolik kalp yetmezliği ayrımı","NYHA sınıflaması","Diüretik dozlama mantığı","Antikoagülasyon kararı (AF + KKY)","Tetkik önceliği: BNP, EKO, akciğer grafisi"]'::jsonb,
    '["Akut dekompanse kalp yetmezliği (en olası)","KOAH alevlenmesi","Akut koroner sendrom","Pulmoner emboli","Pnömoni"]'::jsonb,
    '["İstirahatte dispne","Bilateral raller + ödem birlikteliği","Hipoksemi (SpO2<92)","Hemodinamik instabilite","Yeni başlayan göğüs ağrısı"]'::jsonb,
    '["IV furosemid (önceki dozun 2 katı IV)","Oksijen desteği (SpO2 hedef >94)","Tuz/sıvı kısıtlama eğitimi","Antikoagülan dozaj kontrolü","Kardiyoloji konsültasyonu + yatış"]'::jsonb,
    'Kolay', 10
  ),
  (
    'dahiliye_anemi',
    'dahiliye',
    'Demir Eksikliği Anemisi Araştırması',
    '48 yaşında kadın hasta, 4 aydır artan halsizlik ve nefes darlığı ile başvuruyor. Çabuk yoruluyor, saçları dökülüyor. Menstrüel siklus düzenli ama yoğun. Geçmişinde tanılı hastalığı yok. Muayene: soluk konjonktiva, koilonişi, sistolik üfürüm (anemik), TA 110/70 nabız 96. Hb 7.8 g/dL, MCV 68, ferritin 6 ng/mL.',
    'Hocam çok halsizim, merdiven çıkarken bile soluk soluğa kalıyorum.',
    '["Mikrositer anemi ayırıcı tanısı","Demir eksikliğinin GİS etiyolojisi araştırması (özellikle perimenopozal kadında)","Oral vs parenteral demir kararı","Menstrüel kayıp + ek araştırma gerekliliği","Kolonoskopi endikasyonu"]'::jsonb,
    '["Demir eksikliği anemisi (en olası)","Talasemi taşıyıcılığı","Kronik hastalık anemisi","Sideroblastik anemi","Çölyak hastalığı"]'::jsonb,
    '["Hb<8 + semptom","Melena/hematokezi","Kilo kaybı","Karın ağrısı + anemi","Yaş >45 ve yeni demir eksikliği = GİS kanama dışlanmalı"]'::jsonb,
    '["Oral ferrik glisin sülfat 80mg/gün + C vitamini","Beslenme önerisi","Jinekoloji konsültasyonu (menoraji)","Gaita gizli kan + endoskopi/kolonoskopi planı","6 hafta sonra Hb kontrol"]'::jsonb,
    'Kolay', 20
  ),
  (
    'dahiliye_dka',
    'dahiliye',
    'Diyabetik Ketoasidoz',
    '24 yaşında erkek hasta, 2 haftadır artan halsizlik, polidipsi, poliüri ve bulantı yakınmasıyla acile geliyor. Son 24 saatte kusmuş, karın ağrısı tarif ediyor. Bilinen Tip 1 DM yok, baba diyabetik. Muayene: bilinç açık ama yorgun, mukozalar kuru, Kussmaul solunum, aseton kokusu. TA 100/60, nabız 124, kapiler dolum gecikmiş. Glukoz 412, pH 7.18, HCO3 11, idrarda keton 4+.',
    'Hocam çok susuyorum, sürekli tuvalete koşuyorum, kusmaktan duramıyorum.',
    '["DKA tanı kriterleri (glukoz, pH, keton)","Sıvı + insülin + potasyum üçlüsünün doğru sırası","Anyon gap hesaplama","Tetikleyici faktör araştırması","HHS ile ayrım"]'::jsonb,
    '["Diyabetik ketoasidoz (en olası)","Hiperozmolar hiperglisemik durum","Açlık ketozu","Alkolik ketoasidoz","Laktik asidoz"]'::jsonb,
    '["pH<7.0","Bilinç değişikliği","K<3.3 (insülin öncesi düzeltilmeli)","Serebral ödem bulguları (özellikle çocukta)","Beraberinde sepsis"]'::jsonb,
    '["IV %0.9 NaCl 1L bolus, sonra titre","Regüler insülin 0.1 U/kg/saat infüzyon (K düzeltildikten sonra)","K replasmanı (K<5.3 ise)","Glukoz 250 altına inince %5 dekstroz","Tetikleyici tarama (enfeksiyon, AKS)"]'::jsonb,
    'Orta', 30
  ),

  -- CERRAHİ
  (
    'cerrahi_apandisit',
    'cerrahi',
    'Akut Apandisit',
    '22 yaşında erkek hasta, 12 saat önce göbek çevresinde başlayan, sonra sağ alt kadrana göçen karın ağrısı, bulantı ve iştahsızlık ile acile başvuruyor. Son ateşi 38.2°C. Muayenede McBurney noktasında hassasiyet, rebound +, Rovsing +, defans yok. WBC 14.500, CRP 48, idrar tahlili normal.',
    'Hocam karnım çok ağrıyor, midemin çevresinde başladı, şimdi sağda.',
    '["Klasik apandisit klinik triadı","Alvarado skoru","Görüntüleme endikasyonları (USG ilk, BT zor vakada)","Beta-hCG önemi (kadın hastada)","Cerrahi vs gözlem kararı"]'::jsonb,
    '["Akut apandisit (en olası)","Mezenter lenfadenit","Sağ over kisti torsiyonu (kadın)","Sağ üreter taşı","Crohn ileiti","Meckel divertiküliti"]'::jsonb,
    '["Diffüz peritonit bulguları (perforasyon)","Hemodinamik instabilite","Yüksek ateş + sepsis kriterleri","Ağrı 48 saatten uzun (apse riski)","İmmünsüpresif hasta"]'::jsonb,
    '["IV sıvı resüsitasyonu","NPO + nasogastrik tüp (kusma varsa)","Geniş spektrum antibiyotik (sefoksitin veya seftriakson+metronidazol)","Genel cerrahi konsültasyonu","Laparoskopik apendektomi planı"]'::jsonb,
    'Kolay', 10
  ),
  (
    'cerrahi_kolesistit',
    'cerrahi',
    'Akut Kolesistit',
    '50 yaşında kadın hasta, dün akşam yağlı yemek sonrası başlayan sağ üst kadran ağrısı, bulantı ve sırt ağrısı ile acile geliyor. Daha önce de benzer ataklar olmuş ama bu kadar uzun sürmemiş. Muayene: Murphy belirtisi +, sağ üst kadran palpasyonla hassas, ateş 37.9°C. WBC 13.200, ALT 65, total bilirubin 1.2, lipaz normal. USG: taşlı safra kesesi, duvar kalınlığı 5mm, perikolesistik sıvı.',
    'Hocam sağ üst tarafım çok ağrıyor, dün gece kebap yedim, sonra başladı.',
    '["Akut taşlı kolesistit klinik tanı kriterleri","Murphy belirtisi yorumlaması","Cholangit (Charcot triadı) vs basit kolesistit ayrımı","Antibiyotik seçimi","Erken vs geç kolesistektomi tartışması"]'::jsonb,
    '["Akut kolesistit (en olası)","Koledokolitiyazis + kolanjit","Akut pankreatit","Peptik ülser perforasyonu","Sağ alt lob pnömoni"]'::jsonb,
    '["Sarılık + ateş + ağrı = kolanjit (acil ERCP)","Sepsis kriterleri","Şiddetli lökositoz >18000","Yaşlı, immünkompromize hasta","Gangrenöz/perforasyon bulguları"]'::jsonb,
    '["NPO + IV sıvı","Analjezi (NSAİİ veya opiat)","IV antibiyotik (seftriakson + metronidazol)","Genel cerrahi konsültasyonu","Erken laparoskopik kolesistektomi (24-72 saat)"]'::jsonb,
    'Orta', 20
  ),
  (
    'cerrahi_perforasyon',
    'cerrahi',
    'Perfore Peptik Ülser',
    '38 yaşında erkek hasta, 3 saat önce ani başlayan şiddetli karın ağrısı ile acile geliyor. Ağrı önce epigastrik bölgede, şimdi tüm karna yayılmış. NSAİİ kullanım öyküsü var (kronik sırt ağrısı için). Muayene: hasta yatağa çakılmış pozisyonda, batın tahta sertliğinde, defans +, rebound +, bağırsak sesleri kayıp. TA 100/60, nabız 118, ateş 37.4°C. Ayakta direkt batın grafisinde diafram altı serbest hava görülüyor.',
    'Hocam karnım sanki bıçak saplandı, kıpırdayamıyorum.',
    '["Akut karın + tahta sertliği = perforasyon","Ayakta batın grafisi + diafram altı serbest hava","Hemodinamik stabilizasyon önceliği","Sepsis yönetimi","Acil laparotomi endikasyonu"]'::jsonb,
    '["Perfore peptik ülser (en olası)","Perfore divertikülit","Mezenterik iskemi","Akut pankreatit (şiddetli)","Akut kolesistit perforasyon"]'::jsonb,
    '["Hipotansiyon + taşikardi","Diffüz peritonit","Septik şok","Yaşlı + komorbidite","Geç başvuru (>24 saat)"]'::jsonb,
    '["NPO + nasogastrik dekompresyon","2 geniş çaplı IV damar yolu + agresif sıvı","Geniş spektrum antibiyotik (piperasilin-tazobaktam)","PPİ IV","Acil genel cerrahi konsültasyonu + laparotomi"]'::jsonb,
    'Zor', 30
  ),

  -- ÇOCUK
  (
    'cocuk_bronsiyolit',
    'cocuk',
    'Akut Bronşiyolit',
    '9 aylık erkek bebek, 2 gündür artan öksürük, burun akıntısı ve son 12 saatte hışıltı + nefes darlığı ile acile getiriliyor. Beslenmesi azalmış, son 6 saatte bez ıslatmamış. Ateşi 37.8°C. Muayene: SS 60/dk, subkostal çekilme +, burun kanadı solunumu, oskültasyonda bilateral ronküs ve wheezing. SpO2 oda havasında %89. Mevsim kış.',
    'Annesi: Hocam bebeğim hırıltıyla nefes alıyor, mama da içmiyor.',
    '["Bronşiyolit klinik tanı (laboratuvar gerekmez)","RSV mevsimi","Solunum eforu derecelendirme","Hidrasyon değerlendirmesi","Yatış endikasyonları"]'::jsonb,
    '["Akut bronşiyolit (RSV) en olası","Astım atak","Pnömoni","Yabancı cisim aspirasyonu","Konjenital kardiyak hastalık dekompansasyonu"]'::jsonb,
    '["SpO2<92","Apneik ataklar","Beslenme reddi + dehidratasyon","Yaş <3 ay","Şiddetli solunum eforu","Toksik görünüm"]'::jsonb,
    '["Nazofarengeal aspirasyon (sekresyon)","Hipertonik salin nebulizasyon (3%)","Oksijen desteği (hedef SpO2 >92)","IV/NG hidrasyon","Yatış (yaş, SpO2, beslenme kriterleri ile)","NOT: bronkodilatör, steroid, antibiyotik rutin önerilmez"]'::jsonb,
    'Kolay', 10
  ),
  (
    'cocuk_otit',
    'cocuk',
    'Akut Otitis Media',
    '3 yaşında kız çocuk, 2 gündür ateş ve sağ kulak ağrısı yakınmasıyla polikliniğe geliyor. Gece uykudan uyanıp ağlamış, kulağına dokundurmuyor. Geçen ay üst solunum yolu enfeksiyonu geçirmiş. Muayene: ateş 38.6°C, sağ timpan zar hiperemik, bombe, ışık refleksi kaybolmuş, perforasyon yok. Faringeal hiperemi minimal.',
    'Annesi: Hocam ateşi düşmüyor, kulağına dokundurmuyor, dün gece hiç uyumadık.',
    '["Akut otitis media tanı kriterleri","Antibiyotik vs gözlem kararı (yaş + ciddiyet)","İlk seçim antibiyotik (amoksisilin)","Komplikasyonlar (mastoidit, menenjit)","Tekrarlayan otit + tympanostomi tüpü endikasyonu"]'::jsonb,
    '["Akut otitis media (en olası)","Effüzyonlu otitis media","Diş çıkarma ağrısı","Akut mastoidit","Eksternal otit"]'::jsonb,
    '["Şiddetli kulak arkası ağrı + şişlik (mastoidit)","Fasiyal paralizi","Menenjit bulguları","2 yaşın altında bilateral şiddetli OM","Yüksek ateş + toksik görünüm"]'::jsonb,
    '["Amoksisilin 80-90 mg/kg/gün 2 doz (10 gün)","Parasetamol/ibuprofen ile analjezi","Ev ortamı: sıcak kompres, başın yüksek tutulması","48-72 saat içinde yanıt yoksa yeniden değerlendirme","Komplikasyon belirtilerini aileye öğret"]'::jsonb,
    'Kolay', 20
  ),
  (
    'cocuk_dokuntu',
    'cocuk',
    'Ateş + Döküntü Ayırıcı Tanı',
    '5 yaşında erkek çocuk, 4 gündür yüksek ateş (39°C''ye kadar), öksürük, konjonktivit ve burun akıntısı, son 24 saatte yüz ve gövdede yayılan makülopapüler döküntü ile polikliniğe geliyor. Aşıları eksik (göçmen aile, MMR yok). Muayene: bukal mukozada beyaz noktalar (Koplik), bilateral konjonktivit, ateş 39.4°C, döküntü yüzden başlayıp gövdeye yayılmış.',
    'Annesi: Hocam ateşi düşmüyor, sonra döküntü çıktı, gözleri de kızardı.',
    '["Döküntülü çocuk hastalıkları ayırıcı tanısı (kızamık, kızamıkçık, suçiçeği, ELRD, scarlet)","Koplik lekeleri patognomonik","Aşı tarama önemi","Halk sağlığı bildirimi","Komplikasyonlar (pnömoni, ensefalit)"]'::jsonb,
    '["Kızamık (en olası — Koplik + döküntü)","Kızamıkçık","Roseola infantum","Eritema infektiyozum (5. hastalık)","Skarlatina","Kawasaki hastalığı"]'::jsonb,
    '["Pnömoni komplikasyonu","Akut ensefalit (bilinç değişikliği)","İmmün yetmezlik öyküsü","Dehidratasyon","Subakut sklerozan panensefalit riski (uzun vade)"]'::jsonb,
    '["İzolasyon (5 gün döküntü sonrası)","Halk sağlığı bildirimi","Destek tedavisi: ateş kontrolü, hidrasyon","A vitamini (DSÖ önerisi, ciddi vakada)","Aşılama sonrası planı + temaslıları MMR/IG profilaksisi"]'::jsonb,
    'Orta', 30
  ),

  -- KADIN DOĞUM
  (
    'kadin_ektopik',
    'kadin_dogum',
    'Ektopik Gebelik Şüphesi',
    '28 yaşında kadın hasta, 8 hafta amenore sonrası başlayan sağ alt kadran ağrısı ve vajinal lekelenme ile acile başvuruyor. Son menstrüel periyot 8 hafta önce, daha önce klamidya enfeksiyonu ve PID öyküsü var. Muayene: TA 100/65, nabız 102, sağ adneksiyal hassasiyet, servikal hareketle ağrı +. Beta-hCG 4200 mIU/mL. Transvajinal USG: uterusta gestasyonel kese yok, sağ adneksiyal kompleks kitle 3 cm, Douglas''ta minimal serbest sıvı.',
    'Hocam adetim gecikti, son birkaç gündür sağ tarafımda ağrı var ve hafif kanama oldu.',
    '["β-hCG diskriminatif düzey (>1500-2000 → USG''de intrauterin kese görülmeli)","Adneksiyal ağrı + amenore + β-hCG + boş uterus = ektopik şüphesi","Risk faktörleri (PID, tubal cerrahi, IVF, IUD)","Rüptür belirtileri","Metotreksat vs cerrahi karar"]'::jsonb,
    '["Tubal ektopik gebelik (en olası)","İmplantasyon sancısı","Spontan abortus","Korpus luteum kisti","Akut apandisit (kadın hasta)","Over torsiyonu"]'::jsonb,
    '["Hemodinamik instabilite (rüptür şüphesi)","Şiddetli karın ağrısı + omuz ağrısı (diyafram irritasyonu)","Senkop","Beta-hCG >5000 + kompleks kitle","Düşmüş Hb"]'::jsonb,
    '["2 geniş çaplı IV damar yolu","Tam kan + kan grubu + crossmatch","Kadın doğum acil konsültasyonu","Rüptür yoksa ve uygunsa metotreksat","Rüptür/instabilite varsa acil laparoskopi","Rh negatifse anti-D"]'::jsonb,
    'Orta', 10
  ),
  (
    'kadin_preeklampsi',
    'kadin_dogum',
    'Şiddetli Preeklampsi',
    '32 yaşında kadın, 32 haftalık ilk gebe, son 3 gündür artan baş ağrısı, görme bulanıklığı, sağ üst kadran ağrısı ve ödem ile acile geliyor. Daha önceki kontrollerde TA 130/85 dışında özellik yok. Muayene: TA 168/108 (iki ölçüm), pretibial 3+ ödem, hiperrefleksi, klonus +. İdrar protein/kreatinin oranı 1.2, trombosit 90.000, AST 110, LDH 480. Fetal kalp atımı 145 düzenli, NST reaktif.',
    'Hocam başım çok ağrıyor, gözlerimde ışıklar çakıyor, midemin üstü ağrıyor.',
    '["Şiddetli preeklampsi tanı kriterleri (TA, end-organ hasarı)","HELLP sendromu","Magnezyum sülfat profilaksisi (eklampsi)","Antihipertansif seçimi (labetalol, hidralazin, nifedipin)","Doğum kararı (32 hafta + şiddetli özellik)"]'::jsonb,
    '["Şiddetli preeklampsi (en olası)","HELLP sendromu","Gebeliğin akut yağlı karaciğeri","Migren + gebelik","Pyelonefrit"]'::jsonb,
    '["Eklampsi (konvulsiyon)","HELLP tam tablosu","Akut böbrek yetmezliği","Pulmoner ödem","Placental abruptio","Fetal distress"]'::jsonb,
    '["Magnezyum sülfat IV yükleme + idame","Antihipertansif (TA<160/110 hedef)","Sol yan yatış pozisyonu","Steroid (akciğer matürasyonu, <34 hafta)","Doğum kararı (multidisipliner): genelde 34 hafta öncesi steroid sonrası, şiddetli vakada acil"]'::jsonb,
    'Zor', 20
  ),
  (
    'kadin_pkos',
    'kadin_dogum',
    'Polikistik Over Sendromu',
    '24 yaşında kadın, 2 yıldır düzensiz adet kanaması (yılda 4-5 kez), yüzde ve göğüste artan tüylenme, akne ve son 6 ayda 8 kg kilo alımı şikayetiyle polikliniğe geliyor. Yakınmaları evlendikten sonra çocuk istemesi ile öne çıkmış. Aile öyküsünde anne T2DM. Muayene: VKİ 31, hirsutizm (Ferriman-Gallwey 18), akne, akantozis nigrikans. Pelvik USG: bilateral overlerde >12 küçük folikül.',
    'Hocam adetlerim çok düzensiz, tüylenmeden çok rahatsızım ve bir türlü hamile kalamıyorum.',
    '["Rotterdam kriterleri (3''ten 2: oligo/anovulasyon, hiperandrojenizm, PKO morfoloji)","İnsülin direnci + metabolik sendrom ilişkisi","Yaşam tarzı modifikasyonu öncelik","Ovulasyon indüksiyonu (klomifen, letrozol)","Endometrium koruma (siklik progesteron)"]'::jsonb,
    '["Polikistik Over Sendromu (en olası)","Konjenital adrenal hiperplazi non-klasik form","Cushing sendromu","Hipotiroidi","Hiperprolaktinemi","Androjen üreten tümör"]'::jsonb,
    '["Hızlı virilizasyon (3-6 ayda) → tümör şüphesi","Şiddetli akantozis nigrikans + kilo + hipertansiyon → metabolik sendrom","Endometrial hiperplazi/karsinom riski","Uyku apnesi","Depresyon/anksiyete"]'::jsonb,
    '["Yaşam tarzı: kilo verme %5-10","Hirsutizm: kombine OK, spironolakton","İnsülin direnci: metformin","Gebelik isteyen hastada: letrozol/klomifen ile ovulasyon indüksiyonu","Yıllık endometrium + OGTT + lipid takibi"]'::jsonb,
    'Orta', 30
  ),

  -- ACİL TIP
  (
    'acil_aks',
    'acil',
    'Akut Koroner Sendrom Şüphesi',
    '58 yaşında erkek hasta, 2 saat önce ani başlayan retrosternal sıkıştırıcı göğüs ağrısı, sol kola yayılım, terleme, bulantı ile acile getiriliyor. Risk faktörleri: 30 yıl sigara, HT, hiperlipidemi, baba 55 yaşında MI. Muayene: TA 145/95, nabız 102, SS 22, SpO2 %96. Akciğerler temiz, kalp sesleri normal. EKG: D2-D3-aVF''de 2mm ST elevasyon, V1-V3''te resiprokal ST depresyonu. İlk troponin yüksek hassasiyetli 28 ng/L (referans <14).',
    'Hocam göğsümde bir bıçak gibi ağrı var, kolum uyuştu, çok terliyorum.',
    '["STEMI vs NSTEMI vs unstabil angina ayrımı","İnferior MI + RV infarkt olasılığı (nitrat dikkat)","Reperfüzyon kararı: PKİ vs tromboliz (zaman + erişim)","Door-to-balloon hedefi (<90dk)","Erken DAPT (dual antiplatelet)"]'::jsonb,
    '["İnferior STEMI (en olası)","Unstabil angina","Akut perikardit","Aort diseksiyonu","Pulmoner emboli","GIS perforasyonu"]'::jsonb,
    '["Kardiyojenik şok","Mekanik komplikasyonlar (papiller adale rüptürü, VSR)","RV infarkt + hipotansiyon → IV sıvı (NİTRAT VERME)","Yeni ileti bloğu","Refrakter ağrı/aritmi"]'::jsonb,
    '["MONA-B: Morfin (refrakter ağrı), Oksijen (SpO2<90), Nitrogliserin (RV inf. dikkat), Aspirin 300mg çiğnetilir, β-bloker (kontraendike değilse)","DAPT: ASA + tikagrelor/klopidogrel","Antikoagülan (UFH veya enoksaparin)","Acil PKİ çağrısı (<90dk hedef)","Statin yükleme"]'::jsonb,
    'Zor', 10
  ),
  (
    'acil_pte',
    'acil',
    'Pulmoner Emboli Şüphesi',
    '45 yaşında kadın hasta, 4 saat önce ani başlayan nefes darlığı, plöritik göğüs ağrısı ve sol bacakta şişlik ile acile geliyor. 3 gün önce 11 saatlik uçak yolculuğu yapmış, oral kontraseptif kullanıyor, BMI 32. Muayene: TA 110/72, nabız 118, SS 26, SpO2 %91. Akciğerler temiz, sol baldır şiş ve hassas. EKG: sinüs taşikardisi, S1Q3T3 paterni. D-dimer 4800 ng/mL (referans <500).',
    'Hocam ani nefes darlığım oldu, nefes alırken göğsüm batıyor, bacağım da şişti.',
    '["Wells skoru / PERC kriterleri","D-dimer kullanımı (yaşa göre düzeltme)","BT pulmoner anjiografi vs V/Q sintigrafisi","Antikoagülan başlatma eşiği","Masif PTE → tromboliz endikasyonu"]'::jsonb,
    '["Pulmoner emboli (yüksek olasılık)","Pnömoni","Pnömotoraks","Akut koroner sendrom","Anksiyete + hiperventilasyon"]'::jsonb,
    '["Hipotansiyon (masif PTE → tromboliz)","Hipoksemi şiddetli","Sağ ventrikül disfonksiyonu (EKO)","Kardiyak arrest","Senkop"]'::jsonb,
    '["Oksijen desteği","IV LMWH veya UFH (gecikme olmamalı)","BT pulmoner anjiografi (stabilse)","Stabil değilse yatak başı EKO + tromboliz değerlendirmesi","Yatış + 3-6 ay antikoagülan plan","Risk faktörü (OK) durdurma"]'::jsonb,
    'Zor', 20
  ),
  (
    'acil_svo',
    'acil',
    'Akut İskemik İnme — Tromboliz Penceresi',
    '70 yaşında erkek, 2 saat önce eşinin gözlemiyle aniden başlayan konuşma bozukluğu (anlamlı konuşamıyor), sağ üst ekstremitede güçsüzlük ile acile getiriliyor. Bilinen HT, AF (warfarin almıyor, sonuncu INR bilinmiyor), DM var. Son normal görüldüğü zaman 2 saat 10 dakika önce. Muayene: bilinç açık, motor afazi, sağ üst ekstremite 1/5 kuvvet, sağ alt 4/5, fasiyal paralizi sağda. NIHSS 12. Acil BT: erken iskemik değişiklik minimal, kanama yok. Glukoz 142, INR 1.1.',
    'Eşi: Hocam aniden konuşamadı, sağ kolunu kaldıramadı, çay servisi sırasında oldu.',
    '["Akut iskemik inme tanısı + tromboliz penceresi (4.5 saat)","NIHSS skorlama","BT öncesi tromboliz vermek YASAK","Kontrendikasyon listesi (kanama, antikoagülan kullanımı, son cerrahi, INR>1.7)","Mekanik trombektomi penceresi (LVO için 6-24 saat)"]'::jsonb,
    '["Akut iskemik inme (en olası — LVO şüphesi)","İntraserebral kanama (BT ile dışlandı)","Hipoglisemi (glukoz normal)","Postiktal Todd parezi","Migren auralı"]'::jsonb,
    '["Pencere dışı başvuru","Antikoagülan kullanımı (warfarin INR>1.7, DOAC son 48 saat)","Aktif kanama","Yakın zamanda büyük cerrahi","Şiddetli HT (>185/110, kontrol edilmeli)","Hızlı düzelen semptom (tromboliz gereksiz)"]'::jsonb,
    '["ABC + iki damar yolu + monitör","Hipoglisemi düzeltilirse anında","TA hedef <185/110 (labetalol IV)","BT sonrası kanama yok + kontrendikasyon yok → IV tPA 0.9mg/kg","NIHSS≥6 + LVO → mekanik trombektomi için nöroloji + girişimsel radyoloji","Yutma testi + aspirasyon önleme","Stroke ünitesine yatış"]'::jsonb,
    'Zor', 30
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
  sort_order = excluded.sort_order;

create index if not exists oral_exam_scenarios_branch_idx
  on praticase.oral_exam_scenarios(branch_id, sort_order);

insert into praticase.self_hosted_schema_migrations(version, filename)
values ('202605240006', '202605240006_praticase_oral_exam_scenarios.sql')
on conflict (version) do nothing;

commit;
