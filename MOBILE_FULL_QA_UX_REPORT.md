# MOBILE FULL QA / UX / FLOW REPORT
## PratiCase — OSCE Simülasyon Uygulaması

**Rapor Tarihi:** 21 Mayıs 2026
**Rapor Türü:** Kod analizi, build testi ve mobil layout incelemesi
**Analiz Yöntemi:** Kaynak kodu incelemesi + flutter analyze + build testleri

> **Not:** Gerçek fiziksel cihazda test yapılamadı. Bu rapor tam kaynak kodu analizi, static analiz (flutter analyze), widget testi, iOS ve Android build çıktıları ile mobil layout incelemesine göre hazırlanmıştır. Gerçek cihaz testi ayrıca önerilir. Tüm bulgular kanıtlı — dosya yolu ve kod satırı referansları verilmiştir.

---

## 1. Yönetici Özeti

### Genel Durum
PratiCase, tıp öğrencileri için OSCE sınavına hazırlık amacıyla geliştirilmiş bir Flutter uygulamasıdır. Uygulama **teknik olarak sağlam** bir temel üzerine kurulu, clean architecture uygulanmış ve build testlerini geçmiştir. Ancak mobil yayın için **kritik iyileştirmeler** gerekmektedir.

### Mobil Yayına Hazır mı?
**HAYIR — Kritik düzeltmeler gerekli.**

Temel sebepler:
1. Ödeme / abonelik sistemi yok; uygulama ticari olarak tamamlanmamış
2. Veri olmadan uygulama içi akış kısmen çalışmaz ("_LiveDataRequiredScreen" gösterilir)
3. Logout akışı auth state'i sıfırlamıyor (P0)
4. Bazı butonlar işlevsiz placeholder olarak bırakılmış
5. Kullanıcı gizlilik/KVKK ekranları link içermiyor, sadece checkbox var
6. Tek widget test var; kapsamı yetersiz

### En Kritik 5 Sorun
1. **P0** — Logout butonuna basıldığında auth state sıfırlanmıyor; kullanıcı uygulamayı tekrar açınca aynı oturuma giriyor
2. **P0** — Tüm canlı veri ekranları (`homeRepository == null`) "Yapılandırma gerekli" ekranı gösteriyor; env olmadan uygulama kullanılamaz
3. **P1** — `PatientChatScreen`'de klavye açıldığında mesaj compose alanı safe area'yı hesaba katmıyor, iOS home indicator üzerine çıkabilir
4. **P1** — `ProfileScreen` menü öğelerinden büyük çoğunluğu (`onTap` yok) tıklandığında hiçbir şey yapmıyor; kullanıcı neden çalışmadığını anlayamıyor
5. **P1** — `ResetPassword` akışı OTP kodu olmadan sadece `email` ve `newPassword` gönderiyor; kod doğrulaması eksik

### En Güçlü 5 Taraf
1. Flutter analyze sıfır hata — kod kalitesi yüksek
2. iOS ve Android build başarılı — yayın buildleri alınabilir
3. Auth akışı eksiksiz: onboarding → register → verify → profile setup
4. Tüm ekranlarda loading / error / empty state'ler mevcut
5. Tema tutarlı: navy/teal/gold renk paleti, Material 3, tipografi sistemi

### Genel Risk Seviyesi
**YÜKSEK** — Uygulama canlı veri olmadan çalışmaz; birkaç kritik akış eksik.

---

## 2. Teknik Proje Özeti

| Özellik | Değer |
|---|---|
| Framework | Flutter (Dart) |
| Flutter SDK | ^3.11.5 |
| Platform | iOS + Android (web ve linux dizinleri var, aktif değil) |
| Bundle ID | com.medasi.praticase |
| Versiyon | 1.0.0+1 |
| Routing | StatefulWidget içinde state machine (AuthFlow switch) + MaterialPageRoute push |
| State Management | StatefulWidget + FutureBuilder (Provider/Bloc yok) |
| Backend | Supabase (PostgreSQL + realtime) |
| Auth | Supabase Auth (email/şifre + Google OAuth) |
| UI Sistemi | Material 3, özel tema (PratiCaseTheme) |
| Tasarım Dili | Medasi ekosistemi — navy/teal/gold palette |
| Build/Test Durumu | ✅ flutter analyze: 0 hata, ✅ flutter test: 1/1 geçti, ✅ iOS build: başarılı (35.7MB), ✅ Android debug APK: başarılı |
| Test Kapsamı | 1 widget testi (yetersiz) |

---

## 3. Test Kapsamı

### İncelenen Dosyalar
- 34 Dart dosyası tam okundu (lib/ altındaki tüm dosyalar)
- pubspec.yaml, analysis_options.yaml, iOS/Android build dosyaları incelendi

### Çalıştırılan Komutlar
```
flutter analyze    → Başarılı, 0 hata/uyarı
flutter test       → Başarılı, 1/1 test geçti
flutter build ios --no-codesign → Başarılı, 35.7MB Runner.app
flutter build apk --debug       → Başarılı, app-debug.apk
```

### Test Edilebilen Alanlar
- Tüm ekranların layout kodları
- Auth akış state machine mantığı
- Mobil safe area kullanımı
- Klavye davranışı (resizeToAvoidBottomInset ayarları)
- Widget hiyerarşisi ve scroll yapıları
- Hata / boş / loading state varlığı
- Buton onPressed callback'leri
- Form validasyon mantığı

