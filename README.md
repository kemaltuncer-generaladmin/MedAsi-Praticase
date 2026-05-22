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

## Vertex AI Edge Functions

PratiCase uses Supabase Edge Functions for live AI. Patient anamnesis turns use
`gemini-2.5-flash`; final OSCE scoring uses `gemini-3.5-flash`.

Required Edge Function secrets:

```bash
VERTEX_AI_LOCATION=global
VERTEX_AI_HISTORY_MODEL=gemini-2.5-flash
VERTEX_AI_EVALUATION_MODEL=gemini-3.5-flash
GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON_BASE64=<base64 encoded service account json>
```

Keep the service account out of Flutter code, screenshots, logs, and committed
files. Set it only as a Supabase secret.
