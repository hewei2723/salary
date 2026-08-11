#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_NAME="SalaryCharger"
APP_DISPLAY_NAME="工资计时器"
VERSION="$(<"$PROJECT_ROOT/VERSION")"
BUILD_NUMBER="2"
DIST_DIR="$PROJECT_ROOT/dist"
APP_DIR="$DIST_DIR/$APP_DISPLAY_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$PROJECT_ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

mkdir -p "$CONTENTS_DIR/MacOS"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS_DIR/MacOS/$APP_NAME"

RESOURCE_BUNDLE="$BIN_DIR/SalaryCharger_SalaryCharger.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    print -u2 "本地化资源不存在: $RESOURCE_BUNDLE"
    exit 1
fi

mkdir -p "$RESOURCES_DIR"
for LPROJ_DIR in "$RESOURCE_BUNDLE"/*.lproj; do
    ditto "$LPROJ_DIR" "$RESOURCES_DIR/${LPROJ_DIR:t}"
done

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
        <string>ja</string>
        <string>ko</string>
        <string>ru</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>SalaryCharger</string>
    <key>CFBundleIdentifier</key>
    <string>com.hewei.salarycharger</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDisplayName</key>
    <string>工资计时器</string>
    <key>CFBundleName</key>
    <string>工资计时器</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"
echo "$APP_DIR"
