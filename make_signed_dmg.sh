#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Automatically find Developer ID from keychain
IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | awk -F'"' '{print $2}' | head -1)

if [ -z "$IDENTITY" ]; then
    echo "Error: No Developer ID Application certificate found in keychain"
    exit 1
fi

echo "Signing with: $IDENTITY"

# Sign the .app bundle
APP_BUNDLE="mac_appbundle/LabraScope.app"

# Sign embedded executables in Resources (like dfu-programmer-mac)
echo "Signing embedded binaries..."
codesign --force --sign "$IDENTITY" \
    --timestamp \
    --options runtime \
    "$APP_BUNDLE/Contents/Resources/firmware/dfu-programmer-mac"

# Sign any embedded frameworks/dylibs first (if any)
# find "$APP_BUNDLE" -name "*.dylib" -exec codesign --force --sign "$IDENTITY" --timestamp --options runtime {} \;
# find "$APP_BUNDLE" -name "*.framework" -exec codesign --force --sign "$IDENTITY" --timestamp --options runtime {} \;

# Sign the main executable
echo "Signing main executable..."
codesign --force --sign "$IDENTITY" \
    --timestamp \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE/Contents/MacOS/LabraScope"

# Sign the entire app bundle
echo "Signing app bundle..."
codesign --force --sign "$IDENTITY" \
    --timestamp \
    --options runtime \
    --entitlements entitlements.plist \
    "$APP_BUNDLE"

echo "Signing complete."

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