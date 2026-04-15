#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-0.1.0}"
BUILD_DATE="$(date +%Y.%m.%d)"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
SIGN_IDENTITY="${MOUNTGUARD_SIGN_IDENTITY:--}"
BUILD_ROOT="$ROOT_DIR/.build/mountguard-release"
APP_ROOT="$BUILD_ROOT/MountGuard.app"
APP_CONTENTS="$APP_ROOT/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/MountGuard-${VERSION}.dmg"
STAGING_DIR="$BUILD_ROOT/dmg-root"
ICONSET_DIR="$BUILD_ROOT/MountGuard.iconset"
ICNS_PATH="$APP_RESOURCES/MountGuard.icns"
QUICK_START_PATH="$STAGING_DIR/MountGuard Quick Start.txt"

rm -rf "$BUILD_ROOT" "$DMG_PATH"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$DIST_DIR" "$STAGING_DIR"

swift build -c release --product MountGuardApp --disable-sandbox

EXECUTABLE_PATH="$(find "$ROOT_DIR/.build" -path '*/release/MountGuardApp' -type f | head -n 1)"
if [[ -z "${EXECUTABLE_PATH}" ]]; then
  echo "Release executable not found." >&2
  exit 1
fi

cp "$EXECUTABLE_PATH" "$APP_MACOS/MountGuardApp"
chmod +x "$APP_MACOS/MountGuardApp"

swift "$ROOT_DIR/scripts/generate-emoji-icon.swift" "$ICONSET_DIR" "🧲"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"

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
    <key>CFBundleIconFile</key>
    <string>MountGuard</string>
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
    <key>MountGuardBuildDate</key>
    <string>__BUILD_DATE__</string>
    <key>MountGuardGitCommit</key>
    <string>__GIT_COMMIT__</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

/usr/bin/sed -i '' "s/__VERSION__/${VERSION}/g" "$APP_CONTENTS/Info.plist"
/usr/bin/sed -i '' "s/__BUILD_DATE__/${BUILD_DATE}/g" "$APP_CONTENTS/Info.plist"
/usr/bin/sed -i '' "s/__GIT_COMMIT__/${GIT_COMMIT}/g" "$APP_CONTENTS/Info.plist"

/usr/bin/xattr -cr "$APP_ROOT"
/usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_ROOT"
/usr/bin/codesign --verify --deep --strict "$APP_ROOT"

cat > "$QUICK_START_PATH" <<EOF
MountGuard Quick Start

1. Drag MountGuard.app to Applications.
2. Open it from Applications.
3. If macOS warns on first launch:
   - right-click MountGuard.app
   - choose Open
   - confirm once

Why this may happen:
- this build is code-signed for bundle integrity
- it may still be blocked by Gatekeeper if it has not been notarized for your machine

Version: ${VERSION}
Build: ${BUILD_DATE}
Commit: ${GIT_COMMIT}
EOF

/usr/bin/ditto "$APP_ROOT" "$STAGING_DIR/MountGuard.app"
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
