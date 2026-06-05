# PratiCase Google Play Release Checklist

Bu akış Android içindir. `ios/` ve `web/` dosyalarına release hazırlığında
dokunulmaz.

## Play Billing

Android dijital hak satışları Google Play Billing üzerinden çalışır. Web
Medasi Pay checkout kullanmaya devam eder; Android uygulama içindeki paket
seçimleri dış ödeme sayfasına gitmez.

Edge Function secret'ları:

```bash
PRATICASE_GOOGLE_PLAY_PACKAGE_NAME=com.medasi.praticase
PRATICASE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64=<base64 service account json>
```

Alternatif olarak JSON ham değerle verilebilir:

```bash
PRATICASE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON=<service account json>
```

Service account Google Play Console'da bu uygulamaya erişmeli ve Android
Publisher API satın alma sorgularını okuyabilmelidir.

## Ürün Eşlemesi

Google Play Console'daki ürün/abonelik ID'lerini PratiCase mapping tablosuna
gir. Ortak `public.store_products` tablosunu değiştirme.

```sql
insert into praticase.store_product_app_mappings(
  product_code,
  app_store_product_id,
  google_play_product_id
) values
  ('weekly_subscription', '<ios_product_id>', '<google_play_product_id>'),
  ('monthly_subscription', '<ios_product_id>', '<google_play_product_id>')
on conflict (product_code) do update
set google_play_product_id = excluded.google_play_product_id,
    is_active = true,
    updated_at = now();
```

Android katalog çağrısı `google_play_product_id` değerini native mağaza ürün
kimliği olarak döndürür. iOS aynı tabloda `app_store_product_id` kullanmaya
devam eder.

## Release Build

```bash
scripts/flutter_praticase.sh analyze
scripts/flutter_praticase.sh test
scripts/build-play-store.sh
git diff -- ios/ web/
```

Signed AAB çıktısı:

```txt
build/app/outputs/bundle/release/app-release.aab
~/Desktop/PratiCase-<version>-playstore.aab
```

Script `android/key.properties` veya release keystore eksikse durur; debug
imzalı paket Play Store'a hazır kabul edilmez.

## Play Console Kontrolü

- App bundle: `~/Desktop/PratiCase-<version>-playstore.aab`
- Package name: `com.medasi.praticase`
- Digital goods: Google Play Billing aktif
- Target SDK: Flutter/Android Gradle config ile güncel hedef SDK kullanılır
- Data safety: Supabase Auth, mikrofon, satın alma ve cüzdan kullanımları
  beyan edilir
- Mikrofon izni: OSCE/sözlü sınav sesli görüşme özelliği için açıklanır
- Service account secret'ı Edge Function runtime'dadır; Flutter'a veya Git'e
  secret girilmez
