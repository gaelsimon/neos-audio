#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./scripts/appstore.sh <version> [build-number]"
    echo "Example: ./scripts/appstore.sh 1.4.1"
    exit 1
fi
# App Store Connect refuses a build number it has already seen for the version.
BUILD="${2:-$(date +%Y%m%d%H%M)}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/appstore"
ARCHIVE_PATH="$BUILD_DIR/Neos.xcarchive"
APP_PATH="$BUILD_DIR/Neos.app"
ENTITLEMENTS="$BUILD_DIR/Neos.entitlements"
PKG_PATH="$BUILD_DIR/Neos.pkg"

DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the ten-character team identifier}"
# Signed locally: Xcode's cloud export writes a designated requirement that a non-ASCII certificate name fails (ITMS-90238).
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:?Set APP_SIGN_IDENTITY to the Apple Distribution identity}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:?Set INSTALLER_SIGN_IDENTITY to the Mac Installer Distribution identity}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:?Set PROVISIONING_PROFILE to the Mac App Store provisioning profile}"
DESTINATION="${DESTINATION:-upload}"
if [ "$DESTINATION" = "upload" ]; then
    APPSTORE_APP_ID="${APPSTORE_APP_ID:?Set APPSTORE_APP_ID to the Apple ID of the app in App Store Connect}"
    APPSTORE_KEY_PATH="${APPSTORE_KEY_PATH:?Set APPSTORE_KEY_PATH to an App Store Connect API key (.p8)}"
    APPSTORE_KEY_ID="${APPSTORE_KEY_ID:?Set APPSTORE_KEY_ID}"
    APPSTORE_ISSUER_ID="${APPSTORE_ISSUER_ID:?Set APPSTORE_ISSUER_ID}"
fi

echo "==> Archiving Neos v${VERSION} (${BUILD}) for the App Store..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
xcodebuild -project "$PROJECT_DIR/Neos.xcodeproj" \
    -scheme Neos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE' \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY=- \
    -quiet

BINARY="$ARCHIVE_PATH/Products/Applications/Neos.app/Contents/MacOS/Neos"
if strings "$BINARY" | grep -q "ko-fi.com"; then
    echo "ERROR: the Ko-fi link is still in the binary; APP_STORE was not applied"
    exit 1
fi

echo "==> Signing with ${APP_SIGN_IDENTITY}..."
ditto "$ARCHIVE_PATH/Products/Applications/Neos.app" "$APP_PATH"
cp "$PROVISIONING_PROFILE" "$APP_PATH/Contents/embedded.provisionprofile"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Contents/Info.plist")
codesign -d --entitlements - --xml "$APP_PATH" > "$ENTITLEMENTS"
/usr/libexec/PlistBuddy \
    -c "Add :com.apple.application-identifier string ${DEVELOPMENT_TEAM}.${BUNDLE_ID}" \
    -c "Add :com.apple.developer.team-identifier string ${DEVELOPMENT_TEAM}" \
    "$ENTITLEMENTS"
codesign --force --sign "$APP_SIGN_IDENTITY" --options runtime --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --strict "$APP_PATH"

echo "==> Packaging..."
productbuild --component "$APP_PATH" /Applications --sign "$INSTALLER_SIGN_IDENTITY" "$PKG_PATH"

if [ "$DESTINATION" = "upload" ]; then
    echo "==> Uploading..."
    xcrun altool --upload-package "$PKG_PATH" \
        --type macos \
        --apple-id "$APPSTORE_APP_ID" \
        --bundle-id "$BUNDLE_ID" \
        --bundle-version "$BUILD" \
        --bundle-short-version-string "$VERSION" \
        --apiKey "$APPSTORE_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID" \
        --p8-file-path "$APPSTORE_KEY_PATH"
fi

echo ""
if [ "$DESTINATION" = "upload" ]; then
    echo "✅ Neos v${VERSION} (${BUILD}) uploaded. It shows up in App Store Connect once processed."
else
    echo "✅ Neos v${VERSION} (${BUILD}) packaged at $PKG_PATH"
fi
