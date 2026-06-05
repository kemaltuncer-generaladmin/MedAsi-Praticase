#!/usr/bin/env bash
# Build a signed Android App Bundle for Google Play.
#
# Output:
#   build/app/outputs/bundle/release/app-release.aab
#   ~/Desktop/PratiCase-<version>-playstore.aab
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
OUTPUT_DIR="${PRATICASE_AAB_OUTPUT_DIR:-$HOME/Desktop}"
KEY_PROPERTIES="$ROOT_DIR/android/key.properties"

if [[ ! -f "$KEY_PROPERTIES" ]]; then
  echo "android/key.properties is required for a Play Store signed AAB." >&2
  exit 1
fi

STORE_FILE="$(
  awk -F= '/^storeFile=/ {gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
    "$KEY_PROPERTIES"
)"
if [[ "$STORE_FILE" = /* ]]; then
  STORE_FILE_PATH="$STORE_FILE"
else
  STORE_FILE_PATH="$ROOT_DIR/android/$STORE_FILE"
fi
if [[ -z "$STORE_FILE" || ! -f "$STORE_FILE_PATH" ]]; then
  echo "Release keystore referenced by android/key.properties was not found." >&2
  exit 1
fi

"$ROOT_DIR/scripts/sync_praticase_env.sh" --dart-defines-only >/dev/null
if [[ ! -f "$ROOT_DIR/.dart_tool/package_config.json" ]]; then
  echo "Flutter dependencies are missing. Run flutter pub get before release." >&2
  exit 1
fi

cd "$ROOT_DIR"
"$FLUTTER_BIN" build appbundle --release --no-pub \
  --dart-define-from-file="$DEFINE_FILE"

VERSION="$(
  awk '/^version:/ {print $2; exit}' "$ROOT_DIR/pubspec.yaml" |
    tr '+/' '--'
)"
mkdir -p "$OUTPUT_DIR"
cp "$ROOT_DIR/build/app/outputs/bundle/release/app-release.aab" \
  "$OUTPUT_DIR/PratiCase-${VERSION}-playstore.aab"

printf 'AAB copied to %s/PratiCase-%s-playstore.aab\n' "$OUTPUT_DIR" "$VERSION"