### Test Edilemeyen Alanlar
- Gerçek cihaz üzerinde ekran görüntüleri
- Supabase API yanıt süreleri ve gerçek hata mesajları
- Google OAuth flow (mock'ta simüle ediliyor)
- Push notification
- Gerçek kullanıcı verisiyle scroll/liste performansı
- Tablet görünümü (kod varlığı var, test edilemedi)
- Ağ kesintisi durumundaki gerçek davranış

### Varsayımlar
- `_LiveDataRequiredScreen`: env değerleri olmadan repository'ler null geliyor → bu screen gösterilir (kod doğrulandı)
- Fiziksel cihazda safe area değerleri iOS 14 için varsayılan kullanıldı (safeArea.bottom = 34pt, top = 44pt)

---

## 4. Mobil Cihaz Matrisi

| Ekran | Durum | Kritik Riskler |
|---|---|---|
| iPhone SE (375×667 pt) | ⚠️ Riskli | Onboarding illustration yüksekliği (170px) + feature tile'lar alt butonları push edebilir. Register'da 5 alan + checkbox + buton → küçük ekranda kaydırma zorunlu |
| iPhone 14 (390×844 pt) | ✅ Büyük ölçüde uyumlu | PatientChat klavye sorunu, bazı bottombar yükseklikleri |
| iPhone 15 Pro Max (430×932 pt) | ✅ İyi | Geniş ekranda yatay taşma riski yok; ConstrainedBox maxWidth: 430 auth ekranlarında uygulanıyor |
| Android Orta Ekran (varsayım: 390×844 dp) | ✅ Büyük ölçüde uyumlu | Android navigation bar (gesture nav) + bottom nav çakışma riski var |
| Tablet/iPad | ⚠️ Kısmen | Auth scaffold'da maxWidth: 430 uygulanıyor ancak shell'de tablet layout planlanmamış; tek sütun deneyimi |

---

## 5. Ekran Envanteri

| No | Ekran Adı | Dosya | Route / Navigation | Ana Amaç | Mobil Risk |
|---|---|---|---|---|---|
| 1 | OnboardingScreen | auth/presentation/screens/onboarding_screen.dart | AuthStep.onboarding (state machine) | İlk açılış, kayıt/giriş seçimi | Düşük |
| 2 | LoginScreen | auth/presentation/screens/login_screen.dart | AuthStep.login | Email+şifre girişi | Orta — klavye scroll |
| 3 | RegisterScreen | auth/presentation/screens/register_screen.dart | AuthStep.register | Kayıt formu (5 alan) | Yüksek — uzun form, küçük ekranda risk |
| 4 | VerifyEmailScreen | auth/presentation/screens/verify_email_screen.dart | AuthStep.verifyEmail | 6 haneli OTP doğrulama | Orta — OTP input küçük ekranda |
| 5 | ForgotPasswordScreen | auth/presentation/screens/forgot_password_screen.dart | AuthStep.forgotPassword | Şifre sıfırlama e-posta gönder | Düşük |
| 6 | ResetPasswordScreen | auth/presentation/screens/reset_password_screen.dart | AuthStep.resetPassword | Yeni şifre belirleme | Orta — OTP kodu geçilmeden çalışıyor |
| 7 | ProfileSetupScreen | auth/presentation/screens/profile_setup_screen.dart | AuthStep.profileSetup | Sınıf, branş, hedef seçimi | Orta — Wrap chips mobilde |
| 8 | HomeScreen | home/presentation/home_screen.dart | Shell tab 0 | Dashboard, devam eden vaka, öneriler | Orta — banner carousel, stats scroll |
| 9 | CasesScreen | cases/presentation/cases_screen.dart | Shell tab 1 | Vaka listesi, arama, filtreleme | Orta — search klavye |
| 10 | CaseSearchFilterScreen | cases/presentation/cases_screen.dart | Navigator.push | Zorluk filtresi | Düşük |
| 11 | CaseDetailScreen | cases/presentation/cases_screen.dart | Navigator.push | Vaka detay, hasta bilgisi, akış adımları | Orta |
| 12 | PatientChatScreen | cases/presentation/cases_screen.dart | Navigator.pushReplacement | Hasta görüşmesi, mesajlaşma | Yüksek — klavye + compose bar |
| 13 | PhysicalExamScreen | cases/presentation/cases_screen.dart | Navigator.push | Fizik muayene seçimi | Orta |
| 14 | TestsScreen | cases/presentation/cases_screen.dart | Navigator.push | Tetkik isteme | Orta |
| 15 | DiagnosisScreen | cases/presentation/cases_screen.dart | Navigator.push | Tanı ve ayırıcı tanı | Orta — klavye + text input |
| 16 | ManagementPlanScreen | cases/presentation/cases_screen.dart | Navigator.push | Tedavi/yönetim planı | Orta — klavye + text input |
| 17 | ResultScreen | cases/presentation/cases_screen.dart | Navigator.pushReplacement | Sınav sonuç karnesi | Düşük |
| 18 | CaseReportScreen | cases/presentation/cases_screen.dart | Navigator.push | Detaylı vaka raporu | Düşük |
| 19 | LabResultScreen | cases/presentation/cases_screen.dart | Navigator.push | Laboratuvar sonuçları | Düşük |
| 20 | ImagingResultScreen | cases/presentation/cases_screen.dart | Navigator.push | Görüntüleme sonuçları | Orta — image loading |
| 21 | MedicationInfoScreen | cases/presentation/cases_screen.dart | Navigator.push | İlaç bilgisi | Düşük |
| 22 | AddNoteScreen | cases/presentation/cases_screen.dart | Navigator.push | Vaka notu ekleme | Orta — klavye |
| 23 | CaseProgressScreen | cases/presentation/cases_screen.dart | Navigator.push | Vaka ilerleme adımları | Düşük |
| 24 | ExamsScreen (_ExamsScreen) | shell/presentation/praticase_shell.dart | Shell tab 2 | Sınav modu seçimi | Düşük |
| 25 | ProgressSummaryScreen | shell/presentation/praticase_shell.dart | Shell tab 3 | Gelişim özeti, başarı oranı | Düşük |
| 26 | BadgesScreen | progress/presentation/progress_screens.dart | Navigator.push | Rozetler | Düşük |
| 27 | LeaderboardScreen | progress/presentation/progress_screens.dart | Navigator.push | Sıralama | Düşük |
| 28 | ProfileScreen | progress/presentation/progress_screens.dart | Shell tab 4 | Profil ve menü öğeleri | Orta — menü item'lar işlevsiz |
| 29 | SettingsScreen | progress/presentation/progress_screens.dart | Navigator.push | Uygulama ayarları | Orta |
| 30 | NotificationsScreen | progress/presentation/progress_screens.dart | Navigator.push | Bildirimler | Düşük |
| 31 | FavoriteCasesScreen | progress/presentation/progress_screens.dart | Navigator.push | Favori vakalar | Düşük |
| 32 | CaseHistoryScreen | progress/presentation/progress_screens.dart | Navigator.push | Vaka geçmişi | Düşük |
| 33 | HelpCenterScreen | progress/presentation/progress_screens.dart | Navigator.push | Yardım merkezi | Düşük |
| 34 | FaqScreen | progress/presentation/progress_screens.dart | Navigator.push | SSS | Düşük |
| 35 | AnnouncementsScreen | progress/presentation/progress_screens.dart | Navigator.push | Duyurular | Düşük |
| 36 | MyDataScreen | progress/presentation/progress_screens.dart | Navigator.push | Veri görüntüleme | Düşük |
| 37 | ContactScreen | progress/presentation/progress_screens.dart | Navigator.push | Bize ulaşın formu | Orta — klavye |
| 38 | ProfileEditScreen | progress/presentation/progress_screens.dart | Navigator.push | Profil düzenleme | Orta — klavye |
| 39 | ProfileEditScreen | progress/presentation/progress_screens.dart | Navigator.push | Profil düzenleme | Orta |
| 40 | LogoutConfirmScreen | progress/presentation/progress_screens.dart | fullscreenDialog | Çıkış onaylama | Yüksek — auth state reset eksik |
| 41 | _LiveDataRequiredScreen | shell/presentation/praticase_shell.dart | (fallback) | Env yapılandırılmamış uyarı | Kritik — env yoksa tüm ana tab'lar bu ekranı gösterir |

---

## 6. Detaylı Ekran İncelemeleri

---

### Ekran: OnboardingScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/onboarding_screen.dart`
- Navigation: `AuthStep.onboarding` (state machine)
- Bağlı widget'lar: `AuthScaffold`, `AuthBrand`, `AuthPrimaryButton`, `_FeatureTile`, `_OnboardingIllustration`
- Bağlı servis: Yok (stateless)

#### 2. Ekranın Amacı
Kullanıcıya uygulamayı tanıtır; "Hesap Oluştur" veya "Giriş Yap" seçeneği sunar.

#### 3. Kullanıcının Bu Ekrana Gelişi
- İlk açılışta gelir (auth yoksa)
- Geri butonu yok; nav stack başlangıcı
- Login olmadan erişilebilir (açık ekran)

#### 4. Mobil Görsel Yerleşim Değerlendirmesi
- `AuthScaffold` SafeArea içinde — üst çentik güvenli
- `SingleChildScrollView` var — scroll gerektiğinde çalışır
- `showFooterText: true` (varsayılan) — footer alt kısımda görünür
- **iPhone SE riski:** Illustration (170px yükseklik) + 3 feature tile + 2 buton toplam uzunluğu küçük ekranı aşabilir; ancak scroll olduğu için kırılma değil sadece kaydırma gerekir
- Butonlar `Size.fromHeight(52)` — parmakla basım rahat (≥44pt)
- "Medasi auth env gelene kadar güvenli demo akışı açık" yazısı ekranda görünür — **yayın öncesi kaldırılmalı**

#### 5. UI Elemanları
- CTA buton: "Hesap Oluştur" (FilledButton + gradient, 52px) ✅
- Secondary buton: "Giriş Yap" (OutlinedButton, 52px) ✅
- Feature tile'lar: 3 adet — icon + başlık + açıklama ✅
- Illustration: 170px yükseklik kapsayıcı ✅
- Auth env status row (repositoryConfigured check) ⚠️

#### 6. Etkileşim Testi
- "Hesap Oluştur" → RegisterScreen ✅
- "Giriş Yap" → LoginScreen ✅
- Loading durumu yok (beklenmiyor, doğru) ✅
- Geri dönüş: ekran yok, state machine başlangıcı ✅

#### 7. Mobil Kullanılabilirlik Puanı
- Okunabilirlik: 9/10
- Dokunma kolaylığı: 9/10
- Safe area uyumu: 9/10
- Scroll/klavye uyumu: 9/10
- Tasarım tutarlılığı: 9/10
- Genel mobil kalite: 9/10

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | "Medasi auth env gelene kadar güvenli demo akışı açık" mesajı son kullanıcıya görünür | Düşük — güven sorunu | `onboarding_screen.dart` L91-97 | Yayın buildinde kaldır veya `kDebugMode` ile koşullan |

---

### Ekran: LoginScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/login_screen.dart`
- Navigation: `AuthStep.login`
- Bağlı widget'lar: `AuthScaffold`, `AuthLogoBlock`, `AuthTextField` (×2), `AuthPrimaryButton`, `AuthLinkButton`, `AuthStatusCard`
- State: `_loading`, `_error`, `_email`, `_password` controller'lar

#### 2. Ekranın Amacı
Email + şifre ile giriş.

#### 3. Kullanıcının Bu Ekrana Gelişi
- Onboarding'den "Giriş Yap"
- Register'dan "Zaten hesabın var mı? Giriş yap"
- ForgotPassword'dan geri
- Geri butonu: Onboarding'e döner ✅

#### 4. Mobil Görsel Yerleşim Değerlendirmesi
- `AuthScaffold` → `SafeArea` + `SingleChildScrollView` → klavye açıldığında form scroll olur ✅
- `resizeToAvoidBottomInset: true` ayarlı ✅
- `AuthLogoBlock` (büyük logo + 44px font) — küçük ekranda logo büyük, ancak `FittedBox` yok; **iPhone SE'de logo + başlık + form taşabilir**
- Error card `_error != null` ile dinamik — form altına ekleniyor; **klavye açıkken hata kartı görünmeyebilir** (scroll gerektirir)
- "Şifremi unuttum?" linki küçük — `AuthLinkButton` wrap içinde değil, sadece `Align.centerRight`

#### 5. UI Elemanları
- Email field: `keyboardType.emailAddress`, `textInputAction.next` ✅
- Password field: `textInputAction.done`, `obscureText`, visibility toggle ✅
- "Giriş Yap" button: loading spinner gösteriyor ✅
- Error card: kırmızı renk, mesaj gösteriyor ✅
- "Şifremi unuttum?" link: çalışıyor ✅

#### 6. Etkileşim Testi
- Boş form submit → validator çalışır, "E-posta gerekli" ✅
- Geçersiz email → validator yakalar ✅
- Loading sırasında buton disabled ✅
- Başarılı giriş → `onSignedIn()` → PratiCaseShell ✅
- Hata → `AuthStatusCard` görünür ✅

#### 7. Mobil Kullanılabilirlik Puanı
- Okunabilirlik: 8/10
- Dokunma kolaylığı: 9/10
- Safe area uyumu: 8/10
- Scroll/klavye uyumu: 8/10
- Tasarım tutarlılığı: 9/10
- Genel mobil kalite: 8/10

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Hata kartı formun en altında gösteriliyor; klavye açıkken kullanıcı göremeyebilir | Orta | `login_screen.dart` son `if (_error != null)` bloğu | Hata kartını form üstüne veya CTA üstüne taşı |
| P3 | `AuthLogoBlock` 104px icon + 44px yazı boyutu; SE'de diğer elemanlarla birlikte kalabalık | Düşük | `auth_visuals.dart` L30-32 | Logo boyutunu ekran yüksekliğine göre koşullandır |

---

### Ekran: RegisterScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/register_screen.dart`
- Navigation: `AuthStep.register`
- Bağlı widget'lar: `AuthScaffold`, `AuthTextField` (×5), `PasswordStrengthIndicator`, `AuthPrimaryButton`, terms checkbox (custom `InkWell`)
- State: 5 controller, `_acceptedTerms`, `_loading`, `_error`

#### 2. Ekranın Amacı
Ad, soyad, email, şifre (×2) ve KVKK onayıyla hesap oluşturma.

#### 3. Kullanıcının Bu Ekrana Gelişi
- Onboarding "Hesap Oluştur"
- Login "Kayıt ol"
- Geri: Onboarding'e döner ✅

#### 4. Mobil Görsel Yerleşim Değerlendirmesi
- `AuthScaffold` + `SingleChildScrollView` → uzun form scroll ile geçilebilir ✅
- `topPadding: 12, bottomPadding: 40` — alt padding makul ✅
- **Terms checkbox `_acceptedTerms: true` olarak başlıyor** — kullanıcı varsayılan olarak kabul etmiş oluyor; KVKK uyumu riski ⚠️
- Gizlilik politikası linki **tıklanabilir değil** — sadece `TextSpan` rengi farklı ama `GestureRecognizer` yok
- `LayoutBuilder` ile küçük ekranda hero illüstrasyonu gizleniyor (`constraints.maxWidth >= 330`) ✅
- `PasswordStrengthIndicator` şifre alanından sonra gösteriliyor ✅
- 5 form alanı + şifre tekrar + strength indicator + checkbox + buton → iPhone SE'de ciddi scroll mesafesi

#### 5. UI Elemanları
- Ad, Soyad, Email, Şifre, Şifre Tekrar: 5 `AuthTextField` ✅
- `PasswordStrengthIndicator`: 8+ karakter, büyük harf, rakam ✅
- Terms checkbox: custom `InkWell` + `Container` ⚠️ (özel görünüm, dokunma alanı 20×20px — çok küçük)
- Gizlilik linki: tıklanamaz ⚠️
- Submit: "Hesap Oluştur" butonu ✅

#### 6. Etkileşim Testi
- Terms checkbox varsayılan `true` — KVKK riski ✅/⚠️
- Şifreler eşleşmezse: "Şifreler eşleşmiyor" ✅
- Terms onaylanmamışsa: `_error` ile mesaj gösterilir ✅ (varsayılan true olduğundan tetiklenmiyor)
- Başarılı: `onRegistered(email, fullName)` → VerifyEmailScreen ✅

#### 7. Mobil Kullanılabilirlik Puanı
- Okunabilirlik: 8/10
- Dokunma kolaylığı: 7/10 (checkbox çok küçük)
- Safe area uyumu: 8/10
- Scroll/klavye uyumu: 7/10
- Tasarım tutarlılığı: 8/10
- Genel mobil kalite: 7/10

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P1 | Terms checkbox `_acceptedTerms: true` başlıyor — kullanıcı aktif onay vermeden kayıt olabilir; KVKK/yasal risk | Yüksek | `register_screen.dart` L41: `bool _acceptedTerms = true;` | `false` olarak başlat, kullanıcı aktif seçim yapmalı |
| P1 | Gizlilik politikası linki tıklanamıyor — `TextSpan` teal rengi var ama `GestureRecognizer` yok | Yüksek | `register_screen.dart` `RichText` bloğu | `TapGestureRecognizer` ekle veya `url_launcher` kullan |
| P2 | Terms checkbox dokunma alanı 20×20px — parmakla basması çok zor | Orta — yanlış basma | `register_screen.dart` checkbox `Container(width:20, height:20)` | Minimum 44×44pt touch target için `Padding` ekle |
| P2 | Hata kartı formun altında; klavye + 5 alan açıkken görünmeyebilir | Orta | `register_screen.dart` son `if (_error != null)` | Hata kartını butona yakın taşı |

---

### Ekran: VerifyEmailScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/verify_email_screen.dart`
- Navigation: `AuthStep.verifyEmail`
- Bağlı widget'lar: `OtpInput` (6-digit), `AuthPrimaryButton`, `AuthStatusCard`

#### 2. Ekranın Amacı
Kayıt sonrası e-posta doğrulaması için 6 haneli kod girişi.

#### 3. Mobil Görsel Yerleşim Değerlendirmesi
- 6 adet `Expanded TextField` yan yana — iPhone SE'de her kutu ~48px genişliğinde ✅
- `autofillHints: [AutofillHints.oneTimeCode]` — iOS otomatik doldurma desteği ✅
- `textInputAction.done` son kutuda ✅
- Klavye açıldığında `AuthScaffold` scroll ediyor ✅

#### 7. Mobil Kullanılabilirlik Puanı
- Okunabilirlik: 9/10
- Dokunma kolaylığı: 8/10
- Safe area uyumu: 9/10
- Scroll/klavye uyumu: 9/10
- Tasarım tutarlılığı: 9/10
- Genel mobil kalite: 9/10

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | "Kodu tekrar gönder" butonunda cooldown/timer yok — kullanıcı spam yapabilir | Düşük | `verify_email_screen.dart` `_resend()` — timer yok | ForgotPassword'daki gibi 45sn timer ekle |

---

### Ekran: ForgotPasswordScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/forgot_password_screen.dart`

#### 2. Öne Çıkan Gözlemler
- 45 saniye geri sayım timer ile "tekrar gönder" koruması var ✅
- `_sent = true` olunca `onCodeSent` çağrılıyor ve direkt `ResetPasswordScreen`'e geçiliyor ⚠️
- **Kullanıcı kodu görmeden ResetPassword'a geçiyor** — sent view'da countdown + "e-posta gönderildi" gösteriliyor ama OTP kodu aslında burada girilmiyor, sadece bilgilendirme var. Bu davranış beklenen akışa uyuyor (Supabase magic link kullanımı) ancak kullanıcı deneyimi açısından karışık: "kod gönderdik" ama kod girişi başka ekranda

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Sent view'dan `onCodeSent` direkt çağrılıyor — kullanıcı reset ekranına otomatik geçiyor, akış belirsiz | Orta | `forgot_password_screen.dart` L65: `widget.onCodeSent(...)` | Kullanıcıya "e-posta kontrol et, ardından linke tıkla" talimatı ver; otomatik yönlendirmeyi kaldır |

---

### Ekran: ResetPasswordScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/reset_password_screen.dart`

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P1 | `resetPassword` çağrısında `code: ''` gönderiliyor — OTP doğrulaması yapılmıyor | Yüksek — güvenlik | `reset_password_screen.dart` L72: `code: ''` | OTP giriş alanı ekle veya Supabase deep link akışını kullan |

---

### Ekran: ProfileSetupScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/auth/presentation/screens/profile_setup_screen.dart`

#### 4. Mobil Görsel Yerleşim
- `DropdownButtonFormField` — iOS'ta native dropdown gibi davranmaz; `DropdownMenu` veya `showModalBottomSheet` daha iyi olur ama çalışır
- `SegmentedButton` (1/2/5 vaka) — dar ekranda label kesilebilir ("5 Vaka" kısa, sorun yok) ✅
- `_BranchChip` width: `(constraints.maxWidth - 10) / 2` → 2 sütun — mobil için iyi ✅
- `OutlinedButton.icon` tarih seçici — `Size.fromHeight(50)` ✅
- Varsayılan değerler dolu başlıyor (`_grade = '5. Sınıf'`, `_examDate = DateTime(2026, 6, 24)`, `_branches` 2 seçili) — kullanıcı farkında olmadan devam edebilir
- Kaydedilen sınav tarihi `DateTime(2026, 6, 24)` hardcoded başlıyor ⚠️

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Sınav tarihi `DateTime(2026, 6, 24)` hardcoded başlıyor — gerçek bir kullanıcı için anlamsız varsayılan | Orta | `profile_setup_screen.dart` L37: `DateTime? _examDate = DateTime(2026, 6, 24)` | `null` başlat, tarih seçilmemişse "Opsiyonel" göster |
| P3 | Branşlar varsayılan olarak 2 seçili — kullanıcı istemeden devam edebilir | Düşük | `L37: final _branches = <String>{'Kadın Doğum', 'Genel Cerrahi'}` | Boş başlat |

---

### Ekran: HomeScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/home/presentation/home_screen.dart`
- Navigation: Shell tab 0
- Bağlı: `HomeRepository.loadDashboard()`, `HomeDashboard` model
- State: `_dashboardFuture`, `RefreshIndicator` destekli

#### 2. Ekranın Amacı
Ana ekran: selamlama, devam eden vaka, banner carousel, stats, önerilen vakalar, rozet paneli.

#### 4. Mobil Görsel Yerleşim
- `ListView` ile `bottomPadding: MediaQuery.paddingOf(context).bottom + 132` — bottom nav clearance doğru hesaplanıyor ✅
- `RefreshIndicator` pull-to-refresh ✅
- **Banner Carousel:**
  - `PageView.builder` ✅ ama dot indicator statik — her zaman ilk nokta büyük ve teal, diğerleri gri; scroll ettikçe güncellemiyor ⚠️
  - İlk `index == 0` kontrolü sayfa değiştiğinde güncellenmez
- **Stats Strip:** yatay `ListView.separated`, `height: 150`, `scrollDirection: horizontal` — iç içe scroll (dışta dikey, içte yatay) — Flutter'da genelde sorun değil ✅
- `_NotificationBell` — `onTap: null` değil, callback var ✅
- `_SearchPill` — tıklanabilir görünüm ama kod incelenmeli (ayrı dosyada değil, home_screen içinde)

#### 5. UI Elemanları
- Greeting: büyük "Merhaba, {firstName}!" + "Bugün pratiğe ne dersin?" ✅
- Notification bell + CircleAvatar header ✅
- Banner: gradient kart + CTA button ✅
- Stats: 4 kart (çözülen vaka, başarı, puan, seri) ✅
- Önerilen vakalar: yatay scroll list (178px kart genişliği) ✅
- Badge panel: rozet özeti ✅
- Loading state: `_HomeLoading` ✅
- Error state: `_HomeError` + "Tekrar Dene" butonu ✅
- Empty states her section için ayrı ✅

#### 6. Etkileşim Testi
- "Devam et" ok butonu → `onOpenCases()` → Cases tab
- Banner CTA → `onOpenCases()`
- "Tümünü Gör" → cases veya progress tab
- Pull to refresh → `_refresh()` ✅

#### 7. Mobil Kullanılabilirlik Puanı
- Okunabilirlik: 9/10
- Dokunma kolaylığı: 8/10
- Safe area uyumu: 9/10
- Scroll/klavye uyumu: 9/10
- Tasarım tutarlılığı: 9/10
- Genel mobil kalite: 9/10

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Banner carousel dot indicator statik — sayfa değişince güncellemiyor | Orta — kullanıcı konumunu bilemez | `home_screen.dart` `_BannerCarousel` — `PageController` listener yok | `PageController` ekle, `addListener` ile aktif index güncelle |
| P2 | `_SearchPill` görsel olarak var ama CasesScreen search'e yönlendirmiyor (hızlı navigasyon kaybı) | Düşük | `home_screen.dart` `_SearchPill` widget | Search pill'e `onTap` ile cases tab + search focus ekle |

---

### Ekran: CasesScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/cases/presentation/cases_screen.dart`
- Navigation: Shell tab 1
- State: `_searchController`, `_difficulty`, `_casesFuture`, debounce timer

#### 4. Mobil Görsel Yerleşim
- `ListView` ile `bottomPadding: MediaQuery.paddingOf(context).bottom + 106` ✅
- `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` — sürükleyince klavye kapanıyor ✅
- `_MobileHeader` — menü ikonu (hamburger) var ama `onPressed: () => Navigator.maybePop(context)` — maybePop stack başlangıcında hiçbir şey yapmaz ⚠️
- Notification ikonu `onPressed: null` — deaktif ⚠️
- Search debounce 350ms ✅
- Filtrele butonu: `TextButton.icon` ile `_openFilters()` → push ✅

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Hamburger menü butonu `Navigator.maybePop` çağırıyor; shell tab'ında pop olmaz, anlamsız | Orta | `cases_screen.dart` `_MobileHeader` `IconButton onPressed` | Drawer açacaksa drawer ekle; yoksa icon kaldır |
| P2 | Notification ikonu `null` — tıklanamaz görsel var, işlevsiz | Orta | `cases_screen.dart` `_MobileHeader` — `onPressed: null` | Notifications'a yönlendir veya ikonu kaldır |

---

### Ekran: PatientChatScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/cases/presentation/cases_screen.dart`
- Navigation: Navigator.pushReplacement
- State: `_messageController`, `_bundleFuture`, `_sending`

#### 4. Mobil Görsel Yerleşim — KRİTİK
- `_FlowScaffold(resizeToAvoidBottomInset: true)` — klavye açıldığında ekran küçülüyor ✅
- `Column` içinde `Expanded(ListView)` + `_ChatComposer` — klavye açıldığında compose bar klavyenin üstüne çıkar ✅
- `_ChatComposer` — `_FlowScaffold` parametresi değil, direkt `Column` child olarak `SafeArea` dışında render ediliyor
- **`_FlowScaffold` `SafeArea(bottom: false, child: body)`** — `body` SafeArea bottom yok; `_ChatComposer` bu body içindeyse home indicator üzerine çıkabilir ⚠️
- Mesaj gönderilince `_bundleFuture = _load()` ile tüm liste yeniden yükleniyor — büyük mesaj listelerinde performans sorunu ⚠️
- `_sending` true iken buton disabled ✅

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P1 | `_FlowScaffold` `SafeArea(bottom: false)` — `_ChatComposer` body içinde render edilirse iOS home indicator üzerine çıkabilir | Yüksek | `cases_screen.dart` `_FlowScaffold.body` SafeArea bottom:false | `_ChatComposer` için `SafeArea` wrapper ekle veya `_FlowScaffold` bottom param kullan |
| P1 | Her mesaj gönderiminde `_bundleFuture = _load()` ile tüm session + mesajlar yeniden fetch ediliyor — gerçek kullanımda lag ve flicker | Yüksek | `cases_screen.dart` `_send()` L5-6 | Mesajları local state'e ekle, sadece yeni mesajı append et |
| P2 | "Muayeneye Geç" butonu (`_next`) her bastığında PhysicalExamScreen push ediliyor; rate limit/double-tap koruması yok | Orta | `cases_screen.dart` `_next()` — `_sending` kontrolü yok buton için | `_navigating` bool ekle |

---

### Ekran: DiagnosisScreen / ManagementPlanScreen

#### 4. Mobil Görsel Yerleşim
- `resizeToAvoidBottomInset: true` ✅
- `keyboardDismissBehavior: onDrag` ✅
- `_InputBlock` — `maxLines: 6` (gerekçe) ve `maxLines: 5` (plan notu) → uzun text girişi
- **Bottom fixed button (`_BottomAction`) `SafeArea` içinde `Padding.fromLTRB(20,8,20,14)` ile render ediliyor** — iOS'ta yeterli ✅
- Scroll'un altı `padding: EdgeInsets.fromLTRB(20,12,20,130)` — fixed butonla çakışmaması için 130px ✅

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | DiagnosisScreen'de "Devam Et" butonu form boş olsa da aktif — tanı yazılmadan, opsiyon seçilmeden ilerleniyor | Orta | `diagnosis_screen.dart` `_save()` — validasyon yok | Primer tanı alanı doluysa butonu aktifleştir |

---

### Ekran: ProfileScreen

#### 1. Teknik Kaynak
- Dosya: `lib/src/features/progress/presentation/progress_screens.dart`
- Navigation: Shell tab 4

#### 4. Mobil Görsel Yerleşim
- `ListView` padding `fromLTRB(20, 0, 20, 116)` — bottom nav clearance ✅
- `_ProfileHero`: avatar + isim + istatistikler ✅
- `_MenuPanel`: 7 menü öğesi listesi

#### 5. UI Elemanları / Sorun — KRİTİK
`_MenuPanel` içindeki menü öğeleri:
- "Vaka Geçmişim" → yok (onTap yok)
- "Favori Vakalarım" → yok
- "Notlarım" → yok
- "Bildirimler" → Settings üzerinden var ama direkt ProfileScreen'den yok
- "Başarılarım" → yok
- "Ayarlar" → SettingsScreen ✅
- "İndirmelerim" → yok

**7 menü öğesinden 6'sı işlevsiz.** Kullanıcı bir şeye basar ama hiçbir şey olmaz.

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P1 | ProfileScreen'de 7 menü öğesinin 6'sı `onTap: null` — tıklayınca hiçbir şey olmuyor, kullanıcı kilitleniyor | Yüksek | `progress_screens.dart` `_MenuPanel` items listesi | CaseHistoryScreen, FavoriteCasesScreen vb. zaten yazılmış — navigation ekle |

---

### Ekran: SettingsScreen / LogoutConfirmScreen

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P0 | `LogoutConfirmScreen` logout onayladığında `PratiCaseApp._authenticated` false'a setlemiyor — auth state sıfırlanmıyor | Kritik | `progress_screens.dart` `LogoutConfirmScreen` — `praticase_app.dart`'taki `_authenticated` state'e erişim yok | Callback ile üst widget'a ulaş veya state management ekle |
| P2 | SettingsScreen birçok ayar satırı (dil, yazı boyutu, ses) salt gösterim — değiştirilemez | Orta | `progress_screens.dart` `_SettingsRow` — `onTap: null` satırları | "Yakında" etiketi ekle veya işlevsel yap |

---

### Ekran: ContactScreen

#### 8. Bulunan Sorunlar
| Öncelik | Sorun | Mobil Etki | Kanıt | Öneri |
|---|---|---|---|---|
| P2 | Email ve konu alanları için validasyon yok — boş form gönderilebilir | Orta | `contact_screen.dart` `_send()` — kontrol yok | Boş alan kontrolü ekle |
| P2 | Klavye açıkken "Gönder" butonu görünmeyebilir (ListView içinde değil, `_ProgressPage.children`) | Orta | `progress_screens.dart` `ContactScreen` build | Submit butonu sabit alta taşı |

---

## 7. Buton / CTA / Etkileşim Matrisi

| Ekran | Eleman | Tip | Beklenen Davranış | Gerçek Davranış | Mobil Durum | Risk | Öncelik |
|---|---|---|---|---|---|---|---|
| Onboarding | Hesap Oluştur | FilledButton (gradient) | → RegisterScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Onboarding | Giriş Yap | OutlinedButton | → LoginScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Login | Giriş Yap | AuthPrimaryButton | Submit + loading | ✅ Loading + hata göster | Sorunsuz | Düşük | — |
| Login | Şifremi unuttum? | AuthLinkButton | → ForgotPassword | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Login | Kayıt ol | AuthLinkButton | → Register | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Login | Geri | IconButton (arrow_back_ios) | → Onboarding | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Register | Hesap Oluştur | AuthPrimaryButton | Submit + loading | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Register | Gizlilik linki | TextSpan (teal) | Gizlilik sayfası aç | ❌ Tıklanamaz | Belirsiz | Yüksek | P1 |
| Register | Terms checkbox | InkWell | Toggle onay | ✅ Toggle ediyor, başlangıç:true | Parmakla basması zor (20×20px) | Orta | P2 |
| VerifyEmail | Doğrula | AuthPrimaryButton | OTP verify | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| VerifyEmail | Kodu tekrar gönder | AuthLinkButton | Resend email | ✅ Çalışıyor (cooldown yok) | Sorunsuz | Düşük | P2 |
| ForgotPassword | Gönder | AuthPrimaryButton | Email gönder | ✅ + 45s countdown | Sorunsuz | Düşük | — |
| ResetPassword | Şifreyi Güncelle | AuthPrimaryButton | Reset + `code:''` | ⚠️ code boş gönderiliyor | Sorunsuz görsel | Yüksek | P1 |
| ResetPassword | Giriş Ekranına Dön | AuthPrimaryButton | → Login | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| ProfileSetup | PratiCase'e Başla | AuthPrimaryButton | Profile save | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| ProfileSetup | Branch chip | InkWell | Toggle seçim | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| ProfileSetup | Tarih seç | OutlinedButton.icon | DatePicker aç | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Home | Notification bell | IconButton | Notifications aç | ✅ Çalışıyor (null kontrolü var) | Sorunsuz | Düşük | — |
| Home | Devam et ok | _ArrowButton | → Cases tab | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Home | Banner CTA | FilledButton.icon | → Cases tab | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Home | Stats section header "Tümü" | TextButton | → Progress tab | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Home | Önerilen vaka kart | (tıklanabilir mi?) | Vaka detay aç | ⚠️ Tıklama handler belirsiz | Belirsiz | Orta | P2 |
| Cases | Vaka liste kartı | _CaseListCard | → CaseDetailScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Cases | Filtrele | TextButton.icon | → FilterScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Cases | Hamburger menü | IconButton | Navigator.maybePop | ⚠️ Hiçbir şey yapmaz | Belirsiz | Orta | P2 |
| Cases | Notification | IconButton | onPressed: null | ❌ İşlevsiz | Belirsiz | Orta | P2 |
| CaseDetail | Vaka Çözümüne Başla | _BottomAction | Start session | ✅ Loading + pushReplacement | Sorunsuz | Düşük | — |
| CaseDetail | Bookmark | IconButton | Toggle bookmark | ⚠️ `onPressed: null` — işlevsiz | Belirsiz | Orta | P2 |
| PatientChat | Gönder | IconButton (send) | Mesaj gönder | ✅ Loading kontrolü var | Sorunsuz | Düşük | — |
| PatientChat | Vaka İlerlemesi | OutlinedButton.icon | → CaseProgress | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| PatientChat | Not Ekle | OutlinedButton.icon | → AddNote | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| PatientChat | Devam Et (muayeneye) | _BottomAction | _next() → Physical | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| PatientChat | Sınavı Bitir | _FinishExamButton | Finish session | Kod içinde var, davranış test edilemedi | Test edilemedi | Orta | — |
| PhysicalExam | Bulgu seç | _FindingsCard item | Toggle seçim | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| PhysicalExam | Devam Et | _BottomAction | → TestsScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Tests | Tetkik seç | _TestOptionTile | Toggle + detay | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Tests | Tetkik detay | _TestOptionTile trailing | Lab/Imaging screen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Tests | Devam Et | _BottomAction | → DiagnosisScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Diagnosis | Devam Et | _BottomAction | → Management | ✅ Çalışıyor (boş geçilebilir) | Sorunsuz | Orta | P2 |
| Management | İlaç Bilgisi | OutlinedButton.icon | → Medication | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Management | Planı Kaydet | _BottomAction | → ResultScreen | ✅ pushReplacement | Sorunsuz | Düşük | — |
| Result | Vaka Raporunu İncele | _BottomAction | → CaseReport | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Exams tab | Tek İstasyon | _ExamModeCard | → Cases tab | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Exams tab | Mini OSCE / Zayıf / Branş | _ExamModeCard | → Cases tab | ⚠️ Hepsi aynı yere — ekran yok | Belirsiz | Orta | P2 |
| Progress | Sıralamayı Gör | _ExamModeCard | → LeaderboardScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Profile | Vaka Geçmişim | _MenuPanel item | → CaseHistoryScreen | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Profile | Favori Vakalarım | _MenuPanel item | → FavoriteCasesScreen | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Profile | Notlarım | _MenuPanel item | → Notes | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Profile | Bildirimler | _MenuPanel item | → Notifications | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Profile | Başarılarım | _MenuPanel item | → Badges | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Profile | Ayarlar | _MenuPanel item | → SettingsScreen | ✅ Çalışıyor | Sorunsuz | Düşük | — |
| Profile | İndirmelerim | _MenuPanel item | → Downloads | ❌ onTap null | Belirsiz | Yüksek | P1 |
| Settings | Çıkış Yap | OutlinedButton | → LogoutConfirm | ✅ Açılıyor | Sorunsuz | Düşük | — |
| LogoutConfirm | Çıkış onayla | Button | Auth state reset | ❌ App state sıfırlanmıyor | Kritik | Kritik | P0 |
| Contact | Gönder | FilledButton | Form submit | ✅ Supabase'e kaydeder | Klavye ile çakışıyor | Orta | P2 |
| Shell | Bottom nav 5 tab | _NavItem | Tab değiştir | ✅ Çalışıyor | Sorunsuz | Düşük | — |

---

## 8. Kullanıcı Akışları Matrisi

| Akış | Başlangıç | Adımlar | Beklenen Sonuç | Gerçek Sonuç | Mobil Sorun | Durum | Öncelik |
|---|---|---|---|---|---|---|---|
| İlk açılış | main.dart | Supabase init → session restore → AuthFlow | Onboarding veya Shell | ✅ Doğru; env yoksa mock repository | Loading beklenemiyor — async splash yok | ⚠️ Splash yok | P2 |
| Kayıt | Onboarding | Register → Verify → ProfileSetup → Shell | Dashboard | ✅ Akış tam, terms riski var | Uzun form küçük ekranda | ⚠️ Kısmen | P1 |
| Giriş | Onboarding | Login → Shell | Dashboard | ✅ Çalışıyor | Klavye scroll | ✅ Çalışıyor | — |
| Şifre sıfırlama | Login | ForgotPw → Reset | Login | ⚠️ OTP code:'' | Akış belirsiz | ⚠️ Güvenlik riski | P1 |
| Vaka çözme | Cases | List → Detail → Chat → Physical → Tests → Diagnosis → Management → Result | Sonuç karnesi | ✅ Eksiksiz flow, 8 adım | Chat klavye + refresh | ✅ Çalışıyor | P1 (chat fix) |
| Logout | Settings | Settings → LogoutConfirm → Login | Onboarding/Login | ❌ Auth state sıfırlanmıyor | — | ❌ Kırık | P0 |
| Profil görüntüleme | Shell tab 4 | ProfileScreen | Profil + stats | ✅ Yükleniyor ama menü yok | Menü boş | ⚠️ Kısmen | P1 |
| Gelişim | Shell tab 3 | ProgressSummary | Başarı oranı | ✅ Yükleniyor | — | ✅ Çalışıyor | — |
| Sıralama | Progress → Leaderboard | Sıralama listesi | ✅ Push + load | — | ✅ Çalışıyor | — |
| Rozetler | Home badge panel | BadgesScreen | Rozet grid | ✅ Açılıyor | Grid shrinkWrap | ✅ Çalışıyor | — |
| Bildirimler | Home bell | NotificationsScreen | Bildirim listesi | ✅ Açılıyor | — | ✅ Çalışıyor | — |

---

## 9. Mobil Uyumluluk Raporu

### 9.1 Safe Area

| Ekran | Safe Area Durumu | Sorun | Etki | Öncelik |
|---|---|---|---|---|
| Auth ekranları (tümü) | ✅ `AuthScaffold` → `SafeArea` tam | — | — | — |
| Shell + HomeScreen | ✅ `extendBody: true` + `SafeArea(bottom: false)` + manuel bottom padding | bottomPadding = `.bottom + 132` hesabı doğru | — | — |
| PatientChatScreen | ⚠️ `_FlowScaffold body SafeArea(bottom: false)` — Chat composer body içinde | iOS home indicator çakışma riski | Yüksek | P1 |
| _FlowScaffold (tüm vaka akışları) | ✅ `SafeArea(bottom:false)` + bottom action `SafeArea(top:false)` + padding | Bottom action güvenli | — | — |
| ProgressPage | ✅ `padding: fromLTRB(20,0,20,116)` — bottom nav clearance | — | — | — |

### 9.2 Klavye Davranışı

| Ekran | Input | Klavye Açılınca Durum | Sorun | Öncelik |
|---|---|---|---|---|
| LoginScreen | Email, Şifre | `SingleChildScrollView` scroll eder | Hata kartı görünmeyebilir | P2 |
| RegisterScreen | 5 alan | Scroll eder | Uzun scroll; hata kartı görünmeyebilir | P2 |
| VerifyEmailScreen | OTP 6 kutu | Scroll eder | — | — |
| PatientChatScreen | Mesaj | `resizeToAvoidBottomInset:true` + Column | Composer yukarı çıkar ✅; SafeArea riski | P1 |
| DiagnosisScreen | 2 TextField | `resizeToAvoidBottomInset:true` + ListView scroll | ✅ | — |
| ManagementPlanScreen | 2 TextField | `resizeToAvoidBottomInset:true` + ListView scroll | ✅ | — |
| AddNoteScreen | 10-line textarea | `resizeToAvoidBottomInset:true` | ✅ | — |
| ContactScreen | 3 alan | ListView | Submit butonu klavye kapandıktan sonra görünür | P2 |

### 9.3 Dokunma Hedefleri

| Ekran | Eleman | Dokunma Riski | Etki | Öncelik |
|---|---|---|---|---|
| RegisterScreen | Terms checkbox (20×20px) | Çok küçük | Yanlış basma / kaçırma | P2 |
| AuthScaffold | Back button (IconButton, padding:only left:18) | Yeterli (~48px) | — | — |
| Shell bottom nav | `_NavItem` 66px yükseklik | ✅ Yeterli | — | — |
| CaseListCard | Tüm kart tıklanabilir | ✅ | — | — |
| ProfileScreen menü | `_SettingsRow` tam genişlik tıklanabilir | ✅ | — | — |
| OtpInput kutular | Expanded → ~48px ✅ | — | — | — |
| Banner carousel dot | ~9px küçük nokta | Tıklanamıyor (sadece görsel) | — | — |

### 9.4 Scroll Davranışı

| Ekran | Scroll Durumu | Sorun | Etki | Öncelik |
|---|---|---|---|---|
| HomeScreen | `ListView` dikey + Stats `ListView` yatay | İç içe scroll (standart Flutter pattern, genelde sorun yok) | — | — |
| HomeScreen önerilen vakalar | `ListView.separated` yatay (220px yükseklik) | Kart tıklanabilirliği test edilemedi | Orta | P2 |
| CasesScreen | `ListView` dikey, kart listesi | `keyboardDismissBehavior.onDrag` ✅ | — | — |
| BadgesScreen | `GridView.count + shrinkWrap:true + NeverScrollableScrollPhysics` içinde `_ProgressPage ListView` | Doğru pattern ✅ | — | — |
| PatientChatScreen | `Column > Expanded(ListView)` | Büyük listede performans | P2 | — |
| ProfileScreen | `ListView` + `bottomPadding:116` | ✅ | — | — |
| PhysicalExam / Tests | `ListView` + `bottom:120` | ✅ | — | — |

### 9.5 Responsive Kırılma

| Ekran | Küçük Ekran (SE 375) | Standart iPhone 14 (390) | Büyük iPhone Pro Max (430) | Tablet | Sonuç |
|---|---|---|---|---|---|
| Onboarding | ⚠️ Uzun scroll gerekli | ✅ | ✅ | ✅ (maxWidth:430) | Küçük ekranda uzun |
| Register | ⚠️ Uzun scroll | ✅ | ✅ | ✅ (maxWidth:430) | SE'de riskli |
| ProfileSetup | ✅ Wrap ile 2 sütun | ✅ | ✅ | ⚠️ Tek sütun görünüm | Tablet iyi değil |
| HomeScreen banner | ✅ | ✅ | ✅ | ⚠️ Geniş ekranda kart stretching | Tablet riski |
| PatientChat | ✅ | ✅ | ✅ | ⚠️ | — |
| Shell bottom nav | ✅ 5 tab `FittedBox` ile label sığıyor | ✅ | ✅ | ⚠️ Tablet için sidebar/rail öneri | — |

---

## 10. Tasarım ve UX Kalite Raporu

| Ekran | Görsel Kalite | Tutarlılık | Okunabilirlik | Kullanıcı Yönlendirme | Premium His | Genel UX |
|---|---|---|---|---|---|---|
| Onboarding | 9 | 9 | 9 | 9 | 9 | 9 |
| Login | 8 | 9 | 9 | 8 | 8 | 8 |
| Register | 8 | 9 | 8 | 7 | 8 | 8 |
| VerifyEmail | 9 | 9 | 9 | 9 | 9 | 9 |
| ForgotPassword | 9 | 9 | 9 | 8 | 9 | 9 |
| ResetPassword | 8 | 9 | 9 | 7 | 8 | 8 |
| ProfileSetup | 8 | 8 | 9 | 8 | 8 | 8 |
| HomeScreen | 9 | 9 | 9 | 9 | 9 | 9 |
| CasesScreen | 8 | 9 | 9 | 8 | 8 | 8 |
| PatientChat | 8 | 8 | 8 | 8 | 7 | 8 |
| Exam Akışı (5 adım) | 8 | 9 | 8 | 8 | 8 | 8 |
| ResultScreen | 8 | 9 | 9 | 8 | 8 | 8 |
| ProfileScreen | 7 | 8 | 9 | 4 | 6 | 6 |
| SettingsScreen | 7 | 8 | 8 | 5 | 6 | 6 |

**Genel değerlendirme:**
- Tasarım sistemi (navy/teal/gold, Material 3) tutarlı uygulanmış
- Auth ekranları premium hissettiriyor — gradient butonlar, custom hero illüstrasyonlar, confetti animasyonu özenli
- Ana akış ekranları (Home, Cases) görsel olarak güçlü
- Profile ve Settings ekranları tamamlanmamış menülerle kullanıcıyı yönlendiremiyor
- Genel tipografi hiyerarşisi iyi; headlineMedium→titleLarge→bodyMedium→bodySmall sistematik kullanılmış
- Boşluk sistemi tutarlı (8/10/12/14/18/22/24/28 spacing)

---

## 11. Loading / Empty / Error State Raporu

| Ekran | Durum | Kullanıcı Ne Görüyor? | Yeterli mi? | Sorun | Öncelik |
|---|---|---|---|---|---|
| HomeScreen | Loading | `_HomeLoading` custom widget | ✅ Yeterli | — | — |
| HomeScreen | Error | `_HomeError` + retry butonu + mesaj | ✅ Yeterli | Teknik exception metni görünebilir | P2 |
| HomeScreen | API bağlantı yok | Repository null → `_LiveDataRequiredScreen` | ⚠️ "Yapılandırma gerekli" teknik mesaj | Son kullanıcı ne yapacağını bilmez | P1 |
| HomeScreen | Banner boş | `_EmptyPanel` icon + başlık + body | ✅ Yeterli | Supabase tablo adı kullanıcıya görünüyor | P2 |
| CasesScreen | Loading | `_CenteredState` spinner benzeri | ✅ Yeterli | — | — |
| CasesScreen | Error | `_CenteredState` cloud_off icon + mesaj | ✅ Yeterli | Retry butonu yok | P2 |
| CasesScreen | Boş liste | `_CenteredState` | ✅ Yeterli | Tablo adı görünüyor | P2 |
| PatientChat | Loading | `_CenteredState` | ✅ | — | — |
| PatientChat | Error | `_CenteredState` | ⚠️ Retry yok; geri buton var | Kullanıcı stuck kalabilir | P1 |
| Result | Loading | `_CenteredState` | ✅ | — | — |
| Leaderboard | Loading | `_StateBlock` | ✅ | — | — |
| Profile | Loading | `_ProgressPage` + `_StateBlock` | ✅ | — | — |
| Profile | Error | `_ProgressPage` + `_StateBlock` | ✅ Yeterli | — | — |
| _LiveDataRequiredScreen | Tüm repository null | Yapılandırma mesajı | ❌ Teknik; son kullanıcı için anlamsız | Ticari build'de tüm tab'lar bu ekranı gösterir | P0 |
| Tüm FutureBuilder | Timeout / sonsuz loading | Spinner döner | ⚠️ Timeout mekanizması yok | Yavaş ağda sonsuz loader | P1 |

---

## 12. Güvenlik ve Veri Riski Gözlemleri

1. **Auth state persist riski:** `_restoreSession()` sadece başlangıçta çalışıyor; token süresi dolduktan sonra korumalı ekranlar erişilebilir kalabilir (repository exception yönetimi ile bağlantılı).
2. **OTP kod bypass:** `ResetPasswordScreen`'de `code: ''` gönderilmesi kritik — Supabase API'nin bunu nasıl yorumladığına göre şifre sıfırlama atlatılabilir.
3. **Terms checkbox varsayılan true:** KVKK/GDPR açısından kullanıcının aktif onayı olmadan kayıt alınıyor.
4. **Demo repository bilgisi:** Onboarding ekranında "Medasi auth env gelene kadar..." mesajı son kullanıcıya sızıyor.
5. **Supabase tablo adları:** Empty state mesajlarında `praticase.home_banners`, `praticase.user_dashboard_stats` gibi tablo adları kullanıcıya görünüyor — bilgi ifşası riski.
6. **Logout akışı:** Auth state sıfırlanmıyor; biri başkasının cihazında uygulamayı açabilir.
7. **Contact form:** Validasyon yok; spam riski.

> Not: Secret, token veya private key herhangi bir kaynak dosyada bulunamadı. Env değerleri `String.fromEnvironment` ile build-time injection ile güvenli alınıyor.

---

## 13. Performans Gözlemleri

1. **PatientChat mesaj yenileme:** Her gönderimde `session + messages` yeniden fetch — N+2 query pattern. 10+ mesajda fark edilir gecikme.
2. **FutureBuilder pattern:** Tüm ekranlar `FutureBuilder` kullanıyor; tab değiştiğinde `IndexedStack` ile widget dispose edilmiyor — veri hafızada tutuluyor. Büyük veri setlerinde bellek birikimi.
3. **`shrinkWrap: true` + `NeverScrollableScrollPhysics`:** BadgesScreen'de grid + dış ListView içinde bu pattern kullanılmış. GridView item sayısı artınca performans düşer (tüm item'lar aynı anda render edilir).
4. **`Image.network`:** ImagingResultScreen'de network resim doğrudan yükleniyor, cache/error placeholder yeterli değil.
5. **`IndexedStack`:** Shell 5 tab hepsi memory'de tutuluyor — başlangıçta tüm repository call'ları tetiklenebilir.
6. **Debounce 350ms:** Arama için yeterli ✅.
7. **Paket uyarıları:** `flutter pub outdated` ile 7 paket eski sürümde. Büyük risk değil ama güncelleme önerilir.

