#!/bin/bash
#
# Build "Music Player.app", ad-hoc sign it, and install to /Applications.
#
#   ./build_app.sh              build + install once
#   ./build_app.sh --no-install build the .app next to the sources only
#   ./build_app.sh --watch      keep rebuilding + reinstalling + relaunching on every
#                               change under Sources/ (your live dev loop)
#
set -euo pipefail

APP_NAME="Music Player"
EXEC_NAME="MusicPlayer"
BUNDLE_ID="com.toby.musicplayer"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/$APP_NAME.app"
CONTENTS="$APP/Contents"
DEST="/Applications/$APP_NAME.app"

make_icon() {
  # Best-effort: render a vinyl icon and build AppIcon.icns. Never aborts the build.
  set +e
  local icns="$1"
  local tmp; tmp="$(mktemp -d)"
  local gen="$tmp/gen.swift"
  local master="$tmp/master.png"

  cat > "$gen" <<'SWIFT'
import AppKit
let out = CommandLine.arguments[1]
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let inset: CGFloat = 64
let r = NSRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
let bg = NSBezierPath(roundedRect: r, xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(red: 0.06, green: 0.55, blue: 0.29, alpha: 1),
           ending:   NSColor(red: 0.02, green: 0.18, blue: 0.11, alpha: 1))!
    .draw(in: bg, angle: -90)
let c = NSPoint(x: S/2, y: S/2)
func circle(_ rad: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: c.x-rad, y: c.y-rad, width: rad*2, height: rad*2))
}
NSColor.black.setFill(); circle(330).fill()
NSColor(white: 1, alpha: 0.06).setStroke()
for i in stride(from: 80, through: 320, by: 26) {
    let p = circle(CGFloat(i)); p.lineWidth = 3; p.stroke()
}
NSColor(red: 0.11, green: 0.73, blue: 0.33, alpha: 1).setFill(); circle(120).fill()
NSColor.black.setFill(); circle(20).fill()
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
SWIFT

  swift "$gen" "$master" >/dev/null 2>&1 || { rm -rf "$tmp"; set -e; return 1; }

  local set="$tmp/AppIcon.iconset"; mkdir -p "$set"
  declare -a names=( icon_16x16:16 icon_16x16@2x:32 icon_32x32:32 icon_32x32@2x:64 \
                     icon_128x128:128 icon_128x128@2x:256 icon_256x256:256 \
                     icon_256x256@2x:512 icon_512x512:512 icon_512x512@2x:1024 )
  for n in "${names[@]}"; do
    sips -z "${n##*:}" "${n##*:}" "$master" --out "$set/${n%%:*}.png" >/dev/null 2>&1
  done

  iconutil -c icns "$set" -o "$icns" >/dev/null 2>&1
  local rc=$?
  rm -rf "$tmp"
  set -e
  return $rc
}

build_and_install() {
  echo "==> swift build -c release"
  swift build -c release --package-path "$HERE"
  local bin="$HERE/.build/release/$EXEC_NAME"

  echo "==> assembling $APP_NAME.app"
  rm -rf "$APP"
  mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
  cp "$bin" "$CONTENTS/MacOS/$EXEC_NAME"

  local icon_key=""
  if make_icon "$CONTENTS/Resources/AppIcon.icns"; then
    icon_key="<key>CFBundleIconFile</key><string>AppIcon</string>"
    echo "    icon: generated"
  else
    echo "    icon: skipped (using default)"
  fi

  cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>                <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>         <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>          <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>          <string>$EXEC_NAME</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>1.0</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>NSHighResolutionCapable</key>     <true/>
    <key>NSPrincipalClass</key>            <string>NSApplication</string>
    <key>LSApplicationCategoryType</key>   <string>public.app-category.music</string>
    $icon_key
    <key>NSAppleEventsUsageDescription</key>
    <string>Music Player controls Spotify to show and manage the track you're playing.</string>
</dict>
</plist>
PLIST

  printf 'APPL????' > "$CONTENTS/PkgInfo"

  # Ad-hoc sign so the app has a code identity (needed for Automation consent).
  codesign --force --deep -s - "$APP" >/dev/null 2>&1 || echo "    (codesign skipped)"

  if [[ "${NO_INSTALL:-0}" == "1" ]]; then
    echo "==> built: $APP"
  else
    echo "==> installing to $DEST"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    echo "    done"
  fi
}

sources_signature() {
  find "$HERE/Sources" "$HERE/Package.swift" -type f -exec stat -f '%m %N' {} + 2>/dev/null \
    | sort | shasum | awk '{print $1}'
}

case "${1:-}" in
  --no-install)
    NO_INSTALL=1 build_and_install
    ;;
  --watch)
    echo "Watching Sources/ — edit a file and the installed app updates automatically."
    echo "Press Ctrl-C to stop."
    build_and_install
    pkill -x "$EXEC_NAME" 2>/dev/null || true
    open "$DEST"
    last="$(sources_signature)"
    while true; do
      sleep 1
      cur="$(sources_signature)"
      if [[ "$cur" != "$last" ]]; then
        echo ""
        echo "==> change detected, rebuilding…"
        if build_and_install; then
          pkill -x "$EXEC_NAME" 2>/dev/null || true
          open "$DEST"
        fi
        last="$cur"
      fi
    done
    ;;
  "")
    build_and_install
    echo ""
    echo "Launch it from /Applications or:  open \"$DEST\""
    ;;
  *)
    echo "usage: ./build_app.sh [--no-install | --watch]"; exit 1
    ;;
esac
