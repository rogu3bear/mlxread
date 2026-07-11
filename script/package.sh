#!/bin/bash
# Produce a distributable local build at dist/MLXRead.app.
# The result is Development-signed (or ad hoc). It is NOT notarized and this
# script never claims otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED=build/DerivedData
CONFIGURATION=Release
APP="$DERIVED/Build/Products/$CONFIGURATION/MLXRead.app"

echo "==> Building ($CONFIGURATION)"
xcodebuild \
  -project MLXRead.xcodeproj \
  -scheme MLXRead \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  build

mkdir -p dist
rm -rf dist/MLXRead.app
cp -R "$APP" dist/MLXRead.app

echo "==> Signing state"
codesign --verify --deep --strict dist/MLXRead.app
codesign -dvvv dist/MLXRead.app 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier|Signature)' || true
echo "==> Gatekeeper assessment (expected to fail for non-notarized dev builds)"
spctl -a -vv dist/MLXRead.app || true

echo
echo "Packaged: dist/MLXRead.app (Development-signed, not notarized)"
