#!/usr/bin/env bash
set -euo pipefail

# Build polished macOS DMG for Wallps
APP_NAME="Wallps"
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData/Wallps-build"
APP_BUNDLE="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
OUTPUT_DIR="$(pwd)/build"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}.dmg"
STAGING_DIR="${OUTPUT_DIR}/dmg_staging"

echo "==> Preparing DMG packaging for ${APP_NAME}..."

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Building Release target..."
    xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -derivedDataPath "${DERIVED_DATA}" build
fi

mkdir -p "${OUTPUT_DIR}"
rm -rf "${STAGING_DIR}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

echo "==> Copying ${APP_NAME}.app to staging..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

echo "==> Creating /Applications symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

if [ -f "Wallps/Resources/AppIcon.icns" ]; then
    cp "Wallps/Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
    command -v SetFile >/dev/null && SetFile -a C "${STAGING_DIR}" || true
fi

echo "==> Creating DMG image with hdiutil..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}"

rm -rf "${STAGING_DIR}"

echo "==> Verifying DMG..."
hdiutil imageinfo "${DMG_PATH}" >/dev/null

echo "==> Successfully built DMG installer:"
echo "    ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
