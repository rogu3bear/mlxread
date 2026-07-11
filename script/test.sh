#!/bin/bash
# Run MLXRead tests.
#
# Usage: script/test.sh [--integration] [--ui]
#   default          unit tests only (no network, no model required)
#   --integration    also run model-download + real-synthesis integration tests
#                    (downloads models on first run; network required once)
#   --ui             also run the UI launch smoke test
set -euo pipefail

cd "$(dirname "$0")/.."

INTEGRATION=0
UI=0
for arg in "$@"; do
  case "$arg" in
    --integration) INTEGRATION=1 ;;
    --ui) UI=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

ARGS=(
  -project MLXRead.xcodeproj
  -scheme MLXRead
  -configuration Debug
  -derivedDataPath build/DerivedData
  -skipPackagePluginValidation
  -skipMacroValidation
)

if [[ $INTEGRATION -eq 1 ]]; then
  # TEST_RUNNER_ variables are forwarded into the test process environment.
  export TEST_RUNNER_MLXREAD_INTEGRATION=1
fi

TARGETS=(-only-testing:MLXReadTests)
if [[ $UI -eq 1 ]]; then
  TARGETS+=(-only-testing:MLXReadUITests)
fi

xcodebuild test "${ARGS[@]}" "${TARGETS[@]}"