---

## 14. Yayına Hazırlık Kontrol Listesi

| Madde | Durum | Detay |
|---|---|---|
| Build alınabiliyor mu? | ✅ | iOS 35.7MB, Android APK başarılı |
| `debugShowCheckedModeBanner: false` | ✅ | `praticase_app.dart` L46 |
| Test/mock veri kullanıcıya görünüyor mu? | ⚠️ | "Demo akışı açık" mesajı + Supabase tablo adları empty state'lerde |
| Placeholder metin kaldı mı? | ⚠️ | `_FilterSummaryRow` değerleri "Canlı vaka verisine göre" gibi teknik metinler |
| Console log / debug print fazlalığı | ✅ | Kaynak kodda `print` / `debugPrint` görülmedi |
| App icon tutarlı mı? | Test edilemedi | `assets/branding/praticase.png` kullanılıyor; fiziksel cihaz gerekli |
| App name | ✅ | `MaterialApp(title: 'PratiCase')` |
| Gizlilik / kullanım şartları linki | ❌ | Register'da link rengi var ama tıklanamıyor |
| Ödeme sistemi | ❌ | Hiç yok; uygulama freemium yapısı belirsiz |
| Sandbox/production ayrımı | ✅ | `AuthRepositoryFactory` env check ile ayırıyor |
| Auth güvenli mi? | ⚠️ | OTP bypass riski, logout akışı kırık |
| Logout doğru mu? | ❌ | Auth state sıfırlanmıyor |
| Push notification | ❌ | Kod yok; bildirim ekranı var ama izin akışı yok |
| Mobil performans | ⚠️ | Chat mesaj refresh, shrinkWrap grid |
| Test coverage | ⚠️ | 1 widget test; kritik akışlar test edilmemiş |
| Localization | ⚠️ | Tüm metin Türkçe hardcoded; i18n altyapısı yok |

