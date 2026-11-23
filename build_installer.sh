#!/bin/bash
# Builds Tickdesk.app, then packages it as:
#   dist/Tickdesk-<version>.dmg  (drag-to-Applications disk image)
#   dist/Tickdesk-<version>.pkg  (standard macOS Installer package)
#   dist/Tickdesk-<version>.zip  (the .pkg + How to Install.txt)
#   dist/How to Install.txt   (also inside the .dmg and the .zip)
set -euo pipefail
cd "$(dirname "$0")"

./build_app.sh
APP=build/Tickdesk.app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
mkdir -p dist
rm -f "dist/Tickdesk-$VERSION.dmg" "dist/Tickdesk-$VERSION.pkg" "dist/Tickdesk-$VERSION.zip"
GUIDE="Installer/How to Install.txt"

# ---- DMG ----
STAGE=$(mktemp -d)
ditto "$APP" "$STAGE/Tickdesk.app"
ln -s /Applications "$STAGE/Applications"
cp "$GUIDE" "$STAGE/"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
hdiutil create -volname "Tickdesk" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$STAGE.rw.dmg" >/dev/null
# Give the mounted volume the app's icon.
MNT=$(hdiutil attach -nobrowse -noautoopen "$STAGE.rw.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
SetFile -a C "$MNT" 2>/dev/null || true
hdiutil detach "$MNT" -quiet
hdiutil convert "$STAGE.rw.dmg" -format UDZO -imagekey zlib-level=9 -o "dist/Tickdesk-$VERSION.dmg" >/dev/null
rm -rf "$STAGE" "$STAGE.rw.dmg"
codesign --force -s - "dist/Tickdesk-$VERSION.dmg"

# ---- PKG ----
ROOT=$(mktemp -d)
mkdir -p "$ROOT/Applications"
ditto "$APP" "$ROOT/Applications/Tickdesk.app"
# Always install to /Applications (don't "relocate" to another copy found on disk).
pkgbuild --analyze --root "$ROOT" "$ROOT.plist" >/dev/null
/usr/libexec/PlistBuddy -c "Add :0:BundleIsRelocatable bool false" "$ROOT.plist"
pkgbuild --root "$ROOT" \
         --component-plist "$ROOT.plist" \
         --identifier app.tickdesk.clock.pkg \
         --version "$VERSION" \
         --install-location / \
         "dist/Tickdesk-$VERSION.pkg" >/dev/null
rm -rf "$ROOT" "$ROOT.plist"

# ---- ZIP (pkg + install guide) and loose guide ----
cp "$GUIDE" "dist/How to Install.txt"
ZIPDIR="$(mktemp -d)/Tickdesk-$VERSION"
mkdir -p "$ZIPDIR"
cp "dist/Tickdesk-$VERSION.pkg" "$GUIDE" "$ZIPDIR/"
ditto -c -k --norsrc --noextattr --keepParent "$ZIPDIR" "dist/Tickdesk-$VERSION.zip"
rm -rf "$(dirname "$ZIPDIR")"

echo "Installers:"
ls -lh dist/
