#!/bin/bash
# Keep dist/MLXRead.app (the signed, notarized release) as the ONLY runnable
# copy on disk. Every `xcodebuild` necessarily emits an app into DerivedData —
# Debug, Release, and the separate benchmark tree — so this trashes those
# scattered copies (and their .dSYMs) to stop you from accidentally launching a
# stale or unsigned one. It uses the Trash (reversible), never rm, and never
# touches dist/ or anything installed in /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep Spotlight from surfacing anything under build/, so a stray build never
# shows up in a search you might click.
mkdir -p build
touch build/.metadata_never_index

shopt -s nullglob
targets=()
for p in build/DerivedData/Build/Products/*/MLXRead.app \
         build/DerivedData/Build/Products/*/MLXRead.app.dSYM \
         build/DerivedDataBench/Build/Products/*/MLXRead.app \
         build/DerivedDataBench/Build/Products/*/MLXRead.app.dSYM; do
  targets+=("$p")
done

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "Nothing scattered — no build-dir MLXRead.app to clean."
else
  echo "Trashing ${#targets[@]} scattered build product(s):"
  printf '  %s\n' "${targets[@]}"
  if command -v trash >/dev/null 2>&1; then
    trash "${targets[@]}"
  else
    mkdir -p "$HOME/.Trash"
    for t in "${targets[@]}"; do mv "$t" "$HOME/.Trash/MLXRead-cleaned-$(basename "$t")-$$"; done
  fi
  echo "Trashed."
fi

echo
echo "Runnable MLXRead.app copies now on disk:"
find . -name 'MLXRead.app' -prune 2>/dev/null | sed 's/^/  /'