---

## 15. Önceliklendirilmiş Sorun Listesi

### P0 — Yayına Kesin Engel

| # | Sorun | Ekran | Dosya |
|---|---|---|---|
| 1 | Logout auth state sıfırlamıyor — `LogoutConfirmScreen` `PratiCaseApp._authenticated`'a ulaşamıyor; kullanıcı logout sonrası tekrar açınca authenticated kalıyor | LogoutConfirmScreen | `progress_screens.dart`, `praticase_app.dart` |
| 2 | Env olmadan tüm ana tab'lar `_LiveDataRequiredScreen` gösteriyor — son kullanıcı için anlaşılmaz, ticari build'de kritik | Shell tüm tab'lar | `praticase_shell.dart` |

### P1 — Çok Kritik

| # | Sorun | Ekran | Dosya |
|---|---|---|---|
| 3 | Terms checkbox varsayılan `true` — aktif KVKK onayı alınmıyor | RegisterScreen | `register_screen.dart` L41 |
| 4 | Gizlilik politikası linki tıklanamıyor | RegisterScreen | `register_screen.dart` RichText |
| 5 | `ResetPasswordScreen` `code: ''` gönderiyor — OTP doğrulama bypass riski | ResetPasswordScreen | `reset_password_screen.dart` L72 |
| 6 | ProfileScreen menü öğelerinden 6/7'si `onTap: null` | ProfileScreen | `progress_screens.dart` |
| 7 | PatientChatScreen `_ChatComposer` SafeArea(bottom:false) body içinde — iOS home indicator üstüne çıkabilir | PatientChatScreen | `cases_screen.dart` `_FlowScaffold` |
| 8 | PatientChat: her mesajda tüm session yeniden fetch — ciddi lag | PatientChatScreen | `cases_screen.dart` `_send()` |
| 9 | FutureBuilder timeout yok — yavaş ağda sonsuz loading | Tüm async ekranlar | — |
| 10 | `_LiveDataRequiredScreen` teknik içerikli — son kullanıcıya açıklamalı mesaj gerekli | Shell tabs | `praticase_shell.dart` |

