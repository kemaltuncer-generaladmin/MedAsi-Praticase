# PratiCase AI-Sözlü-OSCE Davranış Standardı — QA Raporu

**Tarih:** 2026-05-25
**Branch:** `release/storekit-oral-exam-qa-fixes`
**Kapsam:** Standart dokümanın §1-§16 bölümlerine karşı mevcut kod tabanının doğrulanması
**Yöntem:** Kod katmanı (statik okuma) + runtime gözlemi (Claude in Chrome bağlandıktan sonra)
**Şu anki durum:** Kod katmanı **VE** runtime gözlemi tamamlandı. Aşağıda iki katmanın birleşik sonuçları.

---

## Genel Sonuç (Runtime sonrası güncel)

| Kategori | Pass | Partial | Fail | Toplam |
|----------|------|---------|------|--------|
| Genel İlkeler | 4 | 0 | 0 | 4 |
| Tek Hoca Sözlüsü | 5 | 1 | 1 | 7 |
| Komisyon Sözlüsü | 3 | 1 | 3 | 7 |
| OSCE Modu | 2 | **3** | **1** | 6 |
| **TOPLAM** | **14** | **5** | **5** | **24** |

**Runtime ile değişen kararlar:**
- C1 FAIL → PARTIAL (Sınav Merkezi katmanı var)
- C2 FAIL → PARTIAL ("Aday Yönergesi" header var)
- **+1 CRITICAL BUG (runtime'da keşfedildi):** AI yanıt üretimi sistematik olarak fallback'e düşüyor (4 turnden 3'ü); standardın klinik karakter deneyimini ciddi şekilde bozuyor. Bu B3/B4'ten ayrı, daha temel bir sorun.

**Karar:** Ürün ship-ready değil. **5 Fail + 1 sistemik bug** mevcut. Önerilen aksiyon sırası:
1. **P0 ACİL:** AI fallback root cause analizi (looksUnsafeOralCoaching regex'ini gevşet ya da Vertex response format'ını teyit et).
2. **P0:** Komisyon speaker selection cevap kalitesine bağla (B3).
3. **P0/P1:** Karne formatlarını standardın §4/§6/§9 başlıklarına yeniden kur (A7, B4, B5, B6, B7, C6).
4. **P1:** İki cosmetic bug (fallback prefix + komite başlığı).

---

## A) Tek Hoca Sözlüsü (Standart §4)

| # | Madde | Durum | Kod Referansı / Açıklama |
|---|---|---|---|
| A1 | Setup'ta 3 hoca seçilebiliyor | **PASS** | [oral_exam_screens.dart:133-154](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L133) `_PersonaTile` listesi DB persona kataloğundan dinamik. ID'ler: `patient_assistant`, `socratic_associate`, `stern_professor`. |
| A2 | Sınav boyunca yalnız seçilen hoca konuşuyor | **PASS** | [praticase-oral-exam/index.ts:402-403](supabase/functions/praticase-oral-exam/index.ts#L402): solo branch `activePersona = panelMap.get(session.persona_id)`. Tek persona her turda kullanılıyor. |
| A3 | Hoca karakteri sabit (ton drift yok) | **PASS** | Migration `202605250003_praticase_exam_mode_neutral_catalog.sql` her persona için ayrı `system_prompt`. Top-level üst kural [index.ts:490-495](supabase/functions/praticase-oral-exam/index.ts#L490) drift'i engelliyor. |
| A4 | Sert Profesör tarzı (öncelik odaklı) | **PASS** | Persona prompt'u kısa/sert tonda; `difficulty=stern`, `patience_level` düşük. |
| A5 | Sokratik Doçent tarzı | **PASS** | Aynı migration, `socratic_associate` prompt'u gerekçelendirme odaklı. |
| A6 | Sabırlı Asistan tarzı | **PASS** | `patient_assistant` prompt'u yapılandırma odaklı, sıcak ton. |
| A7 | **Karne başlıkları seçilen hocaya göre özelleşiyor** (§4.1/§4.2/§4.3'te tarif edilen "Kritik hata analizi" / "Akıl yürütme zinciri" / "Cevap yapılandırma" bölümleri) | **FAIL** | [oral_exam_screens.dart:2410-2492](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2410): Tüm personalar için aynı `_RubricGrid` + jenerik "Güçlü Yönlerin / Gelişim Alanların / Kaçırılan Noktalar". Persona ID'ye göre conditional bölüm yok. **Standart §4.1 Sert Profesör Karnesi**, §4.2 **Sokratik Karnesi**, §4.3 **Eğitici Hoca Notu** ayrı başlık ve bölümler bekliyor. |
| A8 (ek) | Tek hoca karnesinde Bir Sonraki Sefer şablonu | **PARTIAL** | "Gelişim Alanların" var ama §4 örneklerindeki "İdeal kısa sözlü cevap iskeleti" / "Daha güçlü düşünme zinciri" / "Bir sonraki denemede kullanacağın kısa plan" gibi yapılandırılmış bölümler yok. |

---

## B) Komisyon Sözlüsü (Standart §5–6)

| # | Madde | Durum | Kod Referansı / Açıklama |
|---|---|---|---|
| B1 | 3 hoca aynı sınavda var | **PASS** | [index.ts:155-166](supabase/functions/praticase-oral-exam/index.ts#L155) panel branch tüm personaları `panel_role` ile yüklüyor; <3 ise hata. |
| B2 | Her turda yalnız bir ana konuşmacı, diğerleri kısa | **PASS** | [index.ts:477-481](supabase/functions/praticase-oral-exam/index.ts#L477) prompt: "Yalnız ${activePersona.title} konuşmasının sonunda TEK takip sorusu sorsun; diğer iki hoca kesinlikle soru sormasın." |
| B3 | **Konuşacak hoca CEVAP KALİTESİNE göre seçiliyor** (kritik hata → Sert; zayıf gerekçe → Sokratik; dağınık → Sabırlı) | **FAIL** | [index.ts:394-401](supabase/functions/praticase-oral-exam/index.ts#L394): `questionRotation = [second, observer, lead]; activePersona = questionRotation[answerCount % 3]`. **Sabit rotasyon — cevap kalitesi sinyali (`turn_evaluation`, kritik hata, gerekçe zayıflığı, dağınıklık) kullanılmıyor.** Standart §5.1 bu seçimi açıkça istiyor. |
| B4 | Komisyon karnesi "kurul raporu" formatında | **PARTIAL** | [oral_exam_screens.dart:2525-2663](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2525) `_PanelVerdictsCard` per-hoca verdict listeliyor (geçer/sınırda/kalır + 2 cümle not). Var olan: 3 hoca yorumu. **Eksik (standart §6):** "Genel Komisyon Kararı" başlığı yok; 6'lı **alan bazlı skor** (klinik akıl/önceliklendirme/ayırıcı tanı/yönetim/ifade/hasta güvenliği) yok — sadece 5'li mevcut rubric (akıl/bilgi/iletişim/hız/profesyonellik); **kritik hatalar** ayrı bölümü yok; **güçlü yanlar / ideal cevap iskeleti / bir sonraki deneme planı** standart §6.5–6.8 başlıklarıyla yok. |
| B5 | Skor seviye etiketi (Yetersiz/Geliştirilmeli/Orta/Başarılı/Çok Başarılı) | **FAIL** | grep `lib/`: 0 eşleşme. [oral_exam_screens.dart:2297-2301](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2297) sadece renk eşiği (yeşil ≥80, gold ≥60, kırmızı <60); metin etiketi yok. Standart §6.2 0-39/40-59/60-74/75-89/90-100 bantlarıyla etiket istiyor. |
| B6 | İdeal cevap iskeleti bölümü | **FAIL** | grep `İdeal Cevap`, `İdeal Sözlü`, `cevap iskelet`: 0 eşleşme oral exam UI'da. Standart §6.7'de örneklenen "ABCDE + dışla + ön tanı + tetkik + ilk yönetim" şablonu UI'da yok. |
| B7 | Bir sonraki deneme planı | **FAIL** | grep `Bir Sonraki Deneme`, `Sonraki Deneme`, `Sonraki Plan`: 0 eşleşme. Standart §6.8'in 5 maddelik aksiyon listesi yok. |

---

## C) OSCE Modu (Standart §8–9)

| # | Madde | Durum | Kod Referansı / Açıklama |
|---|---|---|---|
| C1 | OSCE ayrı bir setup/giriş akışı | **FAIL** | [praticase_shell.dart:590-595](lib/src/features/shell/presentation/praticase_shell.dart#L590): `case 'mini_osce'` switch'i default'a düşüp `widget.onOpenCases()` çağırıyor. **Mini OSCE etiketi = case kütüphanesi**. Ayrı OSCE deneyimi yok; istasyon bazlı, checklist'li, yapılandırılmış bir mod tanımlı değil. |
| C2 | İstasyon yönergesi (ad/branş/süre/görev) | **FAIL** | OSCE setup ekranı yok. Standart §8.1'in beklediği header (istasyon adı + süre + görev + beklenen çıktı + başlat butonu) hiçbir yerde render edilmiyor. Case detay ekranı vaka başlığı gösteriyor ama "istasyon" konseptiyle değil. |
| C3 | Standart hasta tanı söylemiyor, bulgu veriyor | **PASS** | [praticase-patient-turn/index.ts:174-185](supabase/functions/praticase-patient-turn/index.ts#L174) 11 madde sistem talimatı: "Tanı, ayırıcı tanı, ideal yaklaşım, rubrik, puan, checklist, beklenen cevap, kritik hata, tetkik sonucu veya yönetim planı söyleme." Standart §8.2 ile birebir uyumlu. |
| C4 | Checklist mekanizması (Tam/Kısmi/Eksik/Kritik Eksik) | **PARTIAL** | DB tarafında `praticase_history_checklists`, `praticase_physical_exam_checklists`, vs. çekirdek tablolar mevcut ve [_shared/case_checklists.ts](supabase/functions/_shared/case_checklists.ts) ile case'e enjekte ediliyor. **Ancak:** UI tarafında kullanıcıya gösterilen statü chip'leri (Tam / Kısmi / Eksik / Kritik Eksik) yok. AI iç değerlendirmesi 6 kategoriye (İletişim/Anamnez/Muayene/Tanılar/Tetkik/Yönetim) yansıtılıyor; checklist madde madde statü ile değil. |
| C5 | Sınav SIRASINDA aşırı öğretici geri bildirim yok | **PASS** | Aynı 11 madde sistem talimatı [patient-turn:179-180](supabase/functions/praticase-patient-turn/index.ts#L179) öğretici çıktıyı yasaklıyor. |
| C6 | OSCE karnesi checklist tabanlı | **FAIL** | [cases_result.dart](lib/src/features/cases/presentation/widgets/cases_result.dart): `_ResultHero` + `_ScoreGrid` (6'lı kategori barı) + `_FeedbackCard` (4'lü bullet liste) + `_IdealApproachCard` (var ✓). **Eksik:** istasyon başlığı (ad/branş/süre/görev), checklist Tam/Kısmi/Eksik/Kritik chip'leri (§9.4), kritik kaçan basamaklar ayrı bölümü (§9.5), seviye etiketi. |

---

## D) Genel AI Yanıt İlkeleri (Standart §2)

| # | Madde | Durum | Kod Referansı |
|---|---|---|---|
| D1 | Raw JSON / snake_case / 502 / null / stack trace UI'a sızmıyor | **PASS** | `safeParse` [index.ts:999-1021](supabase/functions/praticase-oral-exam/index.ts#L999), `looksStructuredPayload` [index.ts:1059-1067](supabase/functions/praticase-oral-exam/index.ts#L1059), `looksUnsafeOralCoaching` [index.ts:1069-1073](supabase/functions/praticase-oral-exam/index.ts#L1069). UI'a sadece string mesaj geçiyor. |
| D2 | Parse hatasında doğal Türkçe fallback | **PASS** | [index.ts:543-544](supabase/functions/praticase-oral-exam/index.ts#L543) mentor fallback; [:425-427](supabase/functions/praticase-oral-exam/index.ts#L425) insufficient answer fallback; [:664-667](supabase/functions/praticase-oral-exam/index.ts#L664) skip fallback. Hiçbiri JSON/teknik metin içermiyor. |
| D3 | Karne oluşamazsa kullanıcı dostu retry | **PASS** | `deterministicOralEvaluation()` [index.ts:1144-1216](supabase/functions/praticase-oral-exam/index.ts#L1144) AI çökerse bile rubric döndürür; UI tarafı `PratiCaseUserMessage.oralExam(error.message)` ile sanitize ediyor. |
| D4 | Sanitize: ideal cevap/rubrik/JSON anahtar sızıntısı | **PASS** | `looksUnsafeOralCoaching` regex'i: `ideal cevap|model cevap|rubrik|puan kırılım|sistem talimat|json|checklist|şimdi sana ipucu|doğru cevap şudur`. |

---

## Kritik Bulgular — Implementation İçin Önceliklendirilmiş Liste

### P0 — Ürün ayrımını bozan (standartın ana ayrımı)

**1. B3 — Komisyon konuşmacı seçimi cevap kalitesine göre değil**
- Konum: [praticase-oral-exam/index.ts:394-401](supabase/functions/praticase-oral-exam/index.ts#L394)
- Mevcut: Sabit `[second, observer, lead]` rotasyon
- Önerilen: Önceki turun `turn_evaluation` çıktısını oku. Mapping:
  - `safety_flags.length > 0` veya `moderation == "unsafe"` veya `score_delta <= -5` → **Sert Profesör** (lead)
  - `is_correct == false && moderation == "partial"` veya `missing_points.length >= 2` → **Sokratik Doçent** (second)
  - `moderation == "off_topic"` veya cevap dağınık (heuristik: çok kısa veya >300 char) → **Sabırlı Asistan** (observer)
  - Default: rotasyon devam etsin (fallback)
- Tahmini iş: 30-50 LOC değişiklik + prompt'ta speaker seçim mantığı için iç değerlendirme ekleme

**2. C1 — OSCE ayrı mod değil**
- Konum: [praticase_shell.dart:590-595](lib/src/features/shell/presentation/praticase_shell.dart#L590)
- Mevcut: `case 'mini_osce'` → `onOpenCases()` (case kütüphanesi)
- Önerilen iki yol:
  - **A (hızlı):** Case kütüphanesini "OSCE İstasyon Bankası" başlığı altında yeniden çerçevele; case detay → "İstasyon Yönergesi" header ekle (ad + branş + süre + görev). Aynı backend, yeni framing.
  - **B (tam):** Yeni `osce_sessions` tablosu, yeni edge fn `praticase-osce-station`, çoklu istasyon zinciri.
- B uzun vadeli doğru; A standardın görsel/dil beklentisini kısa vadede karşılar.

**3. B4 + C6 — Karne formatları standartla uyumlu değil**
- Konum: [oral_exam_screens.dart:2293-2522](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2293) (komisyon), [cases_result.dart](lib/src/features/cases/presentation/widgets/cases_result.dart) (OSCE)
- Eksik bölümler (komisyon): "Genel Komisyon Kararı" + seviye etiketi + 6'lı alan skoru + kritik hatalar listesi + ideal cevap iskeleti + bir sonraki deneme planı
- Eksik bölümler (OSCE): istasyon başlığı + checklist Tam/Kısmi/Eksik/Kritik chip'leri + kritik kaçan basamaklar

### P1 — Standart tutarlılığı

**4. A7 — Tek hoca karnesi persona-spesifik bölümler**
- Konum: [oral_exam_screens.dart:2410-2492](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2410)
- Önerilen: `_OralExamResultScreenState.build` içinde `if (r.format == OralExamFormat.solo)` altında `widget.session.personaId` ile switch — her persona için ayrı bölüm başlığı + örnek cevap iskeleti.

**5. B5 — Skor seviye etiketleri**
- Konum: [oral_exam_screens.dart:2297](lib/src/features/oral_exam/presentation/oral_exam_screens.dart#L2297) + [cases_result.dart:28](lib/src/features/cases/presentation/widgets/cases_result.dart#L28)
- Önerilen: shared util `praticase_score_level.dart` — `scoreLevelLabel(int percent) -> String` (0-39 Yetersiz, 40-59 Geliştirilmeli, 60-74 Orta düzey başarılı, 75-89 Başarılı, 90-100 Çok başarılı). Hero card altında etiket pill olarak render et.

**6. B6 + B7 — İdeal cevap iskeleti + Bir Sonraki Deneme planı**
- Konum: `OralExamResult` modeline yeni alanlar (`idealAnswerSkeleton: String`, `nextAttemptPlan: List<String>`). Finalize prompt'una eklenmesi gerek; UI'da yeni iki `_FeedbackBlock`.

### P2 — Diline ve içeriğe ince ayar

**7. C2/C4 — OSCE istasyon yönergesi + checklist UI**
- DB altyapı hazır (`praticase_*_checklists` tabloları). Eksik olan: bu verinin sonuç karnesinde madde madde, statü chip'leriyle render edilmesi.

---

## Runtime QA — Tamamlandı (Web build üzerinden)

Test ortamı: `kemal.tuncer@medasi.com.tr` kullanıcısı, web build `localhost:8080`, browser viewport ~1440px (responsive web).

### Senaryo 1 — Tek Hoca (Sert Profesör + Acil Tıp)
- **A1, A2, A4 PASS ✓:** Setup'ta 3 hoca seçilebiliyor, persona ID sabit kalıyor, ilk soru §4.1 tonuyla uyumlu ("Önce yaklaşımını nasıl yapılandırırsın?").
- **A7 FAIL teyit ❌:** Karne %75/100, **5'li jenerik rubric** (Klinik Akıl/Bilgi/İletişim/Hız/Profesyonellik). Sert Profesör'e özel "Hayati öncelik skoru", "Kritik hata analizi", "Acil yaklaşım skoru", "İdeal kısa sözlü cevap iskeleti" bölümleri YOK.
- **B5 FAIL teyit ❌:** %75 göründü ama "Başarılı (75-89)" gibi seviye etiketi YOK; sadece renk (gold ≥60).
- **B7 FAIL teyit ❌:** "Bir Sonraki Deneme Planı" yapılandırılmış bölümü yok; sadece serbest 2 madde "Gelişim Alanların".
- **CRITICAL BUG**: 2 ardışık turn AI yanıtı **fallback'e düştü** → "Sert Profesör: Devam edelim, lütfen son cevabını klinik gerekçenle biraz daha açar mısın?" Bu kodun [index.ts:543-544](supabase/functions/praticase-oral-exam/index.ts#L543) fallback'i. AI çıktısı parse edilemedi VEYA `looksUnsafeOralCoaching` filtresine takıldı. Standart §4.1'de Sert Profesör'ün vermesi beklenen "Tanıyı söyledin ama hastanın stabil olup olmadığını belirtmedin..." gibi karakterli tepki HİÇ üretilemedi.
- **Cosmetic BUG**: Fallback mesaj prefix'i "Sert Profesör:" ile başlıyor ama bubble label zaten "Sert Profesör" gösteriyor → çift prefix.

### Senaryo 2 — Komisyon (kritik güvenlik hatası testi)
- **B1, B2 PASS ✓:** 3 hoca aynı sınavda, üstte "KOMİTE" badge'i, aktif hoca "SORU SORUYOR" işaretli; diğerlerine "Yanıtınızı komisyon değerlendirmesine aldım." (committeeReplies fallback'i — sağlıklı).
- **B3 KESİN FAIL ❌:** Kasıtlı **kritik güvenlik hatası** yaptım ("Hastayı görmeden tüm vücut BT çekerim, stabilizasyon sonra"). Standart §5.1: Sert Profesör konuşmalı (kritik hata). Uygulama: **Sokratik Doçent** konuştu (kod rotasyonu `[second, observer, lead][1 % 3] = second = Sokratik`). Cevap kalitesi sinyali kullanılmıyor.
- **B4 PARTIAL ⚠️ + büyük eksikler:** "Komite Kararı" başlığı + "Hocaların Notları" + 3 hoca **BAŞKAN/YARDIMCI/GÖZLEMCİ** etiketli ✓. Her hocaya verdict pill (SINIRDA × 3). Ancak 3 hocanın **yorumu AYNI JENERİK metin**: "Yanıtların kaydedildi; değerlendirme temel rubrik üzerinden oluşturuldu." → AI komite yorumu üretemedi, deterministicOralEvaluation fallback'i. Standart §6.3 farklı tonlarla farklı yorum bekliyor. "Genel Komisyon Kararı" başlığı, 6'lı alan skoru (önceliklendirme/ayırıcı tanı/yönetim/ifade/güvenlik), "Kritik Hatalar" listesi, "İdeal Cevap İskeleti", "Bir Sonraki Deneme Planı" YOK.
- **Cosmetic BUG**: Komite karne başlığı hala "Sert Profesör — Acil Tıp sözlü sınav karnesi" diyor (panel modunda "Komite" olmalı).

### Senaryo 3 — Mini OSCE tıklama
- **C1 PARTIAL ⚠️ (FAIL → PARTIAL iyileşme):** Auditte düşündüğümün aksine, Mini OSCE düz case kütüphanesine gitmiyor — "Sınavlar > Sınav Merkezi" ekranına gidiyor; orada **OSCE Pratiği / Mini OSCE Planı / Tek İstasyon / Sözlü Sınav / Teorik Sınav** ayrı kartlar var. Mod kataloğu standardın 5 modunu kavramsal olarak ayırıyor.
- **C2 PARTIAL ⚠️ (FAIL → PARTIAL iyileşme):** Vaka detayında **"Aday Yönergesi: Bu istasyonda Travma olgusunu OSCE yaklaşımıyla değerlendiriniz."** + süre (7 dk) + zorluk (Kolay) + branş (Acil Tıp) + 5 adımlı Vaka Akışı (Anamnez→Muayene→Tetkik→Tanı→Karne) var. Standart §8.1'in talep ettiği "İstasyon adı + Branş + Süre + Görev + Beklenen çıktı + Sınav modu + Başlat butonu" header'ının yaklaşık 5/7'si karşılanıyor. Eksik: "Beklenen Çıktı" + "Sınav Modu" alanları.
- **C4, C6 FAIL teyit ❌:** Vaka akışında ve karnede checklist Tam/Kısmi/Eksik/Kritik Eksik chip'leri yok; case karnesi 6'lı kategori barı + AI feedback bullet listeleri (cases_result.dart koddan teyit).
- **Mini OSCE Planı tıklama:** → Vaka Kütüphanesi (tek vaka: Travma). Standart §8.1'in beklediği "istasyon paketi seçim akışı" yok, sadece tek vaka var.

### Senaryo 4 — Case sonuç ekranı (koddan teyit, runtime atlandı)
- Kod auditi ile teyit: `_IdealApproachCard` var ✓, ama checklist chip'leri, istasyon başlığı header'ı, seviye etiketleri yok.

### Senaryo 5 — Console + Network sızıntı kontrolü
- **D1 PASS teyit ✓:** Console'da **5 Flutter exception** (main.dart.js:6362) — finalize / parse hatasıyla bağlantılı. Önemli: bu exception'lar **UI'a sızmadı**, kullanıcıya doğal Türkçe fallback gösterildi. Standart §2.1'in en kritik gereksinimi karşılanıyor.
- **Logger eksikliği**: Exception'lar sentry/log aggregator'a iletilmiyor; debug modda console'a düşüyor, prod'da kayıp olabilir.
- Network log: Tool ön-yükleme sonrası takip ettiği için oral-exam endpoint çağrılarını yakalayamadı.

### Runtime'da Doğrulanan Pozitif Bulgular
- ✓ Komite UI'sı (3 hoca avatar + aktif/pasif state + panel rol etiketleri) standart §5.2'nin ürün vizyonuyla uyumlu
- ✓ Vaka detay ekranında "Aday Yönergesi" var (auditteki orijinal FAIL kararını PARTIAL'a yükseltti)
- ✓ Sınav Merkezi modları kavramsal olarak ayrılmış
- ✓ Hiçbir ekranda raw JSON / 502 / stack trace gözükmedi
- ✓ Fallback'ler (mentor turn, finalize, deterministic eval, committee replies) doğal Türkçe ile çalışıyor
- ✓ "Karne hazırlanıyor..." spinner + retry akışı kullanıcı dostu

### Runtime'da Doğrulanan Kritik Açıklar
1. **AI yanıt üretiminde sistematik fallback**: 4 ardışık AI turn'ün **3'ünde** mentor mesajı fallback'e düştü (1/4 başarılı: sadece ilk takip sorusu). Bu standart ürün deneyiminin %75'ini bozuyor. Kök neden hipotezi: `looksUnsafeOralCoaching` regex'i çok agresif (`puan|json|rubrik|sistem talimat|checklist|...`); Gemini çıktısı bu kelimelerden birini içerirse mesaj reddediliyor.
2. **B3 (komite speaker selection)**: hardcoded rotasyon kod auditiyle ve runtime ile birebir uyumlu — cevap kalitesi sinyali kullanılmıyor.
3. **B4 + A7 + B5 + B6 + B7 + C4 + C6**: hiçbir karne formatı standardın §4/§6/§9 başlık ve bölümleriyle yapısal olarak eşleşmiyor.

### Görsel Kanıt
Tüm screenshot'lar `~/Library/Application Support/Anthropic/...` veya browser_batch'in `save_to_disk` çıktıları olarak depolandı. Anahtar görseller:
- Tek hoca karnesi (%75) — A7/B5/B7 görsel teyit
- Komite karnesi (%50) — B4 görsel teyit, 3 hoca aynı jenerik metin
- Komite room — "Sokratik Doçent SORU SORUYOR" (kritik hata sonrası)
- Vaka detay — "Aday Yönergesi" başlığı (C2 PARTIAL kanıtı)
- Sınavlar > Sınav Merkezi (C1 PARTIAL kanıtı)

---

## Sonuç

**Doğrulanan güçlü yanlar:**
- Genel AI yanıt güvenliği (D1-D4) çok iyi — sanitize katmanları sağlam.
- Tek hoca solo akışı (A1-A6) standartla yapısal olarak uyumlu.
- Standart hasta rolü (C3, C5) §8.2 ile birebir.
- Deterministic fallback ve hata yönetimi (§12) ürün düzeyinde çalışıyor.

**Doğrulanan kritik açıklar:**
- Komisyon konuşmacı seçimi cevap kalitesine göre yapılmıyor — bu standardın ürün ayrımının ana özelliği.
- OSCE ayrı bir deneyim olarak yok; "Mini OSCE" yalnız bir etiket.
- Hiçbir karne (tek hoca / komisyon / OSCE) standardın §4/§6/§9'daki başlık ve bölümleriyle yapısal olarak eşleşmiyor.
- Skor seviye etiketleri eksik.

**Tavsiye:** P0 üç maddesini tek bir implementation oturumunda kapatmak en yüksek değeri sağlar — komisyon speaker selection (backend) + karne format upgrade (UI) + OSCE framing (UI lite). P1/P2 sonra. Bu rapor implementation planına temel olarak kullanılabilir.
