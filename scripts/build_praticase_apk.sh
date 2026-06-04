#!/usr/bin/env bash
# Build a sideloadable PratiCase release APK for Android.
#
# Usage:
#   scripts/build_praticase_apk.sh             # universal release APK
#   scripts/build_praticase_apk.sh --split     # one APK per ABI (smaller)
#
# Outputs:
#   build/app/outputs/flutter-apk/app-release.apk
#   ~/Desktop/PratiCase-release.apk
# (or PratiCase-<abi>-release.apk variants when --split is used).
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
OUTPUT_DIR="${PRATICASE_APK_OUTPUT_DIR:-$HOME/Desktop}"

"$ROOT_DIR/scripts/sync_praticase_env.sh" --dart-defines-only >/dev/null
if [[ ! -f "$ROOT_DIR/.dart_tool/package_config.json" ]]; then
  echo "Flutter dependencies are missing. Run flutter pub get before building the APK." >&2
  exit 1
fi

cd "$ROOT_DIR"
if [[ "${1:-}" == "--split" ]]; then
  "$FLUTTER_BIN" build apk --release --no-pub \
    --dart-define-from-file="$DEFINE_FILE" \
    --split-per-abi
  mkdir -p "$OUTPUT_DIR"
  for apk in "$ROOT_DIR"/build/app/outputs/flutter-apk/app-*-release.apk; do
    cp "$apk" "$OUTPUT_DIR/PratiCase-${apk##*/app-}"
  done
  printf 'APK files copied to %s/PratiCase-*-release.apk\n' "$OUTPUT_DIR"
else
  "$FLUTTER_BIN" build apk --release --no-pub \
    --dart-define-from-file="$DEFINE_FILE"
  mkdir -p "$OUTPUT_DIR"
  cp "$ROOT_DIR/build/app/outputs/flutter-apk/app-release.apk" \
    "$OUTPUT_DIR/PratiCase-release.apk"
  printf 'APK copied to %s/PratiCase-release.apk\n' "$OUTPUT_DIR"
fi
