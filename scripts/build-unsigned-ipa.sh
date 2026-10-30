#!/bin/sh
# Builds build/Flashcards-unsigned.ipa for sideloading (for example with LiveContainer, which signs it itself).
set -eu
cd "$(dirname "$0")/.."

scripts/bootstrap.sh

DERIVED=build/ipa-derived
rm -rf "$DERIVED" build/Payload build/Flashcards-unsigned.ipa

xcodebuild build \
  -project Flashcards.xcodeproj \
  -scheme Flashcards \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  | tail -3

APP="$DERIVED/Build/Products/Release-iphoneos/Flashcards.app"
[ -d "$APP" ] || { echo "Build did not produce $APP" >&2; exit 1; }

mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry Flashcards-unsigned.ipa Payload)
rm -rf build/Payload

echo "Created build/Flashcards-unsigned.ipa"
ls -lh build/Flashcards-unsigned.ipa
