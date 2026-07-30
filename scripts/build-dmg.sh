#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/Info.plist")
APP_PATH=${SLSKDBAR_APP_PATH:-"$PROJECT_DIR/dist/slskdbar.app"}
OUTPUT_DMG=${SLSKDBAR_OUTPUT_DMG:-"$PROJECT_DIR/dist/slskdbar-$VERSION.dmg"}
SIGN_IDENTITY=${SLSKDBAR_CODESIGN_IDENTITY:--}
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/slskdbar-dmg.XXXXXX")
STAGING_DIR="$TEMP_ROOT/slskdbar"
STAGED_DMG="$TEMP_ROOT/slskdbar-$VERSION.dmg"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

SLSKDBAR_OUTPUT_APP="$APP_PATH" \
  SLSKDBAR_CODESIGN_IDENTITY="$SIGN_IDENTITY" \
  "$SCRIPT_DIR/build-app.sh"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/slskdbar.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "slskdbar" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$STAGED_DMG"

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$STAGED_DMG"
fi

hdiutil verify "$STAGED_DMG"
mkdir -p "$(dirname "$OUTPUT_DMG")"
if [[ -e "$OUTPUT_DMG" ]]; then
  mv "$OUTPUT_DMG" "$TEMP_ROOT/previous-output.dmg"
fi
mv "$STAGED_DMG" "$OUTPUT_DMG"
echo "Created $OUTPUT_DMG"
