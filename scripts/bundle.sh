#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

REL=.build/arm64-apple-macosx/release
APP=DotSyncApp.app
VERSION="${DOTSYNC_VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo 0.0.0)}"
VERSION="${VERSION:-0.0.0}"

swift build -c release --arch arm64 --product DotSyncApp

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$REL/DotSyncApp" "$APP/Contents/MacOS/DotSyncApp"
cp -R "$REL/dotsync_DotSyncCore.bundle" "$APP/Contents/MacOS/"

cat > "$APP/Contents/MacOS/dotsync_DotSyncCore.bundle/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>dotsync_DotSyncCore</string>
  <key>CFBundleIdentifier</key><string>io.akira.dotsync.resources</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
</dict>
</plist>
PLIST
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R "$REL/Sparkle.framework" "$APP/Contents/Frameworks/"

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
  <key>CFBundleShortVersionString</key><string>__VERSION__</string>
  <key>CFBundleVersion</key><string>__VERSION__</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSRequiresNativeExecution</key><true/>
  <key>SUFeedURL</key><string>https://raw.githubusercontent.com/akira-foundation/dotsync/main/appcast.xml</string>
  <key>SUPublicEDKey</key><string>__SPARKLE_PUBLIC_ED_KEY__</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUScheduledCheckInterval</key><integer>86400</integer>
</dict>
</plist>
PLIST

sed -i '' "s|__VERSION__|${VERSION}|g" "$APP/Contents/Info.plist"
PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-bGQW9g8uQnY66E1eexl5WdPC7KgGOkDJhE1NoTL8QFw=}"
sed -i '' "s|__SPARKLE_PUBLIC_ED_KEY__|${PUBLIC_ED_KEY}|" "$APP/Contents/Info.plist"

echo "bundled $APP"
