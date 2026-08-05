# Security Policy

MLXRead is a local macOS app that reads your selected text aloud with an
on-device model. Its central promise is that **your text never leaves your
Mac**. Security reports are welcome and taken seriously.

## Reporting a vulnerability

Please report privately first — do not open a public issue for a security bug.

- **In-app:** Settings → **Report** sends a privacy-safe diagnostic bundle (it
  never includes your selected or spoken text) straight to the maintainer.
- **Web:** the contact form at
  [mlxread-web.pages.dev/support](https://mlxread-web.pages.dev/support)
  (topic “Privacy”) reaches the maintainer directly.
- For sensitive reports, ask for an encrypted channel via either route above.

Please include: affected version (Settings → Report shows it), macOS version,
and clear reproduction steps. Expect an acknowledgement within a few days.

## Scope

In scope:

- The macOS app (selection capture, the ⌥⎋ event tap, audio, model loading).
- The update mechanism (Sparkle appcast / signature verification).
- The delivery worker (`api/`) and the website (`website/`).

Out of scope: third-party dependencies' own advisories (report upstream), and
issues that require already having admin/local access to the user's machine.

## What already protects you

- **No data egress.** Selected text is synthesized in-process, held in memory
  only while reading, never written to disk, and never logged (lengths and
  timings only). No analytics, no crash SDK, no account. See
  [docs/privacy.md](docs/privacy.md).
- **Signed + notarized.** Releases are Developer ID–signed, run under the
  hardened runtime with `get-task-allow` stripped, and are notarized by Apple.
- **Verified updates.** Sparkle appcasts are served over HTTPS and every update
  is **EdDSA-signed and verified** before it installs. The EdDSA private key is
  never committed.
- **Least-privilege delivery.** The contact/report worker's email binding is
  restricted so it can only ever email the maintainer — it cannot be abused as
  an open relay. Debug bundles are content-safe by construction.
- **Threat model.** A repository-specific threat model is maintained at
  [mlxread-threat-model.md](mlxread-threat-model.md).

## Handling

Confirmed vulnerabilities are fixed in a new signed, notarized release; the
appcast is updated so existing installs auto-update. Credit is given in the
release notes unless you prefer to remain anonymous.
