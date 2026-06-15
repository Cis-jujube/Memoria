#!/bin/bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Memorial"
LEGACY_APP_NAME="MemoriaMac"
BUNDLE_ID="com.jujube.memorial"
MIN_SYSTEM_VERSION="14.0"

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

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$LEGACY_APP_NAME" >/dev/null 2>&1 || true

(
  cd "$PACKAGE_DIR"
  swift build --product "$APP_NAME"
)

BUILD_BINARY="$(cd "$PACKAGE_DIR" && swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE" "$DIST_DIR/$LEGACY_APP_NAME.app"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
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
  <key>CFBundleIconFile</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE" >/dev/null 2>&1 || true
  sleep 2
  if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    (
      cd "$ROOT_DIR"
      nohup "$BUILD_BINARY" >"$DIST_DIR/$APP_NAME.log" 2>&1 &
      echo $! >"$DIST_DIR/$APP_NAME.pid"
    )
    sleep 2
  fi

  if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    echo "$APP_NAME did not stay running. Last direct-launch log:" >&2
    tail -n 40 "$DIST_DIR/$APP_NAME.log" >&2 || true
    exit 1
  fi
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    (
      cd "$PACKAGE_DIR"
      swift run MemoriaProtocolChecks
    )
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
