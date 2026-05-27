# PratiCase

PratiCase is the OSCE simulation application in the Medasi ecosystem. It is a Flutter-first, iPhone-oriented product for virtual patient interviews, timed stations, structured clinical actions, and rubric-based score reports.

> ⚠️ **Platform İzolasyonu:** iOS (App Store + StoreKit) ile Android (APK + iyzico/IBAN) ayrı kanallarda. Bir tarafa dokunmadan önce **mutlaka** [`docs/PLATFORM_ISOLATION.md`](docs/PLATFORM_ISOLATION.md) ve [`AGENTS.md`](AGENTS.md) okunmalı. iOS klasörü Android iş akışında, Android klasörü iOS iş akışında dokunulmaz.

## Development

Use the bundled Flutter SDK from the sibling Developer folder:

```bash
/Users/veyselkemal/Developer/flutterv2/flutter_sdk_3_41_9/bin/flutter pub get
/Users/veyselkemal/Developer/flutterv2/flutter_sdk_3_41_9/bin/flutter analyze
/Users/veyselkemal/Developer/flutterv2/flutter_sdk_3_41_9/bin/flutter test
```

## Docker

The Docker target builds Flutter web and serves it with nginx. Local secret
values belong in `.env.praticase`, which is ignored by Git.

```bash
docker compose up --build
```

Build-time auth configuration:

```bash
SUPABASE_URL=https://qlinik.medasi.com.tr
FLUTTER_SUPABASE_URL=https://qlinik.medasi.com.tr
SUPABASE_ANON_KEY=<public anon key>
AUTH_REDIRECT_URL=https://praticase.medasi.com.tr/auth/callback
```

Coolify domain target: `praticase.medasi.com.tr`.

## Self-Hosted Supabase And Edge Functions

PratiCase uses Supabase Edge Functions for live AI. Patient anamnesis turns use
`gemini-2.5-flash`, voice playback uses Gemini TTS, and final OSCE scoring uses
`gemini-3.5-flash`.
The Flutter build receives only `SUPABASE_URL`, `FLUTTER_SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `AUTH_REDIRECT_URL`; service-role, Vertex, and App
Store secrets remain in the self-hosted Edge Function runtime.

Required Edge Function secrets:

```bash
SUPABASE_URL=https://qlinik.medasi.com.tr
SUPABASE_ANON_KEY=<public anon key>
SUPABASE_SERVICE_ROLE_KEY=<edge-runtime only service role key>
PRATICASE_ALLOWED_ORIGINS=https://praticase.medasi.com.tr,https://www.praticase.medasi.com.tr
VERTEX_AI_PROJECT_ID=<google cloud project id>
VERTEX_AI_LOCATION=global
VERTEX_AI_HISTORY_MODEL=gemini-2.5-flash
VERTEX_AI_TTS_MODEL=gemini-2.5-flash-tts
VERTEX_AI_EVALUATION_MODEL=gemini-3.5-flash
GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON_BASE64=<base64 encoded service account json>
```

Keep the service account out of Flutter code, screenshots, logs, and committed
files. Set it only as a Supabase secret.

The deployment script applies PratiCase-owned migrations and publishes the six
PratiCase Edge Functions. It does not replace the shared Qlinik store function
or alter the Medasi payment contract used by the profile store flow.

```bash
scripts/deploy_self_hosted.sh
scripts/preflight_self_hosted.sh --remote
```

Auth email templates are shared by the Medasi Supabase Auth service. Use the
conditional templates in `supabase/auth-templates/` so PratiCase receives
OTP-first confirmation/recovery emails without replacing Qlinik's fallback
email flow. See `docs/praticase-auth-email-templates.md`.

## App Store Server API

PratiCase validates StoreKit purchases in `praticase-storekit-verify` using
Apple's App Store Server API and verifies Apple's signed transaction payload.
The App Store key must be injected into the Edge Function runtime only; never
place a `.p8` private key in Flutter assets or Git.

Required App Store Edge Function secrets:

```bash
PRATICASE_APP_STORE_BUNDLE_ID=com.medasi.praticase
PRATICASE_APP_STORE_APP_ID=<numeric app store app id>
PRATICASE_APP_STORE_KEY_ID=<in-app purchase key id>
PRATICASE_APP_STORE_ISSUER_ID=<issuer id from App Store Connect>
PRATICASE_APP_STORE_PRIVATE_KEY_BASE64=<base64 encoded AuthKey p8 contents>
```

These PratiCase-prefixed names intentionally do not consume or overwrite
Qlinik's existing App Store configuration. Reusing the same App Store key is
allowed by setting its values again under the PratiCase-prefixed variables.
Apple's public root certificates are bundled from Apple PKI for JWS
verification; `PRATICASE_APPLE_ROOT_CA_CERTIFICATES_BASE64` can override them
for rotation. PratiCase does not grant rights through the legacy shared-secret
receipt endpoint; StoreKit rights require signed App Store Server API
verification.

The shared Medasi wallet product remains in `public.store_products`. Do not
replace its Qlinik App Store product identifiers. Instead, after creating the
PratiCase products in App Store Connect, populate the PratiCase-owned mapping.
Add a row for every PratiCase package offered in Apple purchase flows,
including subscription, coin, and question-quota packages:

```sql
insert into praticase.store_product_app_mappings(product_code, app_store_product_id)
values
  ('weekly_subscription', '<com.medasi.praticase weekly product id>'),
  ('monthly_subscription', '<com.medasi.praticase monthly product id>')
on conflict (product_code) do update
set app_store_product_id = excluded.app_store_product_id,
    is_active = true,
    updated_at = now();
```

For renewable subscriptions, configure App Store Server Notifications V2 for
the PratiCase app to POST to:

```txt
https://qlinik.medasi.com.tr/functions/v1/praticase-storekit-verify
```

The notification handler verifies Apple's signed payload and updates shared
wallet rights only for PratiCase-linked purchases through the existing shared
wallet RPCs.

Local validation without exposing the key value:

```bash
chmod 600 /path/to/AuthKey_KEYID.p8
scripts/preflight_self_hosted.sh --app-store-key /path/to/AuthKey_KEYID.p8
scripts/flutter_praticase.sh build web --release
scripts/build_praticase_apk.sh
scripts/flutter_praticase.sh build ios --release --no-codesign
```
