#!/bin/bash
set -euo pipefail

APP_NAME="OpenFocus"
BUNDLE_ID="com.fillsoko.openfocus"
VERSION="0.2.0"
BINARY="NotchMVP"
BUILD_DIR=".build/release"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> Building release binary"
swift build -c release

if [ ! -f "AppIcon.icns" ]; then
    echo "==> Generating icon"
    swiftc -o /tmp/generate_icon scripts/generate_icon.swift
    /tmp/generate_icon
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/$BINARY" "$APP/Contents/MacOS/$APP_NAME"
cp "AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Filip Sokolowski</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "==> Done: $APP"
