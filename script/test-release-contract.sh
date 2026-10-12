#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERIFY="$ROOT/script/release-contract.sh"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/mlxread-release-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output="$($@ 2>&1)"; then
    fail "expected command to fail: $*"
  fi
  [[ "$output" == *"$expected"* ]] || fail "expected '$expected' in: $output"
}

mkdir -p "$FIXTURE/repo/MLXRead.app/Contents"
git -C "$FIXTURE/repo" init -q
git -C "$FIXTURE/repo" config user.name "Release Contract Test"
git -C "$FIXTURE/repo" config user.email "release-contract@example.invalid"

cat > "$FIXTURE/repo/project.yml" <<'YAML'
settings:
  base:
    MARKETING_VERSION: 1.2.3
    CURRENT_PROJECT_VERSION: 42
YAML

cat > "$FIXTURE/repo/MLXRead.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key><string>1.2.3</string>
  <key>CFBundleVersion</key><string>42</string>
  <key>MLXReadSourceRevision</key><string>SOURCE_REVISION</string>
  <key>SUFeedURL</key><string>https://github.com/rogu3bear/mlxread/releases/latest/download/appcast.xml</string>
  <key>SUPublicEDKey</key><string>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</string>
</dict>
</plist>
PLIST

git -C "$FIXTURE/repo" add project.yml
git -C "$FIXTURE/repo" commit -qm "fixture"
REVISION="$(git -C "$FIXTURE/repo" rev-parse HEAD)"
sed -i '' "s/SOURCE_REVISION/$REVISION/" "$FIXTURE/repo/MLXRead.app/Contents/Info.plist"
git -C "$FIXTURE/repo" tag v1.2.3

"$VERIFY" verify \
  --repo "$FIXTURE/repo" \
  --app "$FIXTURE/repo/MLXRead.app" \
  --tag v1.2.3 \
  --repo-slug rogu3bear/mlxread

expect_failure "release tag must be v1.2.3" \
  "$VERIFY" verify --repo "$FIXTURE/repo" --app "$FIXTURE/repo/MLXRead.app" \
  --tag v1.2.2 --repo-slug rogu3bear/mlxread

/usr/libexec/PlistBuddy -c "Set :MLXReadSourceRevision deadbeef" "$FIXTURE/repo/MLXRead.app/Contents/Info.plist"
expect_failure "artifact source revision" \
  "$VERIFY" verify --repo "$FIXTURE/repo" --app "$FIXTURE/repo/MLXRead.app" \
  --tag v1.2.3 --repo-slug rogu3bear/mlxread
/usr/libexec/PlistBuddy -c "Set :MLXReadSourceRevision $REVISION" "$FIXTURE/repo/MLXRead.app/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey REPLACE_WITH_generate_keys_PUBLIC_KEY" "$FIXTURE/repo/MLXRead.app/Contents/Info.plist"
expect_failure "placeholder Sparkle public key" \
  "$VERIFY" verify --repo "$FIXTURE/repo" --app "$FIXTURE/repo/MLXRead.app" \
  --tag v1.2.3 --repo-slug rogu3bear/mlxread

cat > "$FIXTURE/appcast.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel><item>
    <sparkle:version>42</sparkle:version>
    <sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>
    <enclosure url="https://github.com/rogu3bear/mlxread/releases/download/v1.2.3/MLXRead.zip"
      length="1234" sparkle:edSignature="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==" />
  </item></channel>
</rss>
XML

"$VERIFY" verify-appcast --appcast "$FIXTURE/appcast.xml" --tag v1.2.3 \
  --version 1.2.3 --build 42 --repo-slug rogu3bear/mlxread

sed -i '' 's/length="1234"/length="0"/' "$FIXTURE/appcast.xml"
expect_failure "non-zero enclosure length" \
  "$VERIFY" verify-appcast --appcast "$FIXTURE/appcast.xml" --tag v1.2.3 \
  --version 1.2.3 --build 42 --repo-slug rogu3bear/mlxread

echo "PASS: release identity, Sparkle configuration, and appcast fail closed"
