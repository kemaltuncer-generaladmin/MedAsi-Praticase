#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND_ENV="${PRATICASE_ENV_FILE:-$ROOT_DIR/.env.praticase}"
DEPLOY_ENV="${PRATICASE_DEPLOY_ENV_FILE:-$ROOT_DIR/.env.deploy.local}"
CHECK_REMOTE=false
APP_STORE_KEY_FILE=""

usage() {
  cat <<'EOF'
Usage: scripts/preflight_self_hosted.sh [--remote] [--app-store-key /path/to/AuthKey_*.p8]

Checks release configuration without printing secret values or changing the
self-hosted Supabase instance. Pass --remote to inspect the deployed Edge
Function container and applied release migration over SSH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      CHECK_REMOTE=true
      shift
      ;;
    --app-store-key)
      APP_STORE_KEY_FILE="${2:-}"
      [[ -n "$APP_STORE_KEY_FILE" ]] || {
        echo "Missing value for --app-store-key." >&2
        exit 2
      }
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

failures=0
pass() { printf 'ok    %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*" >&2; failures=$((failures + 1)); }

check_set() {
  local label="$1"
  local value="${!label:-}"
  if [[ -n "$value" ]]; then
    pass "$label is configured"
  else
    fail "$label is missing"
  fi
}

printf '\nFlutter public configuration\n'
if [[ ! -f "$FRONTEND_ENV" ]]; then
  fail "$FRONTEND_ENV is missing"
else
  set -a
  # shellcheck disable=SC1090
  source "$FRONTEND_ENV"
  set +a
  check_set SUPABASE_URL
  check_set SUPABASE_ANON_KEY
  check_set AUTH_REDIRECT_URL
fi

printf '\nLocal release assets\n'
for file in \
  "$ROOT_DIR/supabase/functions/praticase-patient-turn/index.ts" \
  "$ROOT_DIR/supabase/functions/praticase-complete-session/index.ts" \
  "$ROOT_DIR/supabase/functions/praticase-theoretical-exam/index.ts" \
  "$ROOT_DIR/supabase/functions/praticase-oral-exam/index.ts" \
  "$ROOT_DIR/supabase/functions/praticase-storekit-verify/index.ts" \
  "$ROOT_DIR/supabase/functions/_shared/apple_root_certificates.ts" \
  "$ROOT_DIR/supabase/migrations/202605240011_praticase_release_copy_hardening.sql" \
  "$ROOT_DIR/supabase/migrations/202605240012_praticase_store_product_mappings.sql"; do
  if [[ -f "$file" ]]; then
    pass "${file#"$ROOT_DIR/"} is present"
  else
    fail "${file#"$ROOT_DIR/"} is missing"
  fi
done

if [[ -n "$APP_STORE_KEY_FILE" ]]; then
  if [[ -f "$APP_STORE_KEY_FILE" ]] &&
    grep -q "BEGIN PRIVATE KEY" "$APP_STORE_KEY_FILE"; then
    pass "App Store private key file is readable and PEM formatted"
  else
    fail "App Store private key file is missing or not PEM formatted"
  fi
fi

if command -v deno >/dev/null 2>&1; then
  if deno check \
    "$ROOT_DIR/supabase/functions/praticase-patient-turn/index.ts" \
    "$ROOT_DIR/supabase/functions/praticase-complete-session/index.ts" \
    "$ROOT_DIR/supabase/functions/praticase-theoretical-exam/index.ts" \
    "$ROOT_DIR/supabase/functions/praticase-oral-exam/index.ts" \
    "$ROOT_DIR/supabase/functions/praticase-storekit-verify/index.ts" \
    >/dev/null; then
    pass "Edge Functions pass deno check"
  else
    fail "Edge Functions fail deno check"
  fi
else
  fail "deno is unavailable for Edge Function verification"
fi

if [[ "$CHECK_REMOTE" == true ]]; then
  printf '\nSelf-hosted Supabase runtime\n'
  if [[ -f "$DEPLOY_ENV" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$DEPLOY_ENV"
    set +a
  fi
  DEPLOY_HOST="${PRATICASE_DEPLOY_HOST:-}"
  SERVICE_DIR="${PRATICASE_SUPABASE_SERVICE_DIR:-}"
  DB_CONTAINER="${PRATICASE_SUPABASE_DB_CONTAINER:-}"
  EDGE_CONTAINER="${PRATICASE_SUPABASE_EDGE_CONTAINER:-}"
  if [[ -z "$DEPLOY_HOST" || -z "$SERVICE_DIR" || -z "$DB_CONTAINER" ||
    -z "$EDGE_CONTAINER" ]]; then
    fail "Self-hosted deploy connection configuration is incomplete"
  elif ! ssh -o BatchMode=yes "$DEPLOY_HOST" bash -s -- \
    "$EDGE_CONTAINER" "$DB_CONTAINER" "$SERVICE_DIR/volumes/functions" <<'REMOTE'
set -euo pipefail
edge_container="$1"
db_container="$2"
functions_dir="$3"
missing=0
required_secrets=(SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY)
for key in "${required_secrets[@]}"; do
  if docker exec "$edge_container" sh -lc "test -n \"\${$key:-}\""; then
    printf 'ok    Edge secret %s is configured\n' "$key"
  else
    printf 'FAIL  Edge secret %s is missing\n' "$key" >&2
    missing=1
  fi
done
check_any() {
  local label="$1"
  shift
  local key
  for key in "$@"; do
    if docker exec "$edge_container" sh -lc "test -n \"\${$key:-}\""; then
      printf 'ok    %s is configured through %s\n' "$label" "$key"
      return
    fi
  done
  printf 'FAIL  %s is missing\n' "$label" >&2
  missing=1
}
check_any "Vertex service account" \
  GOOGLE_VERTEX_SERVICE_ACCOUNT_JSON_BASE64 \
  VERTEX_AI_SERVICE_ACCOUNT_JSON_BASE64 \
  GOOGLE_SERVICE_ACCOUNT_JSON_BASE64
required_praticase_store_secrets=(
  PRATICASE_APP_STORE_BUNDLE_ID
  PRATICASE_APP_STORE_APP_ID
  PRATICASE_APP_STORE_KEY_ID
  PRATICASE_APP_STORE_ISSUER_ID
  PRATICASE_APP_STORE_PRIVATE_KEY_BASE64
)
for key in "${required_praticase_store_secrets[@]}"; do
  if docker exec "$edge_container" sh -lc "test -n \"\${$key:-}\""; then
    printf 'ok    Edge secret %s is configured\n' "$key"
  else
    printf 'FAIL  Edge secret %s is missing\n' "$key" >&2
    missing=1
  fi
done
for function_name in \
  praticase-patient-turn \
  praticase-complete-session \
  praticase-theoretical-exam \
  praticase-oral-exam \
  praticase-storekit-verify; do
  if test -f "$functions_dir/$function_name/index.ts"; then
    printf 'ok    Function %s is published\n' "$function_name"
  else
    printf 'FAIL  Function %s is not published\n' "$function_name" >&2
    missing=1
  fi
done
if test -f "$functions_dir/_shared/apple_root_certificates.ts"; then
  printf 'ok    Apple public trust anchors are published\n'
else
  printf 'FAIL  Apple public trust anchors are not published\n' >&2
  missing=1
fi
mapping_migration_applied=false
for version in \
  202605240011_praticase_release_copy_hardening \
  202605240012_praticase_store_product_mappings; do
  if docker exec "$db_container" psql -U supabase_admin -d postgres -Atqc \
    "select 1 from praticase.self_hosted_schema_migrations where version = '$version' limit 1;" \
    | grep -q '^1$'; then
    printf 'ok    Migration %s is applied\n' "$version"
    if [[ "$version" == "202605240012_praticase_store_product_mappings" ]]; then
      mapping_migration_applied=true
    fi
  else
    printf 'FAIL  Migration %s is not applied\n' "$version" >&2
    missing=1
  fi
done
if [[ "$mapping_migration_applied" == true ]]; then
  mapping_count="$(docker exec "$db_container" psql -U supabase_admin -d postgres -Atqc \
    "select count(*) from praticase.store_product_app_mappings where is_active and app_store_product_id like 'com.medasi.praticase.%';")"
  if [[ "$mapping_count" =~ ^[1-9][0-9]*$ ]]; then
    printf 'ok    %s PratiCase App Store product mapping(s) are active\n' "$mapping_count"
  else
    printf 'FAIL  No active PratiCase App Store product mappings are configured\n' >&2
    missing=1
  fi
fi
exit "$missing"
REMOTE
  then
    fail "Self-hosted runtime is not release-ready"
  else
    pass "Self-hosted runtime release checks passed"
  fi
fi

printf '\n'
if [[ "$failures" -gt 0 ]]; then
  printf 'Preflight failed; review the FAIL items above.\n' >&2
  exit 1
fi
printf 'Preflight passed.\n'
