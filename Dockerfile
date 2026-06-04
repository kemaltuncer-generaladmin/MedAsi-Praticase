# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
ARG SUPABASE_URL=https://qlinik.medasi.com.tr
ARG FLUTTER_SUPABASE_URL=https://qlinik.medasi.com.tr
ARG SUPABASE_ANON_KEY=
ARG AUTH_REDIRECT_URL=https://praticase.medasi.com.tr/auth/callback
ARG PRIVACY_POLICY_URL=https://praticase.medasi.com.tr/legal/privacy.html
ARG TERMS_URL=https://praticase.medasi.com.tr/legal/terms.html
ARG STUDY_TERMS_URL=https://praticase.medasi.com.tr/legal/study-terms.html
ARG PURCHASE_TERMS_URL=https://praticase.medasi.com.tr/legal/purchase-terms.html
RUN --mount=type=secret,id=praticase_env \
  set -eu; \
  if [ -f /run/secrets/praticase_env ]; then . /run/secrets/praticase_env; fi; \
  flutter build web --release --output build/web \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qlinik.medasi.com.tr}" \
    --dart-define=FLUTTER_SUPABASE_URL="${FLUTTER_SUPABASE_URL:-https://qlinik.medasi.com.tr}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
    --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://praticase.medasi.com.tr/auth/callback}" \
    --dart-define=PRIVACY_POLICY_URL="${PRIVACY_POLICY_URL:-https://praticase.medasi.com.tr/legal/privacy.html}" \
    --dart-define=TERMS_URL="${TERMS_URL:-https://praticase.medasi.com.tr/legal/terms.html}" \
    --dart-define=STUDY_TERMS_URL="${STUDY_TERMS_URL:-https://praticase.medasi.com.tr/legal/study-terms.html}" \
    --dart-define=PURCHASE_TERMS_URL="${PURCHASE_TERMS_URL:-https://praticase.medasi.com.tr/legal/purchase-terms.html}"; \
  cp web/flutter_service_worker.js build/web/flutter_service_worker.js; \
  test -s build/web/main.dart.js; \
  WEB_REVISION="$(sha256sum build/web/main.dart.js | cut -c1-12)"; \
  test -n "$WEB_REVISION"; \
  sed -i "s#flutter_bootstrap.js#flutter_bootstrap.js?v=${WEB_REVISION}#" build/web/index.html; \
  sed -i "s#main.dart.js#main.dart.js?v=${WEB_REVISION}#g" build/web/flutter_bootstrap.js; \
  sed -i "s#serviceWorkerVersion: \"\\([0-9][0-9]*\\)\"#serviceWorkerVersion: \"\\1-${WEB_REVISION}\"#" build/web/flutter_bootstrap.js

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
