#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_ENV_FILE="${PRATICASE_DEPLOY_ENV_FILE:-$ROOT_DIR/.env.deploy.local}"

if [[ -f "$LOCAL_ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$LOCAL_ENV_FILE"
  set +a
fi

DEPLOY_HOST="${PRATICASE_DEPLOY_HOST:-root@46.225.100.139}"
SERVICE_DIR="${PRATICASE_SUPABASE_SERVICE_DIR:-/data/coolify/services/yiqde9ihk4ud8gxrymld1jx7}"
DB_CONTAINER="${PRATICASE_SUPABASE_DB_CONTAINER:-supabase-db-yiqde9ihk4ud8gxrymld1jx7}"
EDGE_CONTAINER="${PRATICASE_SUPABASE_EDGE_CONTAINER:-supabase-edge-functions-yiqde9ihk4ud8gxrymld1jx7}"
COOLIFY_BASE_URL="${COOLIFY_BASE_URL:-http://46.225.100.139:8000}"
COOLIFY_APP_UUID="${COOLIFY_APP_UUID:-s6zu97f2zaxuft1fng09f881}"

REMOTE_TMP="/tmp/praticase-deploy"
REMOTE_MIGRATIONS="$REMOTE_TMP/migrations"
REMOTE_FUNCTIONS="$REMOTE_TMP/functions"
REMOTE_SQL_TMP="/tmp/praticase-migrations"
REMOTE_FUNCTIONS_DIR="$SERVICE_DIR/volumes/functions"

log() {
  printf '\n==> %s\n' "$*"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_cmd ssh
require_cmd scp
require_cmd curl

log "Preparing remote deploy workspace"
ssh -o BatchMode=yes "$DEPLOY_HOST" "mkdir -p '$REMOTE_MIGRATIONS' '$REMOTE_FUNCTIONS' '$REMOTE_SQL_TMP'"

log "Uploading migrations"
scp -o BatchMode=yes "$ROOT_DIR"/supabase/migrations/*.sql "$DEPLOY_HOST:$REMOTE_MIGRATIONS/"

log "Applying unapplied migrations"
ssh -o BatchMode=yes "$DEPLOY_HOST" "set -euo pipefail
docker exec '$DB_CONTAINER' psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -qc \"
create schema if not exists praticase;
create table if not exists praticase.self_hosted_schema_migrations (
  version text primary key,
  filename text not null,
  applied_at timestamptz not null default now()
);
\"
docker cp '$REMOTE_MIGRATIONS/.' '$DB_CONTAINER:$REMOTE_SQL_TMP/'
for file in '$REMOTE_MIGRATIONS'/*.sql; do
  filename=\$(basename \"\$file\")
  version=\${filename%.sql}
  applied=\$(docker exec '$DB_CONTAINER' psql -U supabase_admin -d postgres -Atqc \"select 1 from praticase.self_hosted_schema_migrations where version = '\$version' limit 1;\")
  if [[ \"\$applied\" == \"1\" ]]; then
    echo \"skip migration \$filename\"
    continue
  fi

  echo \"apply migration \$filename\"
  docker exec '$DB_CONTAINER' psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -f '$REMOTE_SQL_TMP'/\"\$filename\"
  docker exec '$DB_CONTAINER' psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -qc \"insert into praticase.self_hosted_schema_migrations(version, filename) values ('\$version', '\$filename') on conflict (version) do nothing;\"
done"

log "Uploading Edge Functions"
scp -o BatchMode=yes -r \
  "$ROOT_DIR/supabase/functions/_shared" \
  "$ROOT_DIR/supabase/functions/praticase-patient-turn" \
  "$ROOT_DIR/supabase/functions/praticase-complete-session" \
  "$ROOT_DIR/supabase/functions/praticase-theoretical-exam" \
  "$ROOT_DIR/supabase/functions/praticase-storekit-verify" \
  "$ROOT_DIR/supabase/functions/praticase-oral-exam" \
  "$DEPLOY_HOST:$REMOTE_FUNCTIONS/"

log "Publishing Edge Functions"
ssh -o BatchMode=yes "$DEPLOY_HOST" "set -euo pipefail
cp -R '$REMOTE_FUNCTIONS/_shared' '$REMOTE_FUNCTIONS_DIR/'
cp -R '$REMOTE_FUNCTIONS/praticase-patient-turn' '$REMOTE_FUNCTIONS_DIR/'
cp -R '$REMOTE_FUNCTIONS/praticase-complete-session' '$REMOTE_FUNCTIONS_DIR/'
cp -R '$REMOTE_FUNCTIONS/praticase-theoretical-exam' '$REMOTE_FUNCTIONS_DIR/'
cp -R '$REMOTE_FUNCTIONS/praticase-storekit-verify' '$REMOTE_FUNCTIONS_DIR/'
cp -R '$REMOTE_FUNCTIONS/praticase-oral-exam' '$REMOTE_FUNCTIONS_DIR/'
docker restart '$EDGE_CONTAINER' >/dev/null
docker ps --filter name='$EDGE_CONTAINER' --format '{{.Names}}\t{{.Status}}'"

if [[ -n "${COOLIFY_API_TOKEN:-}" ]]; then
  log "Triggering Coolify web deploy"
  curl -fsS \
    -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
    "$COOLIFY_BASE_URL/api/v1/deploy?uuid=$COOLIFY_APP_UUID&force=true"
  echo
else
  log "Skipping Coolify deploy because COOLIFY_API_TOKEN is not set"
fi

log "Checking public web endpoint"
curl -fsS -I --max-time 10 https://praticase.medasi.com.tr/ | sed -n '1,12p'

log "Done"
