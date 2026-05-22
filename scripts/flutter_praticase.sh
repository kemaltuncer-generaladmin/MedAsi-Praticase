#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SDK_ROOT="${SDK_ROOT:-$HOME/SDKlar}"
if [[ ! -d "$SDK_ROOT" ]]; then
  SDK_ROOT="$(find "$HOME" -maxdepth 1 -type d -name "SDK*lar" | head -n 1)"
fi
if [[ -n "$SDK_ROOT" && -x "$SDK_ROOT/flutter/current/bin/flutter" ]]; then
  FLUTTER_BIN="${FLUTTER_BIN:-$SDK_ROOT/flutter/current/bin/flutter}"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi
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
