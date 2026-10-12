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
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-mlxread}"
REPO_SLUG="${RELEASE_REPO:-rogu3bear/mlxread}"
APP="dist/MLXRead.app"
ZIP="dist/MLXRead.zip"
DMG="dist/MLXRead.dmg"
APPCAST="dist/appcast.xml"
VERSION="$(awk '$1 == "MARKETING_VERSION:" { print $2; exit }' project.yml)"
BUILD_VERSION="$(awk '$1 == "CURRENT_PROJECT_VERSION:" { print $2; exit }' project.yml)"
TAG="${RELEASE_TAG:-v$VERSION}"
RELEASE_CONTRACT="script/release-contract.sh"

# Publication is part of this command's contract. Fail before expensive build
# and notarization work if the destination cannot be reached.
command -v gh >/dev/null 2>&1 || { echo "error: gh is required to publish release assets" >&2; exit 1; }
gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1 || { echo "error: GitHub release $REPO_SLUG/$TAG does not exist or is inaccessible" >&2; exit 1; }

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

# A release asset must identify the exact tagged source that produced it and
# must carry a usable update configuration. Untracked operator files are
# intentionally ignored because they are outside the XcodeGen source graph.
bash "$RELEASE_CONTRACT" verify \
  --repo "$PWD" --app "$APP" --tag "$TAG" --repo-slug "$REPO_SLUG"

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

# Generate the signed feed from the exact final ZIP. Hosting it as a release
# asset avoids a source/appcast/tag cycle while keeping the app's feed URL
# stable through GitHub's latest-release redirect.
APPCAST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mlxread-appcast.XXXXXX")"
trap 'rm -rf "$APPCAST_DIR"' EXIT
cp "$ZIP" "$APPCAST_DIR/MLXRead.zip"
SPARKLE_BIN="$(find build/DerivedData/SourcePackages/artifacts -path '*Sparkle/bin/generate_appcast' -type f -perm -111 | head -1)"
[[ -x "$SPARKLE_BIN" ]] || { echo "error: Sparkle generate_appcast tool not found" >&2; exit 1; }
rm -f "$APPCAST"
"$SPARKLE_BIN" \
  --account "$SPARKLE_ACCOUNT" \
  --download-url-prefix "https://github.com/$REPO_SLUG/releases/download/$TAG/" \
  --link "https://mlxread.com" \
  --maximum-deltas 0 \
  -o "$APPCAST" \
  "$APPCAST_DIR"
bash "$RELEASE_CONTRACT" verify-appcast \
  --appcast "$APPCAST" --tag "$TAG" --version "$VERSION" \
  --build "$BUILD_VERSION" --repo-slug "$REPO_SLUG"

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

# 7) Recheck the final app identity, then publish all three contracts: DMG for
# people, ZIP for Sparkle, and the signed appcast that binds them.
bash "$RELEASE_CONTRACT" verify \
  --repo "$PWD" --app "$APP" --tag "$TAG" --repo-slug "$REPO_SLUG"
echo "==> Updating GitHub release $TAG assets"
gh release upload "$TAG" "$DMG" "$ZIP" "$APPCAST" --repo "$REPO_SLUG" --clobber

echo
echo "==> Done: notarized, stapled, and published DMG + signed Sparkle feed."
