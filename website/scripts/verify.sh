#!/usr/bin/env bash
#
# Local release-readiness gate for the MLXRead site.
# Run before deploying or claiming a change is complete.
set -euo pipefail

echo "==> 1/4 Formatting"
cargo fmt --check

echo "==> 2/4 SSR compile check"
cargo check --features ssr

echo "==> 3/4 Full edge build (WASM + hashed assets + worker bundle + verifiers)"
bash ./scripts/build-edge.sh

echo "==> 4/4 Wrangler deployment structure validation"
bunx wrangler@4.83.0 deploy --dry-run

echo ""
echo "==> All checks passed."
