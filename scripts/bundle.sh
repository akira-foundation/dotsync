#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REL=.build/arm64-apple-macosx/release
APP=DotSyncApp.app

swift build -c release --arch arm64 --product DotSyncApp

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$REL/DotSyncApp" "$APP/Contents/MacOS/DotSyncApp"
cp -R "$REL/dotsync_DotSyncCore.bundle" "$APP/Contents/MacOS/"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>dotsync</string>
  <key>CFBundleIdentifier</key><string>io.akira.dotsync</string>
  <key>CFBundleExecutable</key><string>DotSyncApp</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSRequiresNativeExecution</key><true/>
</dict>
</plist>
PLIST

echo "bundled $APP"
