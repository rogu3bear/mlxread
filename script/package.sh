#!/bin/bash
# Produce a distributable build at dist/MLXRead.app (+ dist/MLXRead.zip).
#
# Signing is controlled by env passthrough. For a PUBLIC release, sign with a
# Developer ID identity (+ the hardened runtime the Release config already
# enables, which strips get-task-allow — TM-001):
#
#   DEVELOPMENT_TEAM=4JB58L7BTZ \
#   CODE_SIGN_IDENTITY="Developer ID Application: MLNavigator Inc. (4JB58L7BTZ)" \
#   CODE_SIGN_STYLE=Manual OTHER_CODE_SIGN_FLAGS=--timestamp \
#     script/package.sh
#
# This script does NOT notarize. A Developer ID build still needs notarization
# for zero-friction Gatekeeper; run notarytool separately (see README).
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED=build/DerivedData
CONFIGURATION=Release
APP="$DERIVED/Build/Products/$CONFIGURATION/MLXRead.app"

SIGN_OVERRIDE=()
[[ -n "${DEVELOPMENT_TEAM:-}" ]] && SIGN_OVERRIDE+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
[[ -n "${CODE_SIGN_IDENTITY:-}" ]] && SIGN_OVERRIDE+=("CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")
[[ -n "${CODE_SIGN_STYLE:-}" ]] && SIGN_OVERRIDE+=("CODE_SIGN_STYLE=$CODE_SIGN_STYLE")
[[ -n "${OTHER_CODE_SIGN_FLAGS:-}" ]] && SIGN_OVERRIDE+=("OTHER_CODE_SIGN_FLAGS=$OTHER_CODE_SIGN_FLAGS")
# A Developer ID build takes no provisioning profile; allow explicitly clearing.
if [[ -n "${CLEAR_PROVISIONING:-}" ]]; then
  SIGN_OVERRIDE+=("PROVISIONING_PROFILE_SPECIFIER=")
fi
# For distribution, suppress the injected base entitlements (get-task-allow),
# which a plain `xcodebuild build` otherwise adds even in Release. Absent
# get-task-allow is required to notarize and closes TM-001.
[[ -n "${INJECT_BASE_ENTITLEMENTS:-}" ]] && SIGN_OVERRIDE+=("CODE_SIGN_INJECT_BASE_ENTITLEMENTS=$INJECT_BASE_ENTITLEMENTS")

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
codesign -dvvv dist/MLXRead.app 2>&1 | grep -E '^(Identifier|Authority|TeamIdentifier|Signature|CodeDirectory)' || true
echo "==> Gatekeeper assessment (rejects until notarized)"
spctl -a -vv dist/MLXRead.app || true

echo "==> Zipping (ditto, preserves symlinks/signature)"
rm -f dist/MLXRead.zip
ditto -c -k --keepParent dist/MLXRead.app dist/MLXRead.zip
echo "    dist/MLXRead.zip ($(du -h dist/MLXRead.zip | cut -f1))"

echo
echo "Packaged: dist/MLXRead.app + dist/MLXRead.zip"
