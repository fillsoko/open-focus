#!/bin/bash
set -euo pipefail

APP_NAME="OpenFocus"
VERSION="0.1.0"
DIST="dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGING="$DIST/dmg_staging"

if [ ! -d "$APP" ]; then
    echo "error: $APP not found. Run scripts/build_app.sh first." >&2
    exit 1
fi

echo "==> Preparing staging dir"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    "$DMG" >/dev/null

rm -rf "$STAGING"

echo "==> Done: $DMG"
