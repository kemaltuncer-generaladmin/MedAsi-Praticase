#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COOLIFY_BASE_URL="${COOLIFY_BASE_URL:-http://46.225.100.139:8000}"
COOLIFY_APP_UUID="${COOLIFY_APP_UUID:-s6zu97f2zaxuft1fng09f881}"
ENV_FILE="${PRATICASE_ENV_FILE:-$ROOT_DIR/.env.praticase}"

if [[ -z "${COOLIFY_API_TOKEN:-}" ]]; then
  echo "COOLIFY_API_TOKEN is required." >&2
  exit 1
fi

curl -fsS \
  -H "Authorization: Bearer $COOLIFY_API_TOKEN" \
  -H "Accept: application/json" \
  "$COOLIFY_BASE_URL/api/v1/applications/$COOLIFY_APP_UUID/envs" \
  | jq -r '
      map(select((.is_preview // false) == false))
      | unique_by(.key)
      | .[]
      | select(.key | IN(
          "SUPABASE_URL",
          "FLUTTER_SUPABASE_URL",
          "SUPABASE_ANON_KEY",
          "AUTH_REDIRECT_URL",
          "OPENAI_API_KEY",
          "OPENAI_MODEL",
          "OPENAI_TTS_MODEL",
          "OPENAI_TTS_VOICE"
        ))
      | "\(.key)=\(.real_value // .value)"
    ' > "$ENV_FILE"

chmod 600 "$ENV_FILE"
"$ROOT_DIR/scripts/sync_praticase_env.sh"
