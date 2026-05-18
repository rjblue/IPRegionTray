#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.1.0}"
PACKAGE_NAME="IPRegionTray-$VERSION"
ZIP_NAME="$PACKAGE_NAME-mac-arm64.zip"
RELEASE_DIR="$ROOT_DIR/release/$PACKAGE_NAME"
RELEASE_NOTES_FILE="RELEASE_NOTES_v$VERSION.md"
if [[ ! -f "$ROOT_DIR/$RELEASE_NOTES_FILE" ]]; then
    RELEASE_NOTES_FILE="RELEASE_NOTES_v1.0.0.md"
fi

cd "$ROOT_DIR"
"$ROOT_DIR/scripts/build-app.sh"

rm -rf "$RELEASE_DIR" "$ROOT_DIR/release/$ZIP_NAME"
mkdir -p "$RELEASE_DIR/source" "$RELEASE_DIR/app" "$RELEASE_DIR/executable" "$RELEASE_DIR/docs"

cp Package.swift README.md README.zh-CN.md LICENSE CHANGELOG.md "$RELEASE_NOTES_FILE" .gitignore "$RELEASE_DIR/source/"
cp -R .github Sources Resources scripts docs "$RELEASE_DIR/source/"
cp -R dist/IPRegionTray.app "$RELEASE_DIR/app/"
cp dist/IPRegionTray.app/Contents/MacOS/IPRegionTray "$RELEASE_DIR/executable/IPRegionTray-arm64"
cp README.md README.zh-CN.md CHANGELOG.md "$RELEASE_NOTES_FILE" docs/USER_GUIDE.md docs/USER_GUIDE.zh-CN.md docs/DEV_GUIDE.md docs/DEV_GUIDE.zh-CN.md "$RELEASE_DIR/docs/"

chmod +x "$RELEASE_DIR/executable/IPRegionTray-arm64"
(
    cd "$RELEASE_DIR"
    find . -type f ! -name SHA256SUMS.txt -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS.txt
)

(
    cd "$ROOT_DIR/release"
    zip -r -X "$ZIP_NAME" "$PACKAGE_NAME" >/dev/null
)

echo "Created $ROOT_DIR/release/$ZIP_NAME"
