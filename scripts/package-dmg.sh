#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.1.0}"
BUILD_ROOT="$ROOT_DIR/.build/mountguard-release"
APP_ROOT="$BUILD_ROOT/MountGuard.app"
APP_CONTENTS="$APP_ROOT/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/MountGuard-${VERSION}.dmg"
STAGING_DIR="$BUILD_ROOT/dmg-root"

rm -rf "$BUILD_ROOT" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$DIST_DIR" "$STAGING_DIR"

swift build -c release --product MountGuardApp --disable-sandbox

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path '*/release/MountGuardApp' -type f | head -n 1)"
if [[ -z "${EXECUTABLE_PATH}" ]]; then
  echo "Release executable not found." >&2
  exit 1
fi

cp "$EXECUTABLE_PATH" "$APP_MACOS/MountGuardApp"
chmod +x "$APP_MACOS/MountGuardApp"

cat > "$APP_CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>MountGuard</string>
    <key>CFBundleExecutable</key>
    <string>MountGuardApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.billlucky.mountguard</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MountGuard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__VERSION__</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

/usr/bin/sed -i '' "s/__VERSION__/${VERSION}/g" "$APP_CONTENTS/Info.plist"

cp -R "$APP_ROOT" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "MountGuard" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"

echo "Created:"
echo "  $DMG_PATH"
echo "  $DMG_PATH.sha256"
