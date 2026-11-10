#!/usr/bin/env bash
#
# build_dmg.sh
# SimplyTrack
#
# Builds SimplyTrack and packages it into a distributable DMG image.
# Supports local developer unsigned builds (via native hdiutil) as well
# as release builds using appdmg or code-signing when configured.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIGURATION="Release"
SKIP_BUILD=false
OPEN_ON_FINISH=false
CUSTOM_OUTPUT=""

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -c, --config CONFIG     Build configuration: 'Release' (default) or 'Debug'
  -s, --skip-build        Skip xcodebuild; use existing app in build/
  -o, --output PATH       Custom output filename/path for the DMG
  --open                  Reveal created DMG in Finder after completion
  -h, --help              Show this help message

Examples:
  ./scripts/build_dmg.sh
  ./scripts/build_dmg.sh --config Debug --open
  ./scripts/build_dmg.sh --skip-build
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--config)
            CONFIGURATION="$2"
            shift 2
            ;;
        -s|--skip-build)
            SKIP_BUILD=true
            shift
            ;;
        -o|--output)
            CUSTOM_OUTPUT="$2"
            shift 2
            ;;
        --open)
            OPEN_ON_FINISH=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            print_usage
            exit 1
            ;;
    esac
done

cd "$PROJECT_ROOT"

BUILD_DIR="$PROJECT_ROOT/build"
DERIVED_DATA_DIR="$PROJECT_ROOT/.build_derived_data"
DMG_STAGING_DIR="$PROJECT_ROOT/build/dmg_staging"

# 1. Clean previous staging
rm -rf "$DMG_STAGING_DIR"
mkdir -p "$BUILD_DIR"

APP_PATH=""

# 2. Build if required
if [ "$SKIP_BUILD" = false ]; then
    echo "==> Building SimplyTrack (Configuration: $CONFIGURATION)..."
    xcodebuild -project SimplyTrack.xcodeproj \
        -scheme SimplyTrack \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        build

    BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/SimplyTrack.app"
    if [ ! -d "$BUILT_APP" ]; then
        echo "Error: Built app not found at expected path: $BUILT_APP" >&2
        exit 1
    fi

    # Copy to project build/ folder
    rm -rf "$BUILD_DIR/SimplyTrack.app"
    cp -R "$BUILT_APP" "$BUILD_DIR/SimplyTrack.app"
    APP_PATH="$BUILD_DIR/SimplyTrack.app"
else
    # Find existing app in build/
    if [ -d "$BUILD_DIR/SimplyTrack.app" ]; then
        APP_PATH="$BUILD_DIR/SimplyTrack.app"
    else
        APP_PATH=$(find "$BUILD_DIR" -name "SimplyTrack.app" -type d | head -n 1)
    fi

    if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
        echo "Error: No SimplyTrack.app found in $BUILD_DIR. Run without --skip-build." >&2
        exit 1
    fi
    echo "==> Using existing app bundle: $APP_PATH"
fi

# 3. Read application version from Info.plist
APP_VERSION=$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")
DMG_NAME="SimplyTrack-$APP_VERSION.dmg"
if [ -n "$CUSTOM_OUTPUT" ]; then
    FINAL_DMG="$CUSTOM_OUTPUT"
else
    FINAL_DMG="$BUILD_DIR/$DMG_NAME"
fi

echo "==> Packaging into DMG: $FINAL_DMG (App Version: $APP_VERSION)"
rm -f "$FINAL_DMG"

# 4. Use appdmg if installed and signing identity is present or template is adjusted; otherwise native hdiutil
if command -v appdmg >/dev/null 2>&1 && [ -f "$PROJECT_ROOT/appdmg.template.json" ]; then
    echo "==> Found 'appdmg' CLI, generating customized DMG via template..."
    TEMP_APPDMG_JSON="$BUILD_DIR/appdmg_temp.json"
    
    # Check if a code-signing certificate is available
    CERT_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep -E 'Developer ID Application|Apple Development' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)
    
    if [ -n "$CERT_IDENTITY" ]; then
        echo "    Using code-signing identity: $CERT_IDENTITY"
        sed "s|{{TITLE}}|SimplyTrack v$APP_VERSION|g; s|{{APP_PATH}}|$APP_PATH|g; s|{{CERT_IDENTITY}}|$CERT_IDENTITY|g" "$PROJECT_ROOT/appdmg.template.json" > "$TEMP_APPDMG_JSON"
    else
        echo "    No codesign certificate found in keychain, creating unsigned DMG template"
        # Remove code-sign block from template for local builds
        sed "s|{{TITLE}}|SimplyTrack v$APP_VERSION|g; s|{{APP_PATH}}|$APP_PATH|g" "$PROJECT_ROOT/appdmg.template.json" \
            | grep -v '"code-sign"' \
            | grep -v '"signing-identity"' \
            > "$TEMP_APPDMG_JSON"
    fi

    appdmg "$TEMP_APPDMG_JSON" "$FINAL_DMG"
    rm -f "$TEMP_APPDMG_JSON"

else
    echo "==> Using native macOS hdiutil to create DMG..."
    mkdir -p "$DMG_STAGING_DIR"
    cp -R "$APP_PATH" "$DMG_STAGING_DIR/"
    ln -s /Applications "$DMG_STAGING_DIR/Applications"

    # Optional: copy background image and icon if available
    if [ -f "$PROJECT_ROOT/dmg-background.png" ]; then
        mkdir -p "$DMG_STAGING_DIR/.background"
        cp "$PROJECT_ROOT/dmg-background.png" "$DMG_STAGING_DIR/.background/background.png"
    fi

    VOL_NAME="SimplyTrack"
    TEMP_DMG="$BUILD_DIR/temp_uncompressed.dmg"
    rm -f "$TEMP_DMG"

    # Calculate required size in MB with safety margin
    DIR_SIZE_MB=$(du -sm "$DMG_STAGING_DIR" | cut -f1)
    DMG_SIZE_MB=$((DIR_SIZE_MB + 30))

    # Create temporary read/write disk image
    hdiutil create -srcfolder "$DMG_STAGING_DIR" \
        -volname "$VOL_NAME" \
        -fs HFS+ \
        -fsargs "-c c=64,a=16,e=16" \
        -format UDRW \
        -size "${DMG_SIZE_MB}m" \
        "$TEMP_DMG" -quiet

    # Convert to compressed read-only UDZO image
    hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" -quiet
    rm -f "$TEMP_DMG"
    rm -rf "$DMG_STAGING_DIR"
fi

# 5. Generate checksum
shasum -a 256 "$FINAL_DMG" > "$FINAL_DMG.sha256"

echo "=========================================================="
echo " Successfully created DMG:"
echo " File:     $FINAL_DMG"
echo " Size:     $(du -h "$FINAL_DMG" | cut -f1)"
echo " SHA-256:  $(cat "$FINAL_DMG.sha256" | cut -d ' ' -f 1)"
echo "=========================================================="

if [ "$OPEN_ON_FINISH" = true ]; then
    open -R "$FINAL_DMG"
fi

