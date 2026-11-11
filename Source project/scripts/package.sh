#!/bin/sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

swift test
swift build -c release

APP="release/Morrow Budget.app"
rm -rf "$APP" "release/PersonalBudget.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/PersonalBudget "$APP/Contents/MacOS/PersonalBudget"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PersonalBudget</string>
    <key>CFBundleIdentifier</key>
    <string>app.morrow.personalbudget</string>
    <key>CFBundleName</key>
    <string>Morrow Budget</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

ARCHIVE="Morrow-Budget-macOS.zip"
STAGING_DIR="$(mktemp -d /private/tmp/morrow-budget-package.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
mkdir -p "$STAGING_DIR/Source project"
cp -R "$APP" "$STAGING_DIR/Morrow Budget.app"
cp README.md "$STAGING_DIR/README.md"
cp Package.swift "$STAGING_DIR/Source project/Package.swift"
cp README.md "$STAGING_DIR/Source project/README.md"
cp -R Sources Tests scripts "$STAGING_DIR/Source project/"
rm -f "$ARCHIVE"
(cd "$STAGING_DIR" && zip -r "$PROJECT_ROOT/$ARCHIVE" "Morrow Budget.app" README.md "Source project" -x '*/.DS_Store' >/dev/null)
unzip -t "$ARCHIVE"
APP_COUNT="$(unzip -Z1 "$ARCHIVE" | awk '{ path = $0; sub(/\/$/, "", path); countParts = split(path, parts, "/"); if (parts[countParts] == "Morrow Budget.app") count++ } END { print count + 0 }')"
if [ "$APP_COUNT" -ne 1 ]; then
    echo "Expected exactly one app bundle in $ARCHIVE; found $APP_COUNT" >&2
    exit 1
fi
rm -f "PersonalBudget-macOS.zip"
printf '\nCreated %s/%s\n' "$PROJECT_ROOT" "$ARCHIVE"


