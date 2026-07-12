#!/bin/bash
# Build MLXRead with xcodebuild, then relaunch the fresh app.
#
# Usage: script/build_and_run.sh [--verify] [--logs] [--telemetry] [--configuration Debug|Release]
#   --verify     after launch, assert the process is running and codesign validates
#   --logs       stream MLXRead's os_log output after launch (Ctrl-C to stop)
#   --telemetry  stream only speech/audio/model timing categories (local os_log only;
#                MLXRead has no analytics or network telemetry)
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIGURATION=Debug
VERIFY=0
LOGS=0
TELEMETRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verify) VERIFY=1 ;;
    --logs) LOGS=1 ;;
    --telemetry) TELEMETRY=1 ;;
    --configuration) CONFIGURATION="$2"; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

DERIVED=build/DerivedData
APP="$DERIVED/Build/Products/$CONFIGURATION/MLXRead.app"

echo "==> Stopping any running MLXRead"
pkill -x MLXRead 2>/dev/null || true

# Contributors override signing without editing tracked files:
#   DEVELOPMENT_TEAM=ABCDE12345 script/build_and_run.sh   # your own team
#   CODE_SIGNING_ALLOWED=NO      script/build_and_run.sh   # quick unsigned build
# A stable signing identity is recommended: the macOS Accessibility (TCC)
# grant is keyed to the code signature, so ad-hoc/unsigned rebuilds re-prompt.
SIGN_OVERRIDE=()
[[ -n "${DEVELOPMENT_TEAM:-}" ]] && SIGN_OVERRIDE+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM")
[[ -n "${CODE_SIGNING_ALLOWED:-}" ]] && SIGN_OVERRIDE+=("CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED")

echo "==> Building ($CONFIGURATION)"
xcodebuild \
  -project MLXRead.xcodeproj \
  -scheme MLXRead \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ${SIGN_OVERRIDE[@]+"${SIGN_OVERRIDE[@]}"} \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: built app not found at $APP" >&2
  exit 1
fi

echo "==> Launching $APP"
open "$APP"

if [[ $VERIFY -eq 1 ]]; then
  echo "==> Verifying"
  sleep 2
  if ! pgrep -x MLXRead >/dev/null; then
    echo "error: MLXRead is not running after launch" >&2
    exit 1
  fi
  echo "    process: running (pid $(pgrep -x MLXRead | head -1))"
  codesign --verify --deep --strict "$APP"
  echo "    codesign: valid ($(codesign -dvvv "$APP" 2>&1 | grep '^Authority' | head -1 || echo 'ad hoc'))"
  echo "    bundle id: $(defaults read "$(pwd)/$APP/Contents/Info" CFBundleIdentifier)"
  echo "==> Verify OK"
fi

if [[ $TELEMETRY -eq 1 ]]; then
  echo "==> Streaming local timing telemetry (Ctrl-C to stop)"
  exec log stream --level info --predicate 'subsystem == "me.jkca.mlxread" AND (category == "speech" OR category == "audio" OR category == "models")'
fi

if [[ $LOGS -eq 1 ]]; then
  echo "==> Streaming logs (Ctrl-C to stop)"
  exec log stream --level debug --predicate 'subsystem == "me.jkca.mlxread"'
fi
