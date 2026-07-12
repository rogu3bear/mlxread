#!/bin/bash
# Produce a distributable local build at dist/MLXRead.app.
# The result is Development-signed (or ad hoc). It is NOT notarized and this
# script never claims otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED=build/DerivedData
CONFIGURATION=Release
APP="$DERIVED/Build/Products/$CONFIGURATION/MLXRead.app"

# Signing override (see build_and_run.sh). For a PUBLIC release, sign with a
# Developer ID identity and notarize — Developer ID + hardened runtime strips
# get-task-allow (TM-001). Example:
#   DEVELOPMENT_TEAM=ABCDE12345 CODE_SIGN_IDENTITY="Developer ID Application" \
#     script/package.sh
SIGN_OVERRIDE=()
[[ -n "${DEVELOPMENT_TEAM:-}" ]] && SIGN_OVERRIDE+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
[[ -n "${CODE_SIGN_IDENTITY:-}" ]] && SIGN_OVERRIDE+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")

echo "==> Building ($CONFIGURATION)"
# Remove any stale product first (a prior hosted-test build can leave an
# xctest bundle inside the app, which breaks release code signing).
rm -rf "$APP"
xcodebuild \
  -project MLXRead.xcodeproj \
  -scheme MLXRead \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ${SIGN_OVERRIDE[@]+"${SIGN_OVERRIDE[@]}"} \
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
