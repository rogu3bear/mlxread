#!/bin/bash
# Deterministic local synthesis benchmark.
#
# Usage: script/benchmark.sh [soprano|kokoro|all]   (default: all)
#
# Requires the corresponding model(s) to be downloaded (first run downloads).
# Reports only measured values, parsed from the benchmark test output.
set -euo pipefail

cd "$(dirname "$0")/.."

WHICH="${1:-all}"
case "$WHICH" in
  soprano) FILTER=(-only-testing:MLXReadTests/BenchmarkTests/testBenchmarkSoprano) ;;
  kokoro)  FILTER=(-only-testing:MLXReadTests/BenchmarkTests/testBenchmarkKokoro) ;;
  all)     FILTER=(-only-testing:MLXReadTests/BenchmarkTests) ;;
  *) echo "usage: $0 [soprano|kokoro|all]" >&2; exit 2 ;;
esac

LOG="$(mktemp -t mlxread-benchmark)"
export TEST_RUNNER_MLXREAD_BENCHMARK=1

# Own DerivedData: Release benchmark builds never contend with Debug work.
# ENABLE_TESTABILITY is required for @testable import in Release.
set +e
xcodebuild test \
  -project MLXRead.xcodeproj \
  -scheme MLXRead \
  -configuration Release \
  -derivedDataPath build/DerivedDataBench \
  -destination 'platform=macOS,arch=arm64' \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  ENABLE_TESTABILITY=YES \
  ONLY_ACTIVE_ARCH=YES \
  "${FILTER[@]}" > "$LOG" 2>&1
STATUS=$?
set -e

echo
echo "== MLXRead synthesis benchmark =="
if ! grep -q '^BENCHMARK|' "$LOG"; then
  echo "No benchmark output produced. Tail of log:" >&2
  tail -30 "$LOG" >&2
  exit 1
fi
grep '^BENCHMARK|' "$LOG" | sed 's/^BENCHMARK|/  /' | awk -F= '
  /model/      { print "\nModel: " $2; next }
  { printf "  %-24s %s\n", $1":", $2 }
'
echo
if [[ $STATUS -ne 0 ]]; then
  echo "warning: xcodebuild exited nonzero ($STATUS); check $LOG" >&2
  exit $STATUS
fi
echo "Full log: $LOG"
