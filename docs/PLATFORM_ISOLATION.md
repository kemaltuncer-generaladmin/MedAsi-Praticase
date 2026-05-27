# Platform İzolasyon Kuralları (Android ↔ iOS)

Bu dokümanın amacı: **Android tarafında yapılan değişikliklerin iOS akışını hiçbir şekilde etkilememesini** garanti etmek. Xcode'da yapılan değişiklikler de Android tarafına bulaşmaz.

> **Geçerli kapsam:** PratiCase — Flutter tek kod tabanı, iki dağıtım kanalı.
> iOS App Store'da yayında, Android Play Store dışı APK + alternatif ödeme akışına geçti.

---

## 1. Kapsam ve Sözleşme

| Taraf | Dağıtım | Ödeme | Değiştiren |
|---|---|---|---|
| **iOS** | App Store | `in_app_purchase` (StoreKit) | Sadece Xcode + `ios/` klasörü |
| **Android** | praticase.medasi.com.tr/download (APK) | iyzico / IBAN + aktivasyon kodu | Sadece `android/` + Dart Android branch |

İki tarafın dosya dünyaları **kesinlikle ayrık**. Aşağıdaki tablo bağlayıcıdır.

---

## 2. Dosya Bölgeleri

### 2.1 iOS Bölgesi — Android iş akışı sırasında **DOKUNULMAZ**

```
ios/                                  # tüm klasör
ios/Podfile
ios/Podfile.lock
ios/Runner.xcodeproj/**
ios/Runner.xcworkspace/**
ios/Runner/Info.plist
ios/Runner/AppDelegate.swift
ios/Runner/Runner-Bridging-Header.h
ios/Runner/*.entitlements
ios/Runner/Assets.xcassets/**
ios/Runner/Base.lproj/**
ios/Configuration.storekit
ios/fastlane/**
```

### 2.2 Android Bölgesi — iOS iş akışı sırasında **DOKUNULMAZ**

```
android/                              # tüm klasör
android/app/build.gradle.kts
android/app/src/**/AndroidManifest.xml
android/key.properties
android/gradle/**
android/gradlew, gradlew.bat
```

### 2.3 Ortak Bölge — dikkatli kullan

```
lib/                                  # platform guard zorunlu
pubspec.yaml                          # paket eklemek iki tarafı da etkiler
pubspec.lock
analysis_options.yaml
web/                                  # web build'i ayrı kanal
supabase/                             # backend ortak
```

`lib/` altındaki herhangi bir kod **iki platformda da derlenir**. Platform-spesifik davranış için Bölüm 3'teki kuralları uygula.

---

## 3. Dart Kodunda Platform Ayrımı

### 3.1 Runtime guard (varsayılan yöntem)

```dart
import 'dart:io' show Platform;

if (Platform.isIOS) {
  // iOS-only kod
} else if (Platform.isAndroid) {
  // Android-only kod
}
```

- iOS build çalışırken `Platform.isAndroid` her zaman `false` → Android dalı çalışmaz.
- Yine de Dart tarafı tüm dalları **derler**; sadece native paket çağrısı varsa Bölüm 3.2'ye geç.

### 3.2 Conditional import (native paket gerekirse)

```dart
// payment_service.dart
export 'payment_service_stub.dart'
  if (dart.library.io) 'payment_service_io.dart';
```

veya platform-spesifik dosya:

```
lib/src/payment/android_purchase.dart   # sadece Android kod yolundan import edilir
lib/src/payment/ios_purchase.dart       # sadece iOS kod yolundan import edilir
lib/src/payment/purchase_service.dart   # router, ikisini de bilir, Platform.is* ile dağıtır
```

### 3.3 Dosya isimlendirme kuralı

| Önek | Anlam |
|---|---|
| `android_*.dart`, `*_android.dart` | Sadece Android branch'inde çağrılmalı |
| `ios_*.dart`, `*_ios.dart` | Sadece iOS branch'inde çağrılmalı |
| Önek yok | Platform-bağımsız (her iki tarafta çalışır) |

Yeni `android_*.dart` dosyaları **kesinlikle** iOS'ta import edilmez. iOS'ta sadece `Platform.isAndroid` `false` döner ve dosya çağrılmaz; ancak `import` satırı tüm platformda derlenir, bu yüzden o dosyada `dart:io` veya Android-only native paket varsa **iOS derlemesini kırabilir** → Bölüm 3.2'deki conditional import şart.

