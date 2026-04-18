#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$BUILD_DIR/Build/Products/Release/ThrottleBar.app"
ZIP_PATH="$DIST_DIR/ThrottleBar-macOS.zip"

cd "$ROOT_DIR"
rm -rf "$BUILD_DIR" "$DIST_DIR"

xcodegen generate
xcodebuild \
  -scheme ThrottleBar \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

mkdir -p "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
printf 'Created %s\n' "$ZIP_PATH"

