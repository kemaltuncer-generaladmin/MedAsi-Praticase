#!/usr/bin/env bash
# Build a sideloadable PratiCase release APK for Android.
#
# Usage:
#   scripts/build_praticase_apk.sh             # universal release APK
#   scripts/build_praticase_apk.sh --split     # one APK per ABI (smaller)
#
# Output: build/app/outputs/flutter-apk/app-release.apk
# (or app-<abi>-release.apk variants when --split is used).
#
# If android/key.properties is missing the release APK is signed with the
# debug key — fine for sideload / maestro QA, NOT fine for Play Store.
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

cd "$ROOT_DIR"
if [[ "${1:-}" == "--split" ]]; then
  exec "$FLUTTER_BIN" build apk --release \
    --dart-define-from-file="$DEFINE_FILE" \
    --split-per-abi
else
  exec "$FLUTTER_BIN" build apk --release \
    --dart-define-from-file="$DEFINE_FILE"
fi
