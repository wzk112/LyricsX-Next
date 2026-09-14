#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
CONFIGURATION="${1:-release}"
if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Usage: scripts/build.sh [release|debug]" >&2
  exit 2
fi
swift build --configuration "$CONFIGURATION"
BIN_DIR="$(swift build --configuration "$CONFIGURATION" --show-bin-path)"
APP="$PROJECT_ROOT/build/LyricsX Next.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/LyricsX" "$APP/Contents/MacOS/LyricsX"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/run.pl Resources/MediaRemoteAdapter-LICENSE LICENSE "$APP/Contents/Resources/"
iconutil -c icns Resources/Icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
for dylib in "$BIN_DIR"/*.dylib; do
  [[ -e "$dylib" ]] || continue
  cp "$dylib" "$APP/Contents/Frameworks/"
done
for bundle in "$BIN_DIR"/*.bundle; do
  [[ -d "$bundle" ]] || continue
  ditto "$bundle" "$APP/Contents/Resources/$(basename "$bundle")"
done
# SPM uses @rpath; packaged applications must resolve dependencies beside the executable.
if ! otool -l "$APP/Contents/MacOS/LyricsX" | /usr/bin/grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "$APP/Contents/MacOS/LyricsX"
fi
SIGN_IDENTITY="${LYRICSX_SIGN_IDENTITY:--}"
for dylib in "$APP/Contents/Frameworks"/*.dylib; do
  codesign --force --sign "$SIGN_IDENTITY" "$dylib"
done
codesign --force --sign "$SIGN_IDENTITY" --entitlements Resources/LyricsX.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "Built: $APP"
