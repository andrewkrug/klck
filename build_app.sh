#!/bin/bash
# Builds Klck and assembles a runnable Klck.app bundle (no Xcode required).
set -euo pipefail

cd "$(dirname "$0")"

CONFIG="${1:-release}"
APP="Klck.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/Klck"
if [[ ! -f "$BIN" ]]; then
    echo "Build product not found at $BIN" >&2
    exit 1
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Klck"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc sign so macOS lets the bundle run audio locally.
codesign --force --sign - "$APP" 2>/dev/null || echo "(codesign skipped)"

echo "==> Done: $(pwd)/$APP"
echo "    Run with: open $APP   (or ./$APP/Contents/MacOS/Klck for console output)"
