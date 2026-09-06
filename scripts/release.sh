#!/bin/bash
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: ./scripts/release.sh <version>"
    echo "Example: ./scripts/release.sh 1.0.0"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Neos.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Neos.app"
DMG_DIR="$BUILD_DIR/dmg-staging"
DMG_PATH="$BUILD_DIR/Neos-${VERSION}.dmg"

CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Manual}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"

# Notarisation credentials, absent on an ad-hoc build. App Store Connect API key, not an
# Apple ID password: it survives a password change and needs no second factor in CI.
NOTARY_KEY_PATH="${NOTARY_KEY_PATH:-}"
NOTARY_KEY_ID="${NOTARY_KEY_ID:-}"
NOTARY_ISSUER_ID="${NOTARY_ISSUER_ID:-}"

echo "==> Building Neos v${VERSION} Release archive (signing: ${CODE_SIGN_IDENTITY})..."
xcodebuild -project "$PROJECT_DIR/Neos.xcodeproj" \
    -scheme Neos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    archive \
    MARKETING_VERSION="$VERSION" \
    CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
    CODE_SIGN_STYLE="$CODE_SIGN_STYLE" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    -quiet

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Archive failed, Neos.app not found"
    exit 1
fi

echo "==> Verifying signature..."
codesign --verify --strict --verbose=1 "$APP_PATH"

echo "==> Creating DMG..."
rm -rf "$DMG_DIR" "$DMG_PATH"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create -volname "Neos" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "$DMG_PATH" \
    -quiet

rm -rf "$DMG_DIR"

# Notarising the DMG and stapling the ticket to it means the downloaded file clears Gatekeeper
# on its own, with no right-click and no quarantine flag to remove.
if [ "$CODE_SIGN_IDENTITY" = "-" ]; then
    echo "==> Ad-hoc signed: skipping notarisation. First launch will show the Gatekeeper warning."
elif [ -z "$NOTARY_KEY_PATH" ] || [ ! -f "$NOTARY_KEY_PATH" ]; then
    echo "==> No notary credentials: skipping notarisation."
else
    echo "==> Notarising (usually 2-15 minutes)..."
    xcrun notarytool submit "$DMG_PATH" \
        --key "$NOTARY_KEY_PATH" \
        --key-id "$NOTARY_KEY_ID" \
        --issuer "$NOTARY_ISSUER_ID" \
        --wait

    echo "==> Stapling ticket..."
    xcrun stapler staple "$DMG_PATH"
    xcrun stapler validate "$DMG_PATH"
    spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"
fi

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
echo ""
echo "✅ Neos v${VERSION} ready!"
echo "   DMG: $DMG_PATH ($DMG_SIZE)"
echo ""
echo "Next steps:"
echo "   git tag v${VERSION} && git push origin v${VERSION}"
echo "   (CI will then build + publish the GitHub Release automatically)"
