# PRATICASE VIDEO QA FIX REPORT

## Kapsam ve Kanit

Bu rapor, kullanicinin 24 Mayis 2026 tarihinde paylastigi video-analiz QA
listesinin repo icinde kanitlanabilen kritik maddelerini kapsar. Videolar bu
oturumda dogrudan incelenmedi; sonuc, kod taramasi, widget testleri, release
buildleri ve salt-okunur self-hosted preflight bulgularina dayanir.

Canli Qlinik'e deploy, migration, secret degisikligi veya veri yazma islemi
yapilmadi. Qlinik ve PratiCase'in ortak Medasi cuzdan/kota sozlesmesi
korunarak, yalniz PratiCase'e ait Apple dogrulama katmani yerelde
hazirlandi.

## 1. Duzeltilen P0 Hatalar

- Magaza urun kartlari dar `ListTile.trailing` yerlesiminden esneyen dikey
  kart yapisina alindi. Baslik/aciklama kontrollu sariliyor, CTA metni
  ezmiyor ve buyuk yazi boyutu widget testiyle dogrulandi.
- Magaza ve premium akislarinda SQL/RLS/function hata ayrintilarinin
  kullaniciya aktarilmasi merkezi guvenli hata cevirimiyle engellendi.
- Sozlu sinavda parse edilemeyen `case_brief`, `mentor_message` veya ham JSON
  mesaj balonuna basilmiyor; Edge Function ve Dart repository katmaninda
  dogal Turkce fallback uygulaniyor.
- Sozlu sinav karne olusturma hatasinda `502`/provider metni yerine tekrar
  denenebilir, ogrenciye uygun karne mesaji gosteriliyor.
- OSCE sonuc karnesinde bos/teknik metinler temizlendi; ideal ozet basligi
  duzeltildi ve girilmeyen yonetim plani sifir basari gibi sunulmuyor.

## 2. Duzeltilen Layout / Responsive Sorunlari

- Magaza kartlari ve cuzdan degerleri kucuk genislik ve artirilmis text scale
  icin yeniden duzenlendi.
- Kritik kart ve aksiyon alanlarinda metnin CTA ile yatay olarak sikismasi
  azaltildi; uzun metinler kontrollu tasma/sarilma davranisi kullaniyor.
- `store product cards remain readable at large text scale` widget testi
  eklenip gecti.

Tum raporda listelenen her ekranin 1.0/1.2/1.4/1.6 ile cihaz uzerinde tek
tek manuel kabul testi bu turda tamamlanmis sayilmaz; bu, kalan release QA
kalemidir.

## 3. Duzeltilen Akis Sorunlari

- Teknik hata metinleri icin ortak kullanici mesaji katmani eklendi; ham
  exception, SQL izleri ve servis durum kodlari kritik akislarda yuzeye
  cikmiyor.
- Yonetim verisi olmadan sonuca geciste karne, eksik adimi anlasilir olarak
  bildiriyor.
- Anlamsiz veya klinik degerlendirmeye yetmeyecek kadar kisa sozlu sinav
  cevaplari icin dogal yonlendirme mesaji uygulandi.

## 4. Sozlu Sinav Duzeltmeleri

- Structured response parse basarisizliginda raw model cevabini basan yol
  kapatildi.
- UI katmanina JSON/metadata sizmasini engelleyen ikinci savunma eklendi.
- Bitirme/loading metni `Karne hazirlaniyor...` olarak profesyonel dile
  getirildi; finalize failure testi gecti.

## 5. Magaza / Abonelik Duzeltmeleri

- PratiCase StoreKit dogrulamasi Apple App Store Server API kutuphanesi ve
  Apple signed payload dogrulamasi ile yerelde uygulandi.
- PratiCase Apple secret adlari `PRATICASE_APP_STORE_*` altinda ayrildi;
  canlidaki Qlinik `APP_STORE_*` yapilandirmasi okunmuyor veya
  degistirilmiyor.
- `public.store_products` icindeki mevcut Qlinik urun kimliklerini degistirmek
  yerine `praticase.store_product_app_mappings` migration'i hazirlandi.
  PratiCase App Store urunleri bu harita ile ayni ortak kota urunlerine
  baglanacak.
- Salt-okunur canli sema kontrolu, ortak `public.store_products(code)`
  alaninin `UNIQUE` oldugunu dogruladi; mapping foreign key tasarimi mevcut
  ortak katalog kontratiyla uyumludur.
- Satin alma hakki verme islemi yeni tabloya dogrudan yazmak yerine mevcut
  ortak `grant_app_store_product` ve `sync_wallet_profile` RPC sozlesmelerine
  baglandi. Boylece Medasi kota/cuzdan davranisi ortak kalir.
- App Store Server Notifications V2 icin PratiCase satin alimlarini ayiran
  subscription link modeli ve dogrulanmis notification handler hazirlandi.
- Mevcut olmayan bir audit tablosuna best-effort yazma girisimi kaldirildi;
  sadece hassas ogrenci kimligi icermeyen ic olay logu birakildi.

## 6. Sonuc Karnesi Duzeltmeleri

