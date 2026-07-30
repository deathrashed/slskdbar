#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
OUTPUT_APP=${SLSKDBAR_OUTPUT_APP:-"$PROJECT_DIR/dist/slskdbar.app"}
SIGN_IDENTITY=${SLSKDBAR_CODESIGN_IDENTITY:--}
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/slskdbar-build.XXXXXX")
STAGED_APP="$TEMP_ROOT/slskdbar.app"

cleanup() {
  rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT

cd "$PROJECT_DIR"
swift test
echo "Tests passed"
swift build -c release
echo "Release build passed"

mkdir -p "$STAGED_APP/Contents/MacOS" "$STAGED_APP/Contents/Resources"
cp "$PROJECT_DIR/.build/release/slskdbar" "$STAGED_APP/Contents/MacOS/slskdbar"
cp "$PROJECT_DIR/Info.plist" "$STAGED_APP/Contents/Info.plist"
cp -R "$PROJECT_DIR/Resources/." "$STAGED_APP/Contents/Resources/"
cp "$PROJECT_DIR/Resources/Icons/slskd-color-icon.icns" "$STAGED_APP/Contents/Resources/slskd-color-icon.icns"
chmod 755 "$STAGED_APP/Contents/MacOS/slskdbar"
xattr -cr "$STAGED_APP"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$STAGED_APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$STAGED_APP"
fi
plutil -lint "$STAGED_APP/Contents/Info.plist"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"
echo "Bundle validation passed"

mkdir -p "$(dirname "$OUTPUT_APP")"
if [[ -e "$OUTPUT_APP" ]]; then
  mv "$OUTPUT_APP" "$TEMP_ROOT/previous-output.app"
fi
mv "$STAGED_APP" "$OUTPUT_APP"
echo "Created $OUTPUT_APP"
