#!/bin/bash
set -e

SCHEME="ALMS"
PROJECT="ALMS/ALMS.xcodeproj"
DERIVED="$HOME/Library/Developer/Xcode/DerivedData"

cd "$(dirname "$0")"

# Ensure xcode-select points at Xcode.app, not Command Line Tools
XCODE_PATH="/Applications/Xcode.app/Contents/Developer"
if [ "$(xcode-select -p)" != "$XCODE_PATH" ]; then
    echo "▸ Fixing xcode-select (requires sudo once)..."
    sudo xcode-select -s "$XCODE_PATH"
fi

find_app() {
    local config="$1"
    find "$DERIVED" -maxdepth 5 -name "$SCHEME.app" -path "*/$config/*" 2>/dev/null | head -1
}

case "${1:-run}" in

  build)
    echo "▸ Building $SCHEME (Debug)..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug build -quiet
    echo "✓ Done"
    ;;

  run)
    echo "▸ Building $SCHEME (Debug)..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug build -quiet
    APP=$(find_app Debug)
    [ -z "$APP" ] && echo "✗ App not found after build" && exit 1
    echo "▸ Launching..."
    open "$APP"
    ;;

  install)
    echo "▸ Building $SCHEME (Release)..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release build -quiet
    APP=$(find_app Release)
    [ -z "$APP" ] && echo "✗ App not found after build" && exit 1
    cp -Rf "$APP" /Applications/
    echo "✓ Installed — launch ALMS from Spotlight anytime"
    ;;

  open)
    APP=$(find_app Debug)
    if [ -z "$APP" ]; then
        APP=$(find_app Release)
    fi
    [ -z "$APP" ] && echo "✗ No build found — run './dev.sh build' first" && exit 1
    open "$APP"
    ;;

  clean)
    echo "▸ Cleaning..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean -quiet
    echo "✓ Clean"
    ;;

  *)
    echo "Usage: ./dev.sh [build|run|install|open|clean]"
    echo ""
    echo "  build    — Debug build (no launch)"
    echo "  run      — Debug build + launch (default)"
    echo "  install  — Release build → /Applications (then use Spotlight)"
    echo "  open     — Launch last build without rebuilding"
    echo "  clean    — Clean derived data"
    ;;

esac
