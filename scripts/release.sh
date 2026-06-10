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

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1 | xargs)
echo ""
echo "✅ Neos v${VERSION} ready!"
echo "   DMG: $DMG_PATH ($DMG_SIZE)"
echo ""
echo "Next steps:"
echo "   git tag v${VERSION} && git push origin v${VERSION}"
echo "   (CI will then build + publish the GitHub Release automatically)"
