#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="IPRegionTray"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/release"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c release --arch arm64

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

chmod +x "$MACOS_DIR/$APP_NAME"
if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "Built $APP_DIR"
