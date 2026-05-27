# PratiCase — Copilot Instructions

PratiCase is a Flutter-first OSCE simulation app in the Medasi ecosystem. Supabase backend, iPhone-oriented, deployed via Coolify.

## ⚠️ Platform Isolation (Top Priority)

iOS ships via App Store + StoreKit (`in_app_purchase`). Android ships **outside Play Store** as APK with iyzico/IBAN + activation codes. **Never let one platform's change touch the other.**

- Do NOT modify `ios/` when working on Android (Podfile, Info.plist, Xcode project, entitlements — all off-limits).
- Do NOT modify `android/` when working on iOS.
- All platform-specific Dart code MUST be guarded with `Platform.isAndroid` / `Platform.isIOS` or conditional imports.
- iOS UI must NOT show external payment links (Apple anti-steering rule).
- New Android-only files use `android_*.dart` / `*_android.dart` naming.
- After Android changes, verify `flutter build ios --release --no-codesign` still succeeds.

Full contract: [`docs/PLATFORM_ISOLATION.md`](../docs/PLATFORM_ISOLATION.md).

## Other Binding Documents

- [`AGENTS.md`](../AGENTS.md) — PratiCase playbook, ecosystem rules
- [`docs/PLATFORM_ISOLATION.md`](../docs/PLATFORM_ISOLATION.md) — iOS/Android isolation contract
