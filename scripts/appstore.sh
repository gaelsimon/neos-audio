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
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS="$BUILD_DIR/ExportOptions.plist"

DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:?Set DEVELOPMENT_TEAM to the ten-character team identifier}"
# Same App Store Connect API key as notarisation; "export" keeps the package local instead of uploading.
NOTARY_KEY_PATH="${NOTARY_KEY_PATH:?Set NOTARY_KEY_PATH to the App Store Connect API key (.p8)}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:?Set NOTARY_KEY_ID}"
NOTARY_ISSUER_ID="${NOTARY_ISSUER_ID:?Set NOTARY_ISSUER_ID}"
DESTINATION="${DESTINATION:-upload}"

AUTH=(
    -allowProvisioningUpdates
    -authenticationKeyPath "$NOTARY_KEY_PATH"
    -authenticationKeyID "$NOTARY_KEY_ID"
    -authenticationKeyIssuerID "$NOTARY_ISSUER_ID"
)

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
    CODE_SIGN_STYLE=Automatic \
    "${AUTH[@]}" \
    -quiet

BINARY="$ARCHIVE_PATH/Products/Applications/Neos.app/Contents/MacOS/Neos"
if strings "$BINARY" | grep -q "ko-fi.com"; then
    echo "ERROR: the Ko-fi link is still in the binary; APP_STORE was not applied"
    exit 1
fi

cat > "$EXPORT_OPTIONS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>${DESTINATION}</string>
    <key>teamID</key>
    <string>${DEVELOPMENT_TEAM}</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

echo "==> Exporting (${DESTINATION})..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_DIR" \
    "${AUTH[@]}" \
    -quiet

echo ""
if [ "$DESTINATION" = "upload" ]; then
    echo "✅ Neos v${VERSION} (${BUILD}) uploaded. It shows up in App Store Connect once processed."
else
    echo "✅ Neos v${VERSION} (${BUILD}) exported to $EXPORT_DIR"
fi
