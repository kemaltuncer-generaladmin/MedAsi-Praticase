# PratiCase Flutter Design System & Implementation Guide

## 1. Merkezi Tema (ThemeData) Yapısı
Tüm UI bileşenleri `Theme.of(context)` üzerinden beslenecek şekilde yapılandırılmıştır.

### Renk Paleti (PratiCaseColors)
- **Primary (Teal):** `#0e7c78` (Klinik aksiyonlar, butonlar)
- **Secondary (Navy):** `#0b1d2a` (Başlıklar, kurumsal güven)
- **Accent (Gold):** `#f2a900` (Uyarılar, başarı durumları)
- **Surface:** `#f7f9ff` (Temiz medikal arka planlar)

### Tipografi (TextStyles)
- **Headline:** Plus Jakarta Sans Bold (Klinik ciddiyet)
- **Body:** Plus Jakarta Sans Regular (Okunabilirlik)

## 2. Widget Mimarisi (Componentization)
Kod üretimi sırasında şu yapı korunmalıdır:
- **`PratiCaseScaffold`**: Safe-area ve BottomNav yönetimini yapan ana yapı.
- **`ActionCard`**: Vakalar ve gelişim verileri için kullanılan esnek kart bileşeni.
- **`ClinicalInput`**: Chat ve tanı girişleri için kullanılan, klavye uyumlu input alanı.

## 3. Responsive Prensipler
- Sabit `width: 300px` yerine `width: double.infinity` veya `Flexible/Expanded` kullanımı.
- `MediaQuery.of(context).padding` ile notch ve home indicator uyumu.
- `ListView.separated` ile dinamik içerik yönetimi.

## 4. Akış Planı (User Flow)
1. **Giriş:** Onboarding -> Login -> Profil Kurulumu.
2. **Keşfet:** Dashboard -> Vaka Kütüphanesi.
3. **Simülasyon:** Sınav Odası (Anamnez) -> Fizik Muayene -> Tetkik -> Tanı/Yönetim.
4. **Değerlendirme:** Sonuç Karnesi -> Gelişim Analizi.
