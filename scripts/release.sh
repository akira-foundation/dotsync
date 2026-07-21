#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>}"
APP=DotSyncApp.app
DIST=dist
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin

: "${SIGN_IDENTITY:?Developer ID Application identity required}"
: "${APPLE_ID:?}"
: "${APPLE_TEAM_ID:?}"
: "${APPLE_APP_PASSWORD:?}"
: "${SPARKLE_PUBLIC_ED_KEY:?}"
: "${SPARKLE_ED_PRIVATE_KEY_FILE:?path to exported EdDSA private key}"
: "${DOWNLOAD_URL_PREFIX:?public URL prefix for the dmg, e.g. https://github.com/<owner>/<repo>/releases/download/v${VERSION}/}"

echo "==> bundle"
DOTSYNC_VERSION="$VERSION" bash scripts/bundle.sh

echo "==> codesign (hardened runtime, inner-out)"
FW="$APP/Contents/Frameworks/Sparkle.framework"
sign() { codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"; }
sign "$FW/Versions/B/XPCServices/Installer.xpc"
sign "$FW/Versions/B/XPCServices/Downloader.xpc"
sign "$FW/Versions/B/Updater.app"
sign "$FW/Versions/B/Autoupdate"
sign "$FW"
codesign --force --options runtime --timestamp \
    --entitlements scripts/dotsync.entitlements --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> dmg"
mkdir -p "$DIST"
DMG="$DIST/dotsync-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "dotsync" -srcfolder "$APP" -ov -format UDZO "$DMG"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"

echo "==> notarize"
xcrun notarytool submit "$DMG" \
    --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait
xcrun stapler staple "$DMG"

echo "==> appcast (Sparkle EdDSA)"
"$SPARKLE_BIN/generate_appcast" \
    --ed-key-file "$SPARKLE_ED_PRIVATE_KEY_FILE" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    "$DIST"

echo "==> done: $DMG + $DIST/appcast.xml"
