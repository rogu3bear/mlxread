#!/bin/bash
# Validate that a packaged MLXRead app is bound to the exact tagged source and
# to a usable Sparkle feed before any release asset is published.
set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

project_value() {
  local key="$1"
  local file="$2"
  awk -v key="$key" '$1 == key ":" { gsub(/^[^:]+:[[:space:]]*/, ""); gsub(/[\047\042]/, ""); print; exit }' "$file"
}

plist_value() {
  local key="$1"
  local plist="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

verify_release() {
  local repo=""
  local app=""
  local tag=""
  local repo_slug=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo="${2:-}"; shift 2 ;;
      --app) app="${2:-}"; shift 2 ;;
      --tag) tag="${2:-}"; shift 2 ;;
      --repo-slug) repo_slug="${2:-}"; shift 2 ;;
      *) fail "unknown verify argument: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || fail "--repo is required"
  [[ -n "$app" ]] || fail "--app is required"
  [[ -n "$tag" ]] || fail "--tag is required"
  [[ -n "$repo_slug" ]] || fail "--repo-slug is required"
  [[ -d "$repo/.git" ]] || fail "not a Git checkout: $repo"
  [[ -f "$repo/project.yml" ]] || fail "project.yml not found in $repo"

  local plist="$app/Contents/Info.plist"
  [[ -f "$plist" ]] || fail "packaged Info.plist not found: $plist"

  local marketing_version
  local build_version
  marketing_version="$(project_value MARKETING_VERSION "$repo/project.yml")"
  build_version="$(project_value CURRENT_PROJECT_VERSION "$repo/project.yml")"
  [[ -n "$marketing_version" ]] || fail "MARKETING_VERSION is missing from project.yml"
  [[ -n "$build_version" ]] || fail "CURRENT_PROJECT_VERSION is missing from project.yml"

  local expected_tag="v$marketing_version"
  [[ "$tag" == "$expected_tag" ]] || fail "release tag must be $expected_tag for MARKETING_VERSION $marketing_version (got $tag)"

  git -C "$repo" diff --quiet -- || fail "tracked source has unstaged changes"
  git -C "$repo" diff --cached --quiet -- || fail "tracked source has staged changes"

  local head_revision
  local tag_revision
  head_revision="$(git -C "$repo" rev-parse HEAD)"
  tag_revision="$(git -C "$repo" rev-parse "$tag^{commit}" 2>/dev/null)" || fail "release tag does not exist locally: $tag"
  [[ "$tag_revision" == "$head_revision" ]] || fail "release tag $tag points to $tag_revision, not HEAD $head_revision"

  local artifact_version
  local artifact_build
  local artifact_revision
  artifact_version="$(plist_value CFBundleShortVersionString "$plist")"
  artifact_build="$(plist_value CFBundleVersion "$plist")"
  artifact_revision="$(plist_value MLXReadSourceRevision "$plist")"
  [[ "$artifact_version" == "$marketing_version" ]] || fail "artifact marketing version $artifact_version does not match project $marketing_version"
  [[ "$artifact_build" == "$build_version" ]] || fail "artifact build version $artifact_build does not match project $build_version"
  [[ "$artifact_revision" == "$head_revision" ]] || fail "artifact source revision $artifact_revision does not match tagged HEAD $head_revision"

  local feed_url
  local public_key
  local expected_feed="https://github.com/$repo_slug/releases/latest/download/appcast.xml"
  feed_url="$(plist_value SUFeedURL "$plist")"
  public_key="$(plist_value SUPublicEDKey "$plist")"
  [[ "$feed_url" == "$expected_feed" ]] || fail "Sparkle feed must be $expected_feed (got $feed_url)"
  [[ "$public_key" != *OWNER* && "$public_key" != *REPLACE* && "$public_key" != *example.com* ]] || fail "artifact contains a placeholder Sparkle public key"
  [[ -n "$public_key" ]] || fail "artifact has no Sparkle public key"

  local decoded_key_size
  decoded_key_size="$(printf '%s' "$public_key" | /usr/bin/base64 -D 2>/dev/null | wc -c | tr -d ' ')" || fail "Sparkle public key is not valid base64"
  [[ "$decoded_key_size" == "32" ]] || fail "Sparkle public key must decode to 32 bytes (got $decoded_key_size)"

  echo "release-contract: PASS $tag $head_revision (build $build_version)"
}

xml_value() {
  local expression="$1"
  local file="$2"
  xmllint --xpath "string($expression)" "$file" 2>/dev/null || true
}

verify_appcast() {
  local appcast=""
  local tag=""
  local version=""
  local build=""
  local repo_slug=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --appcast) appcast="${2:-}"; shift 2 ;;
      --tag) tag="${2:-}"; shift 2 ;;
      --version) version="${2:-}"; shift 2 ;;
      --build) build="${2:-}"; shift 2 ;;
      --repo-slug) repo_slug="${2:-}"; shift 2 ;;
      *) fail "unknown verify-appcast argument: $1" ;;
    esac
  done

  [[ -f "$appcast" ]] || fail "appcast not found: $appcast"
  [[ -n "$tag" && -n "$version" && -n "$build" && -n "$repo_slug" ]] || fail "verify-appcast requires --tag, --version, --build, and --repo-slug"
  xmllint --noout "$appcast" 2>/dev/null || fail "appcast is not valid XML"

  local item_version
  local item_build
  local enclosure_url
  local enclosure_length
  local signature
  item_version="$(xml_value '//*[local-name()="shortVersionString"]' "$appcast")"
  item_build="$(xml_value '//*[local-name()="version"]' "$appcast")"
  enclosure_url="$(xml_value '//*[local-name()="enclosure"]/@url' "$appcast")"
  enclosure_length="$(xml_value '//*[local-name()="enclosure"]/@length' "$appcast")"
  signature="$(xml_value '//*[local-name()="enclosure"]/@*[local-name()="edSignature"]' "$appcast")"

  [[ "$item_version" == "$version" ]] || fail "appcast version $item_version does not match release $version"
  [[ "$item_build" == "$build" ]] || fail "appcast build $item_build does not match release $build"
  local expected_url="https://github.com/$repo_slug/releases/download/$tag/MLXRead.zip"
  [[ "$enclosure_url" == "$expected_url" ]] || fail "appcast enclosure must be $expected_url (got $enclosure_url)"
  [[ "$enclosure_length" =~ ^[1-9][0-9]*$ ]] || fail "appcast must contain a non-zero enclosure length"
  [[ -n "$signature" && "$signature" != *REPLACE* ]] || fail "appcast has no release signature"

  local signature_size
  signature_size="$(printf '%s' "$signature" | /usr/bin/base64 -D 2>/dev/null | wc -c | tr -d ' ')" || fail "appcast signature is not valid base64"
  [[ "$signature_size" == "64" ]] || fail "appcast signature must decode to 64 bytes (got $signature_size)"

  echo "release-contract: PASS appcast $tag (build $build, $enclosure_length bytes)"
}

case "${1:-}" in
  verify)
    shift
    verify_release "$@"
    ;;
  verify-appcast)
    shift
    verify_appcast "$@"
    ;;
  *)
    fail "usage: $0 <verify|verify-appcast> ..."
    ;;
esac
