#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-v0.1.0}"
APP_NAME="Memorial"
BUNDLE_ID="com.jujube.memorial"
MIN_SYSTEM_VERSION="14.0"
RELEASE_BASENAME="Memoria-macOS-arm64"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/macos"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/macos/Resources/AppIcon/MemoriaMac.icns"
APP_ICON_FILE="$APP_NAME.icns"
ZIP_PATH="$DIST_DIR/$RELEASE_BASENAME.zip"
DMG_PATH="$DIST_DIR/$RELEASE_BASENAME.dmg"
HYBRID_DMG_PATH="$DIST_DIR/$RELEASE_BASENAME.hybrid.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"
NOTES_PATH="$DIST_DIR/release-notes-$VERSION.md"
DMG_STAGING="$DIST_DIR/dmg-staging"
VERSION_NUMBER="${VERSION#v}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command swift
require_command codesign
require_command ditto
require_command hdiutil
require_command shasum

rm -rf "$APP_BUNDLE" "$DMG_STAGING"
rm -f "$ZIP_PATH" "$DMG_PATH" "$HYBRID_DMG_PATH" "$CHECKSUM_PATH" "$NOTES_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DIST_DIR"

(
  cd "$PACKAGE_DIR"
  swift build -c release --product "$APP_NAME"
)

BUILD_BINARY="$(cd "$PACKAGE_DIR" && swift build -c release --show-bin-path)/$APP_NAME"

cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/$APP_ICON_FILE"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Memoria</string>
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION_NUMBER</string>
  <key>CFBundleVersion</key>
  <string>$VERSION_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

mkdir -p "$DMG_STAGING"
ditto "$APP_BUNDLE" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"
hdiutil makehybrid \
  -hfs \
  -hfs-volume-name "Memoria" \
  -o "$HYBRID_DMG_PATH" \
  "$DMG_STAGING"
hdiutil convert "$HYBRID_DMG_PATH" -format UDZO -o "$DMG_PATH"
rm -f "$HYBRID_DMG_PATH"
rm -rf "$DMG_STAGING"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" "$(basename "$DMG_PATH")" >"$(basename "$CHECKSUM_PATH")"
)

cat >"$NOTES_PATH" <<NOTES
# Memoria macOS Preview $VERSION

This is the first public macOS preview release for Memoria.

## Downloads

- Memoria-macOS-arm64.dmg: recommended for most Mac users.
- Memoria-macOS-arm64.zip: direct app bundle archive.
- SHA256SUMS.txt: checksums for both release assets.

## Requirements

- Apple Silicon Mac
- macOS 14 or later

## Install

Open the DMG and drag Memorial.app into Applications, or unzip the ZIP and open Memorial.app.

This build is ad-hoc signed and not Apple-notarized yet. If macOS blocks the first launch, right-click Memorial.app, choose Open, then confirm.

## Privacy

Memoria stores relationship data locally in SQLite. DeepSeek API keys are entered by the user in Settings and stored in macOS Keychain.
NOTES

echo "Created release artifacts:"
echo "  $APP_BUNDLE"
echo "  $ZIP_PATH"
echo "  $DMG_PATH"
echo "  $CHECKSUM_PATH"
echo "  $NOTES_PATH"
