#!/bin/bash
set -e

# CONFIG
APP_NAME="LabraScope"
# Dedicated build dir: a stale cache in a dev build dir would silently keep
# old settings (e.g. a single-arch CMAKE_OSX_ARCHITECTURES) - packaging always
# configures fresh defaults (universal x86_64+arm64, macOS 10.15+).
BUILD_DIR="build_package"
APP_BUNDLE_DIR="mac_appbundle/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
INFO_PLIST="${CONTENTS_DIR}/Info.plist"

# 1. Build the project
echo "Building project..."
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
cmake ..
cmake --build .
cd ..

# 2. Create .app bundle structure
echo "Creating .app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy executable into MacOS directory
echo "Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# 4. Copy resources into Resources directory
echo "Copying resources..."
cp -R misc/media "$RESOURCES_DIR/"
cp -R misc/fonts "$RESOURCES_DIR/"
cp -R README.md "$RESOURCES_DIR/"
cp -R firmware "$RESOURCES_DIR/"


# 5. Copy Info.plist if it exists
if [ ! -f "$INFO_PLIST" ]; then
    echo "Creating default Info.plist..."
    cat <<EOL > "$INFO_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.example.${APP_NAME}</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleIconFile</key>
  <string>media/iconfile</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.15</string>
</dict>
</plist>
EOL
fi

# 6. Optionally sign the app bundle (if codesigning identity is available)
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | awk -F'"' '{print $2}' | head -1)

if [ -z "$IDENTITY" ]; then
    echo "Warning: No Developer ID Application certificate found in keychain"
    echo "Skipping code signing. The app bundle will not be signed."
    echo ""
    echo "Packaging complete! (unsigned)"
    echo "To sign the app, install a Developer ID Application certificate and run again."
else
    echo "Signing with: $IDENTITY"

    # Sign embedded executables in Resources (like dfu-programmer-mac)
    echo "Signing embedded binaries..."
    if [ -f "$APP_BUNDLE_DIR/Contents/Resources/firmware/dfu-programmer-mac" ]; then
        codesign --force --sign "$IDENTITY" \
            --timestamp \
            --options runtime \
            "$APP_BUNDLE_DIR/Contents/Resources/firmware/dfu-programmer-mac"
    fi

    # Sign the main executable
    echo "Signing main executable..."
    codesign --force --sign "$IDENTITY" \
        --timestamp \
        --options runtime \
        --entitlements entitlements.plist \
        "$APP_BUNDLE_DIR/Contents/MacOS/$APP_NAME"

    # Sign the entire app bundle
    echo "Signing app bundle..."
    codesign --force --sign "$IDENTITY" \
        --timestamp \
        --options runtime \
        --entitlements entitlements.plist \
        "$APP_BUNDLE_DIR"

    echo ""
    echo "Packaging complete! (signed)"
    echo "App bundle is signed and ready for DMG creation."
fi

echo "You can now run ./make_signed_dmg.sh to create a notarized DMG."
