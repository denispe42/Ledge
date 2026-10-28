#!/bin/zsh
# Builds a universal (arm64 + x86_64) Ledge.app into dist/ and, with --dmg, a Ledge-<version>.dmg.
# Signing: the local self-signed certificate "Ledge Local Signing" if it is in the keychain (a stable identity, so macOS
# keeps permissions such as Accessibility across rebuilds), otherwise ad-hoc. FUTURE: for a paid Apple Developer ID set SIGN_IDENTITY="Developer ID Application: ..."
# and (optionally) NOTARY_PROFILE=<notarytool keychain profile>; the hooks below are ready for it.
set -euo pipefail
cd "${0:A:h}/.."

VERSION="${VERSION:-0.1.0}"
if [[ -z "${SIGN_IDENTITY:-}" ]]; then
  if security find-identity -p codesigning | grep -q "Ledge Local Signing"; then SIGN_IDENTITY="Ledge Local Signing"; else SIGN_IDENTITY="-"; fi
fi   # "-" = ad-hoc
APP="dist/Ledge.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Ledge"

rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ledge"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
# Localizations (*.lproj) are copied when present.
for d in Resources/*.lproj(N); do cp -R "$d" "$APP/Contents/Resources/"; done

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"
lipo -archs "$APP/Contents/MacOS/Ledge"
echo "Built $APP (version $VERSION, signed with '$SIGN_IDENTITY')"

if [[ "${1:-}" == "--dmg" ]]; then
  DMG="dist/Ledge-$VERSION.dmg"
  STAGE="$(mktemp -d)"
  cp -R "$APP" "$STAGE/" && ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname "Ledge" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  # FUTURE (paid signing): codesign the dmg, then: xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait; xcrun stapler staple "$DMG"
  echo "Built $DMG"
fi
