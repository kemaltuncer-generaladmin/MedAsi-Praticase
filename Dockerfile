FROM ghcr.io/cirruslabs/flutter:3.41.9 AS build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
ARG SUPABASE_URL=https://qlinik.medasi.com.tr
ARG FLUTTER_SUPABASE_URL=https://qlinik.medasi.com.tr
ARG SUPABASE_ANON_KEY=
ARG AUTH_REDIRECT_URL=https://praticase.medasi.com.tr/auth/callback
RUN flutter build web --release --output build/web \
  --dart-define=SUPABASE_URL=${SUPABASE_URL} \
  --dart-define=FLUTTER_SUPABASE_URL=${FLUTTER_SUPABASE_URL} \
  --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY} \
  --dart-define=AUTH_REDIRECT_URL=${AUTH_REDIRECT_URL}

FROM nginx:1.27-alpine

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/healthz || exit 1
