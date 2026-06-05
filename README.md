# PratiCase

PratiCase is the OSCE simulation application in the Medasi ecosystem. It is a Flutter-first, iPhone-oriented product for virtual patient interviews, timed stations, structured clinical actions, and rubric-based score reports.

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

PratiCase uses Supabase Edge Functions for live AI. Patient anamnesis turns,
oral exam moderation, recall guidance, and final OSCE scoring use OpenAI
`gpt-4o-mini`. Voice playback uses OpenAI `gpt-4o-mini-tts`.
The Flutter build receives only `SUPABASE_URL`, `FLUTTER_SUPABASE_URL`,
`SUPABASE_ANON_KEY`, and `AUTH_REDIRECT_URL`; service-role, OpenAI, and App
Store secrets remain in the self-hosted Edge Function runtime.

Required Edge Function secrets:

```bash
SUPABASE_URL=https://qlinik.medasi.com.tr
SUPABASE_ANON_KEY=<public anon key>
SUPABASE_SERVICE_ROLE_KEY=<edge-runtime only service role key>
PRATICASE_ALLOWED_ORIGINS=https://praticase.medasi.com.tr,https://www.praticase.medasi.com.tr
OPENAI_API_KEY=<server-side OpenAI API key>
OPENAI_MODEL=gpt-4o-mini
OPENAI_TTS_MODEL=gpt-4o-mini-tts
OPENAI_TTS_VOICE=alloy
```

AI coin charging is OpenAI/model aware. Defaults follow standard OpenAI text
pricing for `gpt-4o-mini`, and can be overridden from the Edge Function
environment if pricing changes:

```bash
MEDASI_COIN_TL_VALUE=0.30
MEDASI_AI_COIN_USAGE_MULTIPLIER=1.35
OPENAI_GPT_4O_MINI_INPUT_USD_PER_M=0.15
OPENAI_GPT_4O_MINI_CACHED_INPUT_USD_PER_M=0.075
OPENAI_GPT_4O_MINI_OUTPUT_USD_PER_M=0.60
OPENAI_GPT_4O_INPUT_USD_PER_M=2.50
OPENAI_GPT_4O_CACHED_INPUT_USD_PER_M=1.25
OPENAI_GPT_4O_OUTPUT_USD_PER_M=10.00
```

Keep OpenAI and service-role secrets out of Flutter code, screenshots, logs,
and committed files. Set them only as Supabase Edge Function secrets.

## Web Bank Transfer And Android Google Play Payments

Web package selections create a MedAsi Pay checkout session and open
`https://odeme.medasi.com.tr` for IBAN transfer and receipt upload. Android
uses Google Play Billing for in-app digital wallet packages. iOS continues to
use StoreKit only; no bank-transfer navigation is displayed in the iOS purchase
flow.

Required Edge Function secrets for MedAsi Pay:

```bash
MEDASIPAY_API_URL=https://odeme.medasi.com.tr
MEDASIPAY_API_KEY=<service checkout key>
MEDASIPAY_WEBHOOK_SECRET=<shared webhook signature secret>
PRATICASE_PAYMENT_RETURN_URL=https://praticase.medasi.com.tr/
PRATICASE_PAYMENT_WEBHOOK_URL=https://qlinik.medasi.com.tr/functions/v1/praticase-storekit-verify
```

The checkout payload carries the selected live package snapshot, including
`entitlement_kind` and `duration_days`. After receipt approval, the signed
webhook grants the same shared Medasi wallet product. A subscription uses its
configured validity period and is not automatically renewed by bank transfer;
a one-time purchase uses its configured validity period as well.

Required Edge Function secrets for Google Play purchase verification:

```bash
PRATICASE_GOOGLE_PLAY_PACKAGE_NAME=com.medasi.praticase
PRATICASE_GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64=<base64 service account json>
```

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
