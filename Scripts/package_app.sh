#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: package_app.sh [--arch <x86_64|arm64>] [--version <semver>] [--output <dir>]

Builds the DrawingPad Swift package with SwiftPM and assembles a .app bundle
for distribution. The script creates a zip archive containing the bundle and
prints the resulting path.

Environment variables:
  ARCH        Overrides the architecture (x86_64 or arm64).
  VERSION     Overrides the bundle version (defaults to git tag or 0.1.0).
  OUTPUT_DIR  Overrides the directory where artifacts are stored (defaults to dist/).
EOF
}

ARCH="${ARCH:-}"
VERSION="${VERSION:-}"
OUTPUT_DIR="${OUTPUT_DIR:-}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --arch)
            ARCH="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$ARCH" ]]; then
    ARCH="$(uname -m)"
fi

case "$ARCH" in
    x86_64|amd64)
        SWIFT_ARCH="x86_64"
        BUILD_TRIPLE="x86_64-apple-macosx"
        ;;
    arm64|aarch64)
        SWIFT_ARCH="arm64"
        BUILD_TRIPLE="arm64-apple-macosx"
        ;;
    *)
        echo "Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

if [[ -z "$VERSION" ]]; then
    if VERSION="$(git describe --tags --abbrev=0 2>/dev/null)"; then
        VERSION="${VERSION#v}"
    else
        VERSION="0.1.0"
    fi
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="dist"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PRODUCT_NAME="DrawingPad"
APP_NAME="$PRODUCT_NAME.app"
BUILD_CONFIG="release"

BUILD_PATH="$PROJECT_ROOT/.build/$BUILD_TRIPLE/$BUILD_CONFIG"
EXECUTABLE_PATH="$BUILD_PATH/$PRODUCT_NAME"

if [[ ! -x "$EXECUTABLE_PATH" || "$EXECUTABLE_PATH" -ot "$PROJECT_ROOT/Sources" ]]; then
    echo "Building $PRODUCT_NAME for $SWIFT_ARCH..."
    swift build --arch "$SWIFT_ARCH" -c "$BUILD_CONFIG"
fi

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    echo "Expected executable not found at $EXECUTABLE_PATH" >&2
    exit 1
fi

STAGING_DIR="$PROJECT_ROOT/build/$SWIFT_ARCH"
APP_BUNDLE="$STAGING_DIR/$APP_NAME"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$OUTPUT_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.drawingpad</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$PRODUCT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

install -m 0755 "$EXECUTABLE_PATH" "$MACOS_DIR/$PRODUCT_NAME"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --timestamp=none --sign - "$APP_BUNDLE"
fi

ARCHIVE_NAME="$PRODUCT_NAME-$VERSION-$SWIFT_ARCH.zip"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

rm -f "$ARCHIVE_PATH"
ditto -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"

echo "Created $ARCHIVE_PATH"
