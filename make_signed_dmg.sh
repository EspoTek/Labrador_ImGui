#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Automatically find Developer ID from keychain
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | awk -F'"' '{print $2}' | head -1)

if [ -z "$IDENTITY" ]; then
    echo "Error: No Developer ID Application certificate found in keychain"
    echo "Cannot create signed DMG without a Developer ID certificate."
    exit 1
fi

echo "Using identity: $IDENTITY"

# Verify the app bundle is already signed (should be done by package_mac.sh)
APP_BUNDLE="${SCRIPT_DIR}/mac_appbundle/LabraScope.app"
if ! codesign --verify --deep --strict "$APP_BUNDLE" 2>/dev/null; then
    echo "Warning: App bundle is not signed or signature is invalid."
    echo "Run ./package_mac.sh first to build and sign the app bundle."
    exit 1
fi

echo "App bundle signature verified."

# Remove old DMG if it exists
rm -f "${SCRIPT_DIR}/LabraScope.dmg"

create-dmg \
    --volname "LabraScope" \
    --volicon "${SCRIPT_DIR}/misc/media/iconfile.icns" \
    --background "${SCRIPT_DIR}/misc/media/dmg-background.png" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "LabraScope.app" 150 200 \
    --hide-extension "LabraScope.app" \
    --app-drop-link 450 200 \
    --no-internet-enable \
    --codesign "$IDENTITY" \
    "${SCRIPT_DIR}/LabraScope.dmg" \
    "${SCRIPT_DIR}/mac_appbundle/LabraScope.app"

xcrun notarytool submit "${SCRIPT_DIR}/LabraScope.dmg" \
    --keychain-profile "notarytool-profile" \
    --wait

xcrun stapler staple "${SCRIPT_DIR}/LabraScope.dmg"

# Check if staple is valid
xcrun stapler validate "${SCRIPT_DIR}/LabraScope.dmg"

# Verify with spctl (Gatekeeper check)
spctl --assess --type open --context context:primary-signature --verbose "${SCRIPT_DIR}/LabraScope.dmg"