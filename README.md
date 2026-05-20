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

The Docker target builds Flutter web and serves it with nginx:

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
