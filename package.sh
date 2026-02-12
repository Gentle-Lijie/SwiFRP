#!/bin/bash

# SwiFRP Package Script
# Builds and packages the app into a .app bundle

set -e

APP_NAME="SwiFRP"
BUNDLE_ID="com.swifrp.app"
VERSION="1.0.1"
CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
BUILD_DIR=".build/arm64-apple-macosx/${CONFIGURATION}"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
CURRENT_YEAR=$(date +"%Y")

echo "🚀 Building ${APP_NAME}..."

# Build the project
swift build -c "${CONFIGURATION}"

echo "📦 Creating app bundle structure..."

# Remove old app bundle if exists
rm -rf "${APP_BUNDLE}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Copy resources (localizations)
if [ -d "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle/"*.lproj "${RESOURCES_DIR}/" 2>/dev/null || true
fi

# Also copy from source if bundle doesn't have them
if [ -d "SwiFRP/Resources" ]; then
    for lproj in SwiFRP/Resources/*.lproj; do
        if [ -d "$lproj" ]; then
            cp -R "$lproj" "${RESOURCES_DIR}/"
        fi
    done
fi

# Copy app icon
if [ -f "SwiFRP/Resources/AppIcon.icns" ]; then
    cp "SwiFRP/Resources/AppIcon.icns" "${RESOURCES_DIR}/"
    echo "✨ App icon copied"
fi

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © ${CURRENT_YEAR} GentleLijie. All rights reserved.</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>ja</string>
        <string>ko</string>
        <string>es</string>
    </array>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo ""
echo "✅ App bundle created: ${APP_BUNDLE}"
echo ""
echo "📍 Location: $(pwd)/${APP_BUNDLE}"
echo ""

# Optionally open the app
if [ "$1" == "--open" ] || [ "$1" == "-o" ]; then
    echo "🚀 Opening ${APP_BUNDLE}..."
    open "${APP_BUNDLE}"
fi

echo "💡 To open the app, run: open ${APP_BUNDLE}"
echo "💡 To create a DMG, run: hdiutil create -volname '${APP_NAME}' -srcfolder '${APP_BUNDLE}' -ov -format UDZO '${APP_NAME}.dmg'"
