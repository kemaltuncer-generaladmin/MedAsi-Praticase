#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-/Users/veyselkemal/Developer/flutterv2/flutter_sdk_3_41_9/bin/flutter}"
DEFINE_FILE="$ROOT_DIR/.dart_tool/praticase_env.json"

"$ROOT_DIR/scripts/sync_praticase_env.sh" >/dev/null

case "${1:-}" in
  run|build|test|drive)
    exec "$FLUTTER_BIN" "$@" --dart-define-from-file="$DEFINE_FILE"
    ;;
  *)
    exec "$FLUTTER_BIN" "$@"
    ;;
esac
