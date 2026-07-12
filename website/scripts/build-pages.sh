#!/usr/bin/env bash
#
# Build the Cloudflare Pages deployment package (advanced mode).
#
# Produces dist-pages/ = static assets at the root + a _worker.js/ directory
# holding the SSR worker wrapped in Pages-compatible Module syntax.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Edge build (WASM + hashed assets + worker bundle)"
bash ./scripts/build-edge.sh

OUT="dist-pages"
echo "==> Assembling $OUT/"
rm -rf "$OUT"
mkdir -p "$OUT/_worker.js"

# Static assets served by Pages (env.ASSETS). Includes _headers, which Pages
# applies natively.
cp -R target/site/. "$OUT/"

# Worker bundle in Pages _worker.js directory form (multi-module + wasm).
cp build/index.js "$OUT/_worker.js/leptos_core.js"
cp build/index_bg.wasm "$OUT/_worker.js/index_bg.wasm"
cp scripts/pages-worker-entry.js "$OUT/_worker.js/index.js"

echo "==> Pages package ready:"
echo "    $OUT/_worker.js/{index.js,leptos_core.js,index_bg.wasm}"
echo "    static assets: $(find "$OUT" -type f -not -path "*/_worker.js/*" | wc -l | tr -d ' ') files"
