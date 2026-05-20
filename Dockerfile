# syntax=docker/dockerfile:1.7

FROM ghcr.io/cirruslabs/flutter:3.41.9 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN --mount=type=secret,id=praticase_env \
  if [ -f /run/secrets/praticase_env ]; then . /run/secrets/praticase_env; fi; \
  flutter build web --release --output build/web \
    --dart-define=SUPABASE_URL="${SUPABASE_URL:-https://qlinik.medasi.com.tr}" \
    --dart-define=FLUTTER_SUPABASE_URL="${FLUTTER_SUPABASE_URL:-https://qlinik.medasi.com.tr}" \
    --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
    --dart-define=AUTH_REDIRECT_URL="${AUTH_REDIRECT_URL:-https://praticase.medasi.com.tr/auth/callback}"

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
