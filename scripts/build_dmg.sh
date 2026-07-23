#!/bin/bash
set -euo pipefail

APP_NAME="OpenFocus"
VERSION="0.3.0"
DIST="dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGING="$DIST/dmg_staging"
BG_SRC="assets/dmg-background.png"
VOL_NAME="$APP_NAME"
TMP_DMG="$DIST/${APP_NAME}-tmp.dmg"

if [ ! -d "$APP" ]; then
    echo "error: $APP not found. Run scripts/build_app.sh first." >&2
    exit 1
fi

if [ ! -f "$BG_SRC" ]; then
    echo "==> Generating DMG background"
    swift scripts/generate_dmg_background.swift
fi

echo "==> Preparing staging dir"
rm -rf "$STAGING" "$DMG" "$TMP_DMG"
mkdir -p "$STAGING/.background"
cp "$BG_SRC" "$STAGING/.background/background.png"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating writable DMG"
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$TMP_DMG" >/dev/null

echo "==> Mounting to configure Finder view"
MOUNT_DIR="/Volumes/$VOL_NAME"
hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen >/dev/null

# Give Finder a moment to notice the new volume.
sleep 1

/usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {160, 210}
        set position of item "Applications" of container window to {480, 210}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# Ensure .DS_Store is flushed before unmounting.
sync
sleep 1

echo "==> Unmounting"
hdiutil detach "$MOUNT_DIR" >/dev/null

echo "==> Compressing to $DMG"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

rm -f "$TMP_DMG"
rm -rf "$STAGING"

echo "==> Done: $DMG"
