#!/bin/bash
#
# Build "Music Player.app" and package it into a distributable DMG with a drag-to-install
# Applications shortcut.  ->  ./make_dmg.sh   (produces "Music Player.dmg")
#
set -euo pipefail

APP_NAME="Music Player"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/$APP_NAME.app"
DMG="$HERE/$APP_NAME.dmg"

echo "==> building app bundle"
"$HERE/build_app.sh" --no-install

echo "==> staging disk image"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $DMG"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "Done: $DMG"
echo "Open it and drag '${APP_NAME}' onto Applications to install."
