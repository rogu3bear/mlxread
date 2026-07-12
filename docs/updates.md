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
- Source checkouts and development builds keep the template placeholders, so
  the updater stays **inactive** and the update UI is hidden — no accidental
  checks against a placeholder feed. See
  `MLXRead/Updates/UpdateService.swift` (`looksConfigured`).
- Automatic background checks default on (`SUEnableAutomaticChecks`), daily
  (`SUScheduledCheckInterval = 86400`).

## One-time maintainer setup

The signing key is a **credential the maintainer owns** — generate it
yourself; it is never created by CI or committed.

1. **Generate the Ed25519 key pair** (private key saved to your login
   Keychain, public key printed):

   ```bash
   # The tool ships inside the resolved Sparkle package:
   BIN="$(find build/DerivedData/SourcePackages/artifacts -path '*Sparkle/bin*' -name generate_keys | head -1)"
   "$BIN"
   ```

   It prints an `SUPublicEDKey` value. Re-print later with `"$BIN" -p`.

2. **Set the two release values** in `project.yml` (single source of truth),
   then `xcodegen generate`:

   ```yaml
   SUFeedURL: "https://raw.githubusercontent.com/<owner>/mlxread/main/appcast.xml"
   SUPublicEDKey: "<public key from step 1>"
   ```

   (Or host the appcast on GitHub Pages / any HTTPS location you control.)

3. **Back up the private key** off-machine:

   ```bash
   "$BIN" -x sparkle_private_key.pem   # export from Keychain; store securely, do NOT commit
   ```

`.gitignore` excludes `*.pem` and `sparkle_private_key*`. If the private key
is lost you cannot sign updates the installed base will accept — treat it like
a release signing identity.

## Cutting a release

1. Build and sign a **Developer ID + hardened-runtime + notarized** app
   (see `docs/system-voice-provider.md` and `script/package.sh`; for a public
   release, sign with Developer ID rather than the local Development identity).
2. Zip the `.app`:

   ```bash
   ditto -c -k --keepParent dist/MLXRead.app "MLXRead-<version>.zip"
   ```

3. **Sign + build the appcast** (auto-signs from the Keychain private key):

   ```bash
   DIR="$(dirname "$BIN")"
   "$DIR/generate_appcast" /path/to/folder-containing-the-zip/
   ```

   This writes/updates `appcast.xml` with the correct `sparkle:edSignature`,
   `length`, and version fields. (To sign a single archive by hand:
   `"$DIR/sign_update" MLXRead-<version>.zip`.)

4. Upload the `.zip` to the GitHub Release matching the `enclosure` URL, and
   publish the updated `appcast.xml` at `SUFeedURL`.

5. Bump `MARKETING_VERSION` (CFBundleShortVersionString) and
   `CURRENT_PROJECT_VERSION` (CFBundleVersion) in `project.yml` for the next
   build — Sparkle compares `CFBundleVersion`.

## Files

- `appcast.xml` — the feed template at the repo root (replace `OWNER`).
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
