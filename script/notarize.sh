#!/bin/bash
#
# One command to notarize, staple, and publish the MLXRead release.
#
#   ./script/notarize.sh            # build if needed, notarize, staple, upload
#   ./script/notarize.sh --rebuild  # force a fresh Developer ID build first
#
# The FIRST run prompts once for your Apple ID and an app-specific password
# (create one at https://appleid.apple.com -> Sign-In & Security -> App-Specific
# Passwords) and stores them securely in your Keychain. Every run after that is
# fully automatic. Nothing sensitive is ever printed or committed.
set -euo pipefail

cd "$(dirname "$0")/.."

PROFILE="${NOTARY_PROFILE:-mlxread-notary}"
TEAM_ID="${NOTARY_TEAM_ID:-4JB58L7BTZ}"
IDENTITY="Developer ID Application: MLNavigator Inc. (${TEAM_ID})"
APP="dist/MLXRead.app"
ZIP="dist/MLXRead.zip"
DMG="dist/MLXRead.dmg"
TAG="${RELEASE_TAG:-v0.1.0}"

# Publication is part of this command's contract. Fail before expensive build
# and notarization work if the destination cannot be reached.
command -v gh >/dev/null 2>&1 || { echo "error: gh is required to publish release assets" >&2; exit 1; }
gh release view "$TAG" >/dev/null 2>&1 || { echo "error: GitHub release $TAG does not exist or is inaccessible" >&2; exit 1; }

# 1) Build the Developer ID app if it's missing (or --rebuild).
if [[ "${1:-}" == "--rebuild" || ! -d "$APP" ]]; then
  echo "==> Building Developer ID release"
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_IDENTITY="$IDENTITY" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  CLEAR_PROVISIONING=1 \
  INJECT_BASE_ENTITLEMENTS=NO \
    bash script/package.sh
fi

[[ -f "$ZIP" ]] || { echo "error: $ZIP not found; run with --rebuild" >&2; exit 1; }

# 2) One-time credential setup (interactive, stored in Keychain).
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  echo "==> One-time notarization setup (Keychain profile '$PROFILE')"
  echo "    You'll be asked for your Apple ID and an app-specific password."
  echo "    App-specific passwords: https://appleid.apple.com -> Sign-In & Security"
  echo
  if [[ -n "${NOTARY_APPLE_ID:-}" && -n "${NOTARY_PASSWORD:-}" ]]; then
    xcrun notarytool store-credentials "$PROFILE" \
      --apple-id "$NOTARY_APPLE_ID" --team-id "$TEAM_ID" --password "$NOTARY_PASSWORD"
  else
    xcrun notarytool store-credentials "$PROFILE" --team-id "$TEAM_ID"
  fi
fi

submit_notarization() {
  local artifact="$1"
  local output
  local submit_status
  local id

  output="$(mktemp "${TMPDIR:-/tmp}/mlxread-notary.XXXXXX")"
  echo "==> Submitting $artifact to Apple (this usually takes 1-5 minutes)"
  set +e
  xcrun notarytool submit "$artifact" --keychain-profile "$PROFILE" --wait | tee "$output"
  submit_status=${PIPESTATUS[0]}
  set -e
  if [[ $submit_status -ne 0 ]] || grep -q "status: Invalid" "$output"; then
    id=$(awk '/^ *id:/{print $2; exit}' "$output")
    echo "==> Notarization did not pass. Detailed log:" >&2
    [[ -n "$id" ]] && xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 || true
    rm -f "$output"
    exit 1
  fi
  rm -f "$output"
}

# 3) Notarize the update archive so the contained app receives a ticket.
submit_notarization "$ZIP"

# 4) Staple the app for offline verification, then rebuild both release assets.
echo "==> Stapling app and rebuilding release assets"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
bash script/create-dmg.sh "$APP" "$DMG"

# 5) Sign, verify, notarize, and staple the container a person actually downloads.
echo "==> Signing installer image"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
codesign --verify --verbose=4 "$DMG"
submit_notarization "$DMG"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 6) Confirm Gatekeeper now accepts the installed app (should say "accepted").
echo "==> Gatekeeper assessment"
spctl -a -vvv "$APP"

# 7) Publish both contracts: DMG for people, ZIP for Sparkle updates.
echo "==> Updating GitHub release $TAG assets"
gh release upload "$TAG" "$DMG" "$ZIP" --clobber

echo
echo "==> Done: notarized, stapled, and published DMG + Sparkle ZIP."
