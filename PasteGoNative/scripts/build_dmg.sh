#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="${1:-/Users/gaopeng/Applications/PasteGo.app}"
FALLBACK_APP_PATH="$ROOT_DIR/dist/PasteGo-dmg/PasteGo.app"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
VOL_NAME="PasteGo"
STAGING_DIR="$DIST_DIR/PasteGo-dmg"
BACKGROUND_SVG="$DIST_DIR/dmg-background.svg"
BACKGROUND_PNG="$DIST_DIR/dmg-background.png"
TEMP_DMG="$DIST_DIR/PasteGo-temp.dmg"
FINAL_DMG="$DIST_DIR/PasteGo.dmg"
MOUNT_POINT="/Volumes/$VOL_NAME"

if [[ ! -d "$APP_PATH" ]]; then
  if [[ -d "$FALLBACK_APP_PATH" ]]; then
    APP_PATH="$FALLBACK_APP_PATH"
  else
    echo "App not found: $APP_PATH" >&2
    exit 1
  fi
fi

mkdir -p "$DIST_DIR"
rm -rf "$STAGING_DIR" "$TEMP_DMG" "$FINAL_DMG"
mkdir -p "$STAGING_DIR/.background"

if mount | grep -q "$MOUNT_POINT"; then
  hdiutil detach "$MOUNT_POINT" -quiet || true
  sleep 1
fi

swift "$ROOT_DIR/scripts/render_dmg_background.swift" "$BACKGROUND_PNG" >/dev/null
cp "$BACKGROUND_PNG" "$STAGING_DIR/.background/background.png"
cp -R "$APP_PATH" "$STAGING_DIR/PasteGo.app"

if [[ -f "$BUILD_DIR/PasteGo" ]]; then
  cp "$BUILD_DIR/PasteGo" "$STAGING_DIR/PasteGo.app/Contents/MacOS/PasteGo"
fi

for bundle_name in PasteGo_PasteGo.bundle GRDB_GRDB.bundle; do
  if [[ -d "$BUILD_DIR/$bundle_name" ]]; then
    rm -rf "$STAGING_DIR/PasteGo.app/Contents/Resources/$bundle_name"
    cp -R "$BUILD_DIR/$bundle_name" "$STAGING_DIR/PasteGo.app/Contents/Resources/$bundle_name"

    # SwiftPM-generated resource_bundle_accessor looks beside Bundle.main.bundleURL,
    # so packaged apps must also ship the resource bundles at the app root.
    rm -rf "$STAGING_DIR/PasteGo.app/$bundle_name"
    cp -R "$BUILD_DIR/$bundle_name" "$STAGING_DIR/PasteGo.app/$bundle_name"
  fi
done

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create -srcfolder "$STAGING_DIR" -volname "$VOL_NAME" -fs HFS+ -format UDRW "$TEMP_DMG" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG")"
DEVICE="$(echo "$MOUNT_OUTPUT" | awk '/Apple_HFS/ {print $1; exit}')"

cleanup() {
  if mount | grep -q "$MOUNT_POINT"; then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
}
trap cleanup EXIT

sleep 2

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOL_NAME"
    open
    delay 1
    set diskWindow to container window
    set current view of diskWindow to icon view
    set toolbar visible of diskWindow to false
    set statusbar visible of diskWindow to false
    set the bounds of diskWindow to {120, 120, 900, 560}
    set opts to the icon view options of diskWindow
    set arrangement of opts to not arranged
    set icon size of opts to 136
    set background picture of opts to file ".background:background.png"
    set position of item "PasteGo.app" of diskWindow to {150, 285}
    set position of item "Applications" of diskWindow to {620, 285}
    update without registering applications
    delay 1
    close diskWindow
    open
    delay 2
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$DEVICE" -quiet
trap - EXIT

hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
rm -f "$TEMP_DMG"

echo "Created: $FINAL_DMG"