- `Ideal Yasam Ozeti`/bos canli ozet gibi prototip algisi yaratan durumlar
  dogal karne diliyle degistirildi.
- Karne uretimi basarisizsa teknik neden yerine ogrencinin yanitlarinin
  kaydedildigini anlatan tekrar-deneme mesaji kullaniliyor.
- Yonetim plani tamamlanmadiysa skorun anlami acik bicimde belirtiliyor.

## 7. Mikrocopy Degisiklikleri

| Eski | Yeni |
|---|---|
| `AI Geri Bildirimleri` | `Klinik Geri Bildirim` |
| `Karne cikiyor...` | `Karne hazirlaniyor...` |
| `Canli Filtreler` | `Aktif Filtreler` |
| `Supabase Auth` | `Hesap Guvenligi` |
| Kullaniciya gorunen Qlinik soru bankasi ifadesi | `Medasi soru havuzu` odakli ifade |
| Ham SQL/RLS/HTTP/JSON hata metni | Isleme uygun dogal Turkce hata mesaji |
| `Ideal Yasam Ozeti` | `Ideal Yaklasim Ozeti` |

Qlinik adi entegrasyon ve ortak altyapi baglaminda kod/sozlesme tarafinda
korunur; PratiCase ogrencisine gereksiz teknik veya marka-karmasasi yaratacak
yuzey metni olarak basilmiyor.

## 8. Teknik Hata Yonetimi

- Merkezi user-facing error mapper ile magaza, vaka/karne, sozlu ve teorik
  sinav kritik yollarinda teknik servis ayrintisi gizlendi.
- PratiCase Apple function'i yalniz Apple tarafindan dogrulanmis signed
  transaction ile ortak hak verme RPC'sini calistiriyor.
- `.p8` dosyasi repo disinda tutuldu, dosya izni `600` yapildi ve `*.p8`
  Git ignore kapsamina alindi; anahtar icerigi yazdirilmadi.
- Canli self-hosted incelemesi salt okunurdu: ortak Qlinik urunleri ve RPC
  sozlesmeleri kanitlandi, degistirilmedi.

## 9. Test Sonuclari

| Dogrulama | Sonuc |
|---|---|
| `flutter analyze` | Gecti |
| `scripts/flutter_praticase.sh test` | Gecti, 28 test |
| Edge Function `deno check` | Gecti |
| `scripts/preflight_self_hosted.sh --app-store-key ...` | Gecti |
| `git diff --check` | Gecti |
| `scripts/build_praticase_apk.sh` | Gecti, release APK olustu |
| `scripts/flutter_praticase.sh build ios --release --no-codesign` | Gecti, `Runner.app` olustu |
| `scripts/flutter_praticase.sh build web --release` | Gecti |
| Yerel web gorsel kontrolu | Gecti: onboarding render edildi, console error yok |
| `scripts/preflight_self_hosted.sh --remote --app-store-key ...` | Kaldi: canliya alinmamis PratiCase konfig/deploy kalemleri var |

## 10. Kalan Riskler

- Canli ortamda `PRATICASE_APP_STORE_BUNDLE_ID`,
  `PRATICASE_APP_STORE_APP_ID`, `PRATICASE_APP_STORE_KEY_ID`,
  `PRATICASE_APP_STORE_ISSUER_ID` ve
  `PRATICASE_APP_STORE_PRIVATE_KEY_BASE64` henuz tanimli degil.
- Kullanici tarafindan verilen key dosyasinin anahtar ID'si biliniyor; Apple
  issuer ID, sayisal PratiCase App Store app ID ve gercek PratiCase IAP product
  ID'leri anahtardan turetilemez ve saglanmadan canli satin alma acilamaz.
- Yeni public Apple trust-anchor dosyasi, PratiCase store mapping migration'i
  ve copy hardening migration'i henuz canliya deploy edilmedi. Bu bilincli
  olarak Qlinik'i riske atmamak icin bekletildi.
- App Store Connect icinde PratiCase notification URL ve sandbox satin
  alma/yenileme/iade testleri, gerekli Apple bilgileri ve onayli deploy
  sonrasinda yapilmalidir.
- `flutter_tts` icin Swift Package Manager ve Android Kotlin Gradle Plugin
  gelecek Flutter surum uyarilari var; mevcut release buildlerini
  engellemedi.
- Video listesindeki tum ekranlarin cihaz ustu ayrintili accessibility ve
  klavye/manual regression turu henuz tamamlanmadi.

## 11. Benim Tekrar Test Etmem Gereken Akislar

- Magaza ve abonelik yonetimi: PratiCase sandbox satin alma, yenileme,
  iptal/iade notification'i ve ortak kota gorunumu.
- Vaka cozumu: anamnez, fizik muayene, tetkik, tani, yonetim ve sonuc
  karnesi uc uca cihaz testi.
- Sozlu sinav: malformed cevap, bitirme retry ve gercek canli karne donusu.
- Teorik sinav, profil, ayarlar ve yardim ekranlarinin kucuk iPhone/text
  scale/klavye senaryolari.
