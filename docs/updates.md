# Auto-updates (Sparkle)

MLXRead ships with [Sparkle 2](https://sparkle-project.org) for secure,
open-source auto-updates. Updates are delivered as an **EdDSA-signed appcast**
over HTTPS; Sparkle verifies every downloaded archive's signature against the
public key baked into the app **before** installing. A compromised feed host
or a TLS-terminating proxy therefore cannot ship a malicious update without
the maintainer's Ed25519 **private** key. This is the mitigation for threat
**TM-002** (distribution/update integrity) in `mlxread-threat-model.md`.

## How it behaves in the app

- **Menu bar → Check for Updates…** and **Settings → General → Updates**
  (auto-check toggle + "Check Now") appear **only when the build is
  configured** for updates (real feed URL + public key).
- `project.yml` contains the release feed and public key, so a build from the
  checked-in configuration has updates enabled. Clear `SUFeedURL` in a local
  development configuration and regenerate the project to keep the updater
  **inactive** and hide update controls. See
  `MLXRead/Updates/UpdateService.swift` (`looksConfigured`).
- Automatic background checks default on (`SUEnableAutomaticChecks`), daily
  (`SUScheduledCheckInterval = 86400`).

## One-time maintainer setup

The private signing key is a **credential the maintainer owns**. The project
contains its public key; signing a release requires the matching private key
in the maintainer's Keychain. It is never created by CI or committed. Preserve
the existing signing identity for installed clients; do not generate a new
key merely to make a release command pass.

1. For an initial installation only, **generate an Ed25519 key pair** (private
   key saved to your login Keychain, public key printed):

   ```bash
   # The tool ships inside the resolved Sparkle package:
   BIN="$(find build/DerivedData/SourcePackages/artifacts -path '*Sparkle/bin*' -name generate_keys | head -1)"
   "$BIN"
   ```

   It prints an `SUPublicEDKey` value. Re-print later with `"$BIN" -p`.

2. **Set the two release values** in `project.yml` (single source of truth),
   then `xcodegen generate`:

   ```yaml
   SUFeedURL: "https://github.com/rogu3bear/mlxread/releases/latest/download/appcast.xml"
   SUPublicEDKey: "<public key from step 1>"
   ```

   The release contract requires this stable GitHub release-asset URL.

3. **Back up the private key** off-machine:

   ```bash
   "$BIN" -x sparkle_private_key.pem   # export from Keychain; store securely, do NOT commit
   ```

`.gitignore` excludes `*.pem` and `sparkle_private_key*`. If the private key
is lost you cannot sign updates the installed base will accept — treat it like
a release signing identity.

## Cutting a release

1. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, run
   `xcodegen generate`, and commit the source and generated configuration.
   Sparkle compares `CFBundleVersion`; increase it for the next release.
2. When separately authorized to publish a release, create its `v<version>`
   tag at that exact clean source commit and create the matching GitHub release.
   PR integration alone does not authorize these publication effects.
3. Run `script/notarize.sh --rebuild` with the maintainer's Developer ID and
   notarization credentials. Packaging regenerates the Xcode project and embeds
   the current source revision in `MLXReadSourceRevision`. The release contract
   rejects tracked dirt, a tag that differs from HEAD, mismatched app version or
   revision, and an unusable feed/key before notarization.
4. The script notarizes and staples the app, rebuilds the final `MLXRead.zip`
   and `MLXRead.dmg`, and generates `dist/appcast.xml` from that exact ZIP using
   Sparkle's `generate_appcast` and the Keychain account `mlxread` (override
   with `SPARKLE_ACCOUNT`). It checks the feed's version, build, archive URL,
   nonzero length, and signature encoding before upload.
5. After DMG notarization and Gatekeeper checks, the script uploads the DMG,
   ZIP, and signed appcast to the selected release. `RELEASE_REPO` selects the
   repository and `RELEASE_TAG` must still match the project's version. The
   stable feed URL follows GitHub's latest release; verify that release points
   to the intended assets before claiming update delivery.

`script/test-release-contract.sh` exercises the local identity and appcast
validation with fixtures. It does not establish signing-key ownership,
cryptographic signature validity, notarization, upload, or a client update.

## Files

- `dist/appcast.xml` — generated signed feed, uploaded as a release asset;
  it is not committed in the source tree.
- `script/release-contract.sh` — source/artifact identity and appcast checks.
- `MLXRead/Updates/UpdateService.swift` — the in-app integration.
- Info.plist keys `SUFeedURL` / `SUPublicEDKey` / `SUEnableAutomaticChecks` /
  `SUScheduledCheckInterval` — declared in `project.yml`.

## Security notes

- No `com.apple.security.cs.disable-library-validation` entitlement is used:
  Xcode re-signs the embedded `Sparkle.framework` (and its `Autoupdate`,
  `Updater.app`, and XPC services) with the app's team, so Library Validation
  is satisfied under hardened runtime.
- The feed must stay **HTTPS**; `UpdateService.looksConfigured` refuses to
  activate on a non-HTTPS `SUFeedURL`.
- Sparkle's own defaults store update preferences; MLXRead adds no telemetry
  and Sparkle's system-profiling is left disabled (no `SUEnableSystemProfiling`).
