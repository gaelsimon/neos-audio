#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: [PLATFORM=ios] ./scripts/appstore.sh <version> [build-number]"
    echo "Example: ./scripts/appstore.sh 1.4.1"
    exit 1
fi
# App Store Connect refuses a build number it has already seen for the version.
BUILD="${2:-$(date +%Y%m%d%H%M)}"
PLATFORM="${PLATFORM:-macos}"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/appstore"
ARCHIVE_PATH="$BUILD_DIR/Neos.xcarchive"
ENTITLEMENTS="$BUILD_DIR/Neos.entitlements"

case "$PLATFORM" in
    macos)
        SCHEME=Neos
        ARCHIVE_SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=-)
        APP_PATH="$BUILD_DIR/Neos.app"
        BINARY="$APP_PATH/Contents/MacOS/Neos"
        EMBEDDED_PROFILE="$APP_PATH/Contents/embedded.provisionprofile"
        INFO_PLIST="$APP_PATH/Contents/Info.plist"
        PACKAGE_PATH="$BUILD_DIR/Neos.pkg"
        ;;
    ios)
        SCHEME=NeosMobile
        # A device build cannot be signed ad hoc; the script signs it below.
        ARCHIVE_SIGNING=(-destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO)
        APP_PATH="$BUILD_DIR/Payload/Neos.app"
        BINARY="$APP_PATH/Neos"
        EMBEDDED_PROFILE="$APP_PATH/embedded.mobileprovision"
        INFO_PLIST="$APP_PATH/Info.plist"
        PACKAGE_PATH="$BUILD_DIR/Neos.ipa"
        ;;
    *)
        echo "PLATFORM must be macos or ios"
        exit 1
        ;;
esac

DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the ten-character team identifier}"
# Signed locally: Xcode's cloud export writes a designated requirement that a non-ASCII certificate name fails (ITMS-90238).
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:?Set APP_SIGN_IDENTITY to the Apple Distribution identity}"
if [ "$PLATFORM" = "macos" ]; then
    INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:?Set INSTALLER_SIGN_IDENTITY to the Mac Installer Distribution identity}"
fi
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:?Set PROVISIONING_PROFILE to the App Store provisioning profile for $PLATFORM}"
DESTINATION="${DESTINATION:-upload}"
if [ "$DESTINATION" = "upload" ]; then
    APPSTORE_APP_ID="${APPSTORE_APP_ID:?Set APPSTORE_APP_ID to the Apple ID of the app in App Store Connect}"
    APPSTORE_KEY_PATH="${APPSTORE_KEY_PATH:?Set APPSTORE_KEY_PATH to an App Store Connect API key (.p8)}"
    APPSTORE_KEY_ID="${APPSTORE_KEY_ID:?Set APPSTORE_KEY_ID}"
    APPSTORE_ISSUER_ID="${APPSTORE_ISSUER_ID:?Set APPSTORE_ISSUER_ID}"
fi

echo "==> Archiving Neos v${VERSION} (${BUILD}) for the App Store on ${PLATFORM}..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
xcodebuild -project "$PROJECT_DIR/Neos.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE' \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    "${ARCHIVE_SIGNING[@]}" \
    -quiet

mkdir -p "$(dirname "$APP_PATH")"
ditto "$ARCHIVE_PATH/Products/Applications/Neos.app" "$APP_PATH"
if strings "$BINARY" | grep "ko-fi.com" > /dev/null; then
    echo "ERROR: the Ko-fi link is still in the binary; APP_STORE was not applied"
    exit 1
fi

echo "==> Signing with ${APP_SIGN_IDENTITY}..."
cp "$PROVISIONING_PROFILE" "$EMBEDDED_PROFILE"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$INFO_PLIST")
if [ "$PLATFORM" = "macos" ]; then
    codesign -d --entitlements - --xml "$APP_PATH" > "$ENTITLEMENTS"
    /usr/libexec/PlistBuddy \
        -c "Add :com.apple.application-identifier string ${DEVELOPMENT_TEAM}.${BUNDLE_ID}" \
        -c "Add :com.apple.developer.team-identifier string ${DEVELOPMENT_TEAM}" \
        "$ENTITLEMENTS"
    codesign --force --sign "$APP_SIGN_IDENTITY" --options runtime --entitlements "$ENTITLEMENTS" "$APP_PATH"
else
    if [ -e "$APP_PATH/Frameworks" ] || [ -e "$APP_PATH/PlugIns" ]; then
        echo "ERROR: the app embeds frameworks or extensions, which this script does not sign yet"
        exit 1
    fi
    /usr/libexec/PlistBuddy \
        -c "Add :application-identifier string ${DEVELOPMENT_TEAM}.${BUNDLE_ID}" \
        -c "Add :com.apple.developer.team-identifier string ${DEVELOPMENT_TEAM}" \
        -c "Add :get-task-allow bool false" \
        -c "Add :beta-reports-active bool true" \
        "$ENTITLEMENTS"
    codesign --force --sign "$APP_SIGN_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP_PATH"
fi
codesign --verify --strict "$APP_PATH"

echo "==> Packaging..."
if [ "$PLATFORM" = "macos" ]; then
    productbuild --component "$APP_PATH" /Applications --sign "$INSTALLER_SIGN_IDENTITY" "$PACKAGE_PATH"
else
    (cd "$BUILD_DIR" && zip -qry "$PACKAGE_PATH" Payload)
fi

if [ "$DESTINATION" = "upload" ]; then
    echo "==> Uploading..."
    xcrun altool --upload-package "$PACKAGE_PATH" \
        --type "$PLATFORM" \
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
    echo "✅ Neos v${VERSION} (${BUILD}) for ${PLATFORM} uploaded. It shows up in App Store Connect once processed."
else
    echo "✅ Neos v${VERSION} (${BUILD}) for ${PLATFORM} packaged at $PACKAGE_PATH"
fi
