#!/usr/bin/env bash
# Build Principle in release mode and assemble a launchable .app bundle.
# Usage: bash scripts/make-app.sh   [INSTALL_DIR=/some/dir]
set -euo pipefail

APP_NAME="Principle"
MIN_SYSTEM_VERSION="14.0"

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications}"
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"

cd "$PACKAGE_DIR"

# Single source of truth for the version and the bundle id is PrincipleCore,
# not this script. The id is not cosmetic: `AppSettings.defaultsSuite` *is* the
# bundle identifier, and macOS keys the app's TCC grants off it too — a copy
# here that drifted from the library would move the shipped app to an empty
# preferences domain and make the system treat it as an app it has never seen.
info() {
    sed -n "s/.*static let $1 = \"\([^\"]*\)\".*/\1/p" \
        Sources/PrincipleCore/PrincipleCore.swift | head -n 1
}

VERSION="$(info version)"
BUNDLE_ID="$(info bundleIdentifier)"
for pair in "version:$VERSION" "bundleIdentifier:$BUNDLE_ID"; do
    if [[ -z "${pair#*:}" ]]; then
        echo "error: could not read ${pair%%:*} from Sources/PrincipleCore/PrincipleCore.swift" >&2
        exit 1
    fi
done

echo "==> Building $APP_NAME $VERSION (release)"
swift build -c release --product "$APP_NAME"
BIN_DIR="$(swift build -c release --product "$APP_NAME" --show-bin-path)"
BINARY="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BINARY" ]]; then
    echo "error: built binary not found at $BINARY" >&2
    exit 1
fi

echo "==> Assembling $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# SwiftPM emits bundles next to the binary; carry them into Resources so
# Bundle.module keeps resolving inside the app.
for resource_bundle in "$BIN_DIR"/*.bundle; do
    [[ -e "$resource_bundle" ]] || continue
    cp -R "$resource_bundle" "$APP_BUNDLE/Contents/Resources/"
done

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>vi</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_SYSTEM_VERSION</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP_BUNDLE/Contents/PkgInfo"

# Ad-hoc signature: unsigned bundles get killed on launch on Apple silicon.
echo "==> Signing (ad-hoc)"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "    open \"$APP_BUNDLE\""
