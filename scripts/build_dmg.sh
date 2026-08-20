#!/usr/bin/env bash
set -euo pipefail

# Build polished, standards-compliant macOS DMG for Wallps
APP_NAME="Wallps"
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData/Wallps-build"
APP_BUNDLE="${DERIVED_DATA}/Build/Products/Release/${APP_NAME}.app"
OUTPUT_DIR="$(pwd)/build"
DMG_PATH="${OUTPUT_DIR}/${APP_NAME}.dmg"

# Use local non-synced directory for staging to prevent cloud sync xattrs
TMP_DIR="$(mktemp -d -t wallps_dmg_XXXXXX)"
STAGING_DIR="${TMP_DIR}/staging"
TMP_DMG="${TMP_DIR}/${APP_NAME}.dmg"
ENTITLEMENTS="$(pwd)/Wallps/Wallps.entitlements"

cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "==> Preparing release packaging for ${APP_NAME}..."

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "==> Building Release target..."
    xcodebuild -project "${APP_NAME}.xcodeproj" -scheme "${APP_NAME}" -configuration Release -derivedDataPath "${DERIVED_DATA}" build
fi

mkdir -p "${OUTPUT_DIR}"
rm -rf "${STAGING_DIR}" "${TMP_DMG}" "${DMG_PATH}"
mkdir -p "${STAGING_DIR}"

echo "==> Copying ${APP_NAME}.app to clean staging..."
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

echo "==> Sanitizing extended attributes..."
xattr -cr "${STAGING_DIR}"

echo "==> Re-signing staged app with Hardened Runtime..."
codesign --force --deep --sign - --options runtime --entitlements "${ENTITLEMENTS}" "${STAGING_DIR}/${APP_NAME}.app"

echo "==> Verifying signature and integrity..."
codesign --verify --deep --strict --verbose=2 "${STAGING_DIR}/${APP_NAME}.app"

echo "==> Creating /Applications symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

if [ -f "Wallps/Resources/AppIcon.icns" ]; then
    cp "Wallps/Resources/AppIcon.icns" "${STAGING_DIR}/.VolumeIcon.icns"
    command -v SetFile >/dev/null && SetFile -a C "${STAGING_DIR}" || true
fi

# Ensure no stray attributes in staging before creating DMG
xattr -cr "${STAGING_DIR}" 2>/dev/null || true

echo "==> Creating DMG image with hdiutil..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${TMP_DMG}"

echo "==> Moving DMG to build directory..."
cp "${TMP_DMG}" "${DMG_PATH}"

echo "==> Verifying DMG integrity..."
hdiutil imageinfo "${DMG_PATH}" >/dev/null

echo "==> Successfully built DMG installer:"
echo "    ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