---

## 4. UI / Anti-Steering Kuralı (Apple)

iOS uygulamasında dış ödeme yöntemine **yönlendirme yapılamaz** (Apple anti-steering kuralı). Bu yüzden:

```dart
if (Platform.isAndroid) {
  // "IBAN ile öde", "Web'den indir", "Aktivasyon kodu gir" gibi butonlar
  IbanPaymentButton(),
  ActivationCodeButton(),
}
// iOS build'inde bu blok hiç render edilmez
```

iOS build'i Apple incelemesine girdiğinde Android-only butonları **görmez**.

---

## 5. pubspec.yaml — Paket Ekleme Kuralı

| Paket türü | Yapılacak |
|---|---|
| Hem iOS hem Android destekli (örn. `url_launcher`) | Direkt ekle |
| Sadece Android (örn. iyzico Android SDK) | Conditional import ile sar, iOS derlemesinde stub döndür |
| Sadece iOS (örn. `cupertino_*`) | iOS branch'inde kullan |

`pubspec.yaml`'a paket eklemeden önce iOS Podfile'ı kırıp kırmadığını test et:
```sh
flutter pub get
flutter build ios --release --no-codesign
```

---

## 6. CI / Doğrulama

Her Android tarafı değişikliğinden sonra **iOS build'inin hâlâ ayağa kalktığını** ispatla:

```sh
# 1. iOS klasörüne fiziksel dokunuş olmadı mı?
git diff main..HEAD -- ios/
# Çıktı boş olmalı.

# 2. Podfile.lock değişti mi?
git diff main..HEAD -- ios/Podfile.lock
# Çıktı boş olmalı.

# 3. iOS hâlâ derleniyor mu?
flutter build ios --release --no-codesign

# 4. Android tarafı çalışıyor mu?
flutter build apk --release
flutter build appbundle --release
```

Bu dört adımı geçmeyen değişiklik **merge edilmez**.

---

## 7. Xcode'da Manuel Değişiklik Yaparken

Sen Xcode'da capability/sertifika/plist düzenlemesi yaptığında:

1. **Yalnızca** `ios/` altındaki dosyalar değişmeli (git diff ile teyit et)
2. `pubspec.yaml` veya `lib/` değişmemeli
3. Değişikliği commit ederken `ios:` prefix kullan → otomasyonlar Android tarafına atlamaz

```
ios: enable HealthKit capability
ios: rotate provisioning profile
ios: bump CFBundleVersion to 247
```

---

## 8. Branch / Commit Adı Sözleşmesi

| Prefix | Bölge |
|---|---|
| `ios:` veya `feat(ios):` | Sadece `ios/` etkilenmeli |
| `android:` veya `feat(android):` | Sadece `android/` + `android_*.dart` etkilenmeli |
| `shared:` | Ortak bölge — extra dikkat, hem iOS hem Android build'i çalıştır |

---

## 9. Yasak Liste (Bunları Yapma)

- ❌ `ios/Runner/Info.plist`'i Android iş akışı sırasında düzenlemek
- ❌ `in_app_purchase` paketini pubspec'ten kaldırmak (iOS hâlâ kullanıyor)
- ❌ iOS build'inde `IbanPaymentButton` / "web'den al" linki göstermek (anti-steering ihlali)
- ❌ Platform guard'sız `flutter_inappwebview` gibi Android-only paket çağrısı yazmak
- ❌ `ios/Podfile.lock`'u manuel düzenlemek (Xcode yeniden oluşturur)

---

## 10. Acil Geri Alma

Eğer Android değişikliği yanlışlıkla iOS'u kırarsa:

```sh
# iOS klasörünü main'e geri al, Android'i tut
git checkout main -- ios/ pubspec.lock
flutter pub get
flutter build ios --release --no-codesign
```

Sonra Android değişikliğini conditional import'la sarmalayıp tekrar uygula.

---

**Son güncelleme:** 27 Mayıs 2026
**Geçerlilik:** Android'in Play Store dışı dağıtıma alındığı sürece. Play Store'a geri dönüldüğünde Bölüm 1 ve Bölüm 4 revize edilir.
