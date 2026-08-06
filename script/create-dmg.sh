#!/bin/bash
# Create the human-facing MLXRead installer image from an existing app bundle.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="${1:-dist/MLXRead.app}"
DMG="${2:-dist/MLXRead.dmg}"
VOLUME_NAME="${MLXREAD_DMG_VOLUME_NAME:-MLXRead}"

[[ -d "$APP" ]] || { echo "error: app bundle not found: $APP" >&2; exit 1; }
command -v hdiutil >/dev/null 2>&1 || { echo "error: hdiutil is required" >&2; exit 1; }

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/mlxread-dmg.XXXXXX")"
cleanup() {
  rm -rf "$STAGING"
}
trap cleanup EXIT

mkdir -p "$(dirname "$DMG")"
ditto "$APP" "$STAGING/MLXRead.app"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

echo "    $DMG ($(du -h "$DMG" | cut -f1))"
