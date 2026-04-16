#!/bin/bash

APP_NAME="SonicBar"
DIR_NAME="${APP_NAME}.app/Contents/MacOS"
RESOURCES_DIR="${APP_NAME}.app/Contents/Resources"

# Setup app bundle
mkdir -p "$DIR_NAME"
mkdir -p "$RESOURCES_DIR"

if [ -f "Assets/AppIcon.png" ]; then
    echo "Compiling App Icon..."
    mkdir -p MyIcon.iconset
    sips -z 16 16     Assets/AppIcon.png --out MyIcon.iconset/icon_16x16.png > /dev/null 2>&1
    sips -z 32 32     Assets/AppIcon.png --out MyIcon.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -z 32 32     Assets/AppIcon.png --out MyIcon.iconset/icon_32x32.png > /dev/null 2>&1
    sips -z 64 64     Assets/AppIcon.png --out MyIcon.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -z 128 128   Assets/AppIcon.png --out MyIcon.iconset/icon_128x128.png > /dev/null 2>&1
    sips -z 256 256   Assets/AppIcon.png --out MyIcon.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -z 256 256   Assets/AppIcon.png --out MyIcon.iconset/icon_256x256.png > /dev/null 2>&1
    sips -z 512 512   Assets/AppIcon.png --out MyIcon.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -z 512 512   Assets/AppIcon.png --out MyIcon.iconset/icon_512x512.png > /dev/null 2>&1
    sips -z 1024 1024 Assets/AppIcon.png --out MyIcon.iconset/icon_512x512@2x.png > /dev/null 2>&1
    iconutil -c icns MyIcon.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf MyIcon.iconset
fi

cat <<EOF > "${APP_NAME}.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.SonicBar</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Compiling Swift source files..."
SWIFT_FILES=$(find Sources -name "*.swift")
swiftc $SWIFT_FILES -o "$DIR_NAME/$APP_NAME"

if [ $? -eq 0 ]; then
    echo "Build successful! Created ${APP_NAME}.app"
    echo "You can run it from Finder or /Applications."
else
    echo "Compilation failed."
    exit 1
fi
