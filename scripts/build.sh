#!/bin/bash
# Builds Riffle.app (universal: Apple Silicon + Intel) and a drag-to-install DMG.
# Needs only the Xcode Command Line Tools — full Xcode is not required.
#
#   scripts/build.sh            → build/Riffle.app + dist/Riffle-<version>.dmg
#   scripts/build.sh --install  → also installs into /Applications and refreshes Quick Look
set -euo pipefail

VERSION="1.0.2"
BUILD="3"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build"
DIST="$ROOT/dist"
APP="$OUT/Riffle.app"
APPEX="$APP/Contents/PlugIns/RiffleExt.appex"
SDK="$(xcrun --show-sdk-path)"
MIN_OS="14.0"
ARCHS=(arm64 x86_64)

echo "▸ Riffle $VERSION ($BUILD)"
rm -rf "$OUT/obj" "$APP"
mkdir -p "$OUT/obj" "$DIST"

compile() { # name kind(app|appex) sources...
  local name="$1" kind="$2"; shift 2
  local slices=()
  for arch in "${ARCHS[@]}"; do
    local flags=(${RIFFLE_SWIFT_FLAGS:-} -O -whole-module-optimization -sdk "$SDK" -target "$arch-apple-macos$MIN_OS"
                 -module-name "$name" -emit-executable -o "$OUT/obj/$name-$arch")
    if [[ "$kind" == "appex" ]]; then
      # An .appex is an executable whose entry point is NSExtensionMain, not a bundle.
      flags+=(-parse-as-library -application-extension -Xlinker -e -Xlinker _NSExtensionMain
              -framework QuickLookUI -framework QuickLookThumbnailing -framework WebKit -framework JavaScriptCore)
    fi
    swiftc "${flags[@]}" -framework AppKit "$@"
    slices+=("$OUT/obj/$name-$arch")
  done
  lipo -create "${slices[@]}" -output "$OUT/obj/$name"
}

echo "▸ Compiling extension"
compile RiffleExt appex "$ROOT/Extension/PreviewViewController.swift" "$ROOT/Extension/DocumentRenderer.swift"
echo "▸ Compiling app"
compile Riffle app "$ROOT/App/main.swift"

echo "▸ Assembling bundle"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APPEX/Contents/MacOS" "$APPEX/Contents/Resources"
cp "$OUT/obj/Riffle" "$APP/Contents/MacOS/Riffle"
cp "$OUT/obj/RiffleExt" "$APPEX/Contents/MacOS/RiffleExt"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" "$ROOT/App/Info.plist" > "$APP/Contents/Info.plist"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" "$ROOT/Extension/Info.plist" > "$APPEX/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
printf 'XPC!????' > "$APPEX/Contents/PkgInfo"
cp "$ROOT/Resources/marked.min.js" "$APPEX/Contents/Resources/"
cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE.txt"

# App icon: drawn by scripts/make_icon.swift, cached in Resources/AppIcon.icns.
if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "▸ Drawing icon"
  ICONSET="$OUT/obj/AppIcon.iconset"
  mkdir -p "$ICONSET"
  swift "$ROOT/scripts/make_icon.swift" "$OUT/obj/icon-1024.png" >/dev/null
  for s in 16 32 128 256 512; do
    sips -z $s $s "$OUT/obj/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$OUT/obj/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
fi
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signing (ad-hoc)"
codesign --force --options runtime --sign - --entitlements "$ROOT/Extension/RiffleExt.entitlements" "$APPEX"
codesign --force --options runtime --sign - "$APP"
codesign --verify --deep --strict "$APP"
lipo -archs "$APPEX/Contents/MacOS/RiffleExt" | sed 's/^/  extension archs: /'

echo "▸ Packaging DMG"
STAGE="$OUT/obj/dmg"
rm -rf "$STAGE" && mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/docs/INSTALL.txt" "$STAGE/How to install.txt"
DMG="$DIST/Riffle-$VERSION.dmg"
rm -f "$DMG"
hdiutil create -volname "Riffle" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
shasum -a 256 "$DMG" | tee "$DMG.sha256"
du -h "$DMG" | sed 's/^/  size: /'

if [[ "${1:-}" == "--install" ]]; then
  echo "▸ Installing to /Applications"
  osascript -e 'quit app "Riffle"' 2>/dev/null || true
  rm -rf /Applications/Riffle.app
  cp -R "$APP" /Applications/
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Riffle.app
  pluginkit -a /Applications/Riffle.app/Contents/PlugIns/RiffleExt.appex
  pluginkit -e use -i com.aignix.riffle.preview
  qlmanage -r >/dev/null 2>&1; qlmanage -r cache >/dev/null 2>&1
  sleep 2
  pluginkit -m -i com.aignix.riffle.preview
fi
echo "✓ Done: $APP"