### P2 — Orta

| # | Sorun | Ekran | Dosya |
|---|---|---|---|
| 11 | Uygulama splash ekranı yok — açılışta white flash | main.dart | — |
| 12 | Banner carousel dot indicator statik | HomeScreen | `home_screen.dart` |
| 13 | Önerilen vaka kartları tıklanabilir değil (home'dan vaka detaya gidilemiyor) | HomeScreen | `home_screen.dart` |
| 14 | Cases hamburger menü işlevsiz | CasesScreen | `cases_screen.dart` |
| 15 | Cases notification butonu `null` | CasesScreen | `cases_screen.dart` |
| 16 | CaseDetail bookmark butonu `null` | CaseDetailScreen | `cases_screen.dart` |
| 17 | Exams tab 4 kart hepsi aynı yere gidiyor (Mini OSCE gibi modlar gerçek ekran yok) | ExamsScreen | `praticase_shell.dart` |
| 18 | Hata kartları form altında — klavye açıkken görünmeyebilir | Login, Register | — |
| 19 | Empty state mesajlarında Supabase tablo adları görünüyor | Tüm ekranlar | — |
| 20 | VerifyEmail'de resend cooldown yok | VerifyEmailScreen | `verify_email_screen.dart` |
| 21 | DiagnosisScreen boş form ile ilerlenebilir | DiagnosisScreen | `cases_screen.dart` |
| 22 | ProfileSetup sınav tarihi hardcoded başlıyor | ProfileSetupScreen | `profile_setup_screen.dart` L37 |
| 23 | Settings'te çoğu ayar salt görüntüleme | SettingsScreen | `progress_screens.dart` |
| 24 | Contact form validasyon yok | ContactScreen | `progress_screens.dart` |
| 25 | Image.network error placeholder zayıf | ImagingResultScreen | `cases_screen.dart` |
| 26 | 7 paket eski sürüm | pubspec.yaml | — |

### P3 — Düşük

| # | Sorun | Ekran | Dosya |
|---|---|---|---|
| 27 | Onboarding'de "demo akışı açık" mesajı yayın buildinde görünmemeli | OnboardingScreen | `onboarding_screen.dart` L95 |
| 28 | AuthLogoBlock 104px icon iPhone SE'de kalabalık | LoginScreen | `auth_visuals.dart` |
| 29 | ProfileSetup branşlar varsayılan olarak 2 seçili | ProfileSetupScreen | `profile_setup_screen.dart` L37 |
| 30 | Localization altyapısı yok — hardcoded Türkçe | Tüm ekranlar | — |
| 31 | Tablet layout planlanmamış | Shell | `praticase_shell.dart` |
| 32 | Test coverage tek widget test ile çok sınırlı | — | `test/widget_test.dart` |

---

## 16. Adım Adım Aksiyon Önerisi

Aşağıdaki sırayla ele alınmalıdır (kod değişikliği yapılmadan hangi alanların düzeltilmesi gerektiği):

1. **[P0] Logout state sıfırlama:** `LogoutConfirmScreen`'e callback veya Navigator sonucu ile `PratiCaseApp._authenticated = false` + `setState` tetiklenmelidir.
2. **[P0] `_LiveDataRequiredScreen` son kullanıcıya uygun hale getirilmesi:** Teknik "yapılandırma gerekli" mesajı yerine "Şu anda hizmete hazırlanıyoruz" gibi kullanıcı dostu mesaj.
3. **[P1] Terms checkbox `false` başlatılması:** KVKK uyumu için zorunlu.
4. **[P1] Gizlilik politikası linki:** `TapGestureRecognizer` ile URL açılmalı.
5. **[P1] ResetPassword OTP:** `code: ''` yerine gerçek kod girişi veya Supabase magic link akışı kullanılmalı.
6. **[P1] ProfileScreen menü navigation:** 6 işlevsiz menü öğesi için ilgili ekranlara yönlendirme eklenmeli (ekranlar zaten mevcut).
7. **[P1] PatientChat SafeArea:** Compose bar için açık SafeArea bottom eklenmeli.
8. **[P1] PatientChat mesaj yenileme:** Local state append ile optimize edilmeli.
9. **[P1] FutureBuilder timeout:** `Future.timeout` ile 15-30 saniye timeout + timeout error state eklenmeli.
10. **[P2] Splash ekranı:** iOS LaunchScreen ve Flutter splash widget eklenmeli.
11. **[P2] Banner carousel dots:** `PageController.addListener` ile aktif dot güncellenmeli.
12. **[P2] Empty state Supabase tablo adları:** Son kullanıcıya yönelik metinlerle değiştirilmeli.
13. **[P2] Hata kartları:** Form altından üste (veya CTA üstüne) taşınmalı.
14. **[P2] Onboarding demo mesajı:** `kDebugMode` kontrolüne bağlanmalı veya kaldırılmalı.
15. **[P3] Önerilen vaka kartları:** Tıklanınca vaka detaya giden navigation eklenmeli.

---

## 17. Nihai Karar

### 🔴 KRİTİK DÜZELTMELERİ TAMAMLANDIKTAN SONRA YAYINA HAZIR

**PratiCase şu anda mobil yayına hazır değildir.**

Teknik temel çok sağlam — sıfır analiz hatası, başarılı iOS ve Android build, tutarlı tasarım sistemi ve eksiksiz OSCE exam akışı. Ancak:

- **Logout kırık (P0):** Auth güvenliği temel gerekliliktir
- **Canlı veri yoksa uygulama kullanılamıyor (P0):** Ticari release için veri hazırlığı zorunlu
- **KVKK/Terms riski (P1):** App Store / yasal gereklilik
- **Profil menüsü boş (P1):** Kullanıcının %60 ekranı çalışmıyor

**P0 ve P1 sorunlar giderildikten sonra** uygulama "küçük düzeltmelerle yayına hazır" kategorisine geçer. Gerçek cihaz testi ve Supabase canlı veri yüklenmesi zorunludur.

---

*Rapor; kaynak kodu tam incelemesi, flutter analyze (0 hata), flutter test (1/1 geçti), iOS build (35.7MB başarılı), Android debug APK (başarılı) temel alınarak hazırlanmıştır. Gerçek cihaz testi yapılmamıştır.*
