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
TAG="${RELEASE_TAG:-v0.1.0}"

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

# 3) Submit to Apple's notary service and wait for the verdict.
echo "==> Submitting to Apple (this usually takes 1-5 minutes)"
set +e
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait | tee /tmp/mlxread-notary.out
SUBMIT_STATUS=${PIPESTATUS[0]}
set -e
if [[ $SUBMIT_STATUS -ne 0 ]] || grep -q "status: Invalid" /tmp/mlxread-notary.out; then
  ID=$(awk '/^ *id:/{print $2; exit}' /tmp/mlxread-notary.out)
  echo "==> Notarization did not pass. Detailed log:" >&2
  [[ -n "$ID" ]] && xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2 || true
  exit 1
fi

# 4) Staple the ticket into the app so it verifies offline, then re-zip.
echo "==> Stapling and re-zipping"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# 5) Confirm Gatekeeper now accepts it (should say "accepted").
echo "==> Gatekeeper assessment"
spctl -a -vvv "$APP"

# 6) Update the GitHub release asset, if gh + the release exist.
if command -v gh >/dev/null 2>&1 && gh release view "$TAG" >/dev/null 2>&1; then
  echo "==> Updating GitHub release $TAG asset"
  gh release upload "$TAG" "$ZIP" --clobber
fi

echo
echo "==> Done: notarized, stapled, and published. No Gatekeeper prompt for users."
