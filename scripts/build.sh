#!/usr/bin/env bash
# Build Rondo and place the app in dist/Rondo.app
# Usage: ./scripts/build.sh [Release|Debug]  (default: Release)
set -euo pipefail

CONFIG=${1:-Release}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED="$ROOT/build"
DIST="$ROOT/dist"

cd "$ROOT"
echo "Building Rondo ($CONFIG)..."
if ! xcodebuild \
  -project Rondo.xcodeproj \
  -scheme Rondo \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  build > "$DERIVED.log" 2>&1; then
  grep -E "error:" "$DERIVED.log" || tail -20 "$DERIVED.log"
  echo "Build failed. Full log: $DERIVED.log"
  exit 1
fi

mkdir -p "$DIST"
rm -rf "$DIST/Rondo.app"
ditto "$DERIVED/Build/Products/$CONFIG/Rondo.app" "$DIST/Rondo.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DIST/Rondo.app/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$DIST/Rondo.app/Contents/Info.plist")
echo "Built: $DIST/Rondo.app — version $VERSION ($BUILD), $(du -sh "$DIST/Rondo.app" | cut -f1)"
