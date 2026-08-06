# Security Policy

MLXRead is a local macOS app that reads selected text aloud with an on-device
model. Its core security promise is narrow and absolute: **selected and spoken
text must never leave the Mac**. The public website, support form, delivery
Worker, signed app, and update path are also part of the security boundary.

## Reporting a vulnerability

Please report privately first; do not open a public issue for a security bug.

- **In-app:** Settings → **Report** sends a diagnostic bundle and optional
  reporter-entered email/description to the maintainer. The bundle must never
  contain selected or spoken text.
- **Web:** use [mlxread.com/support](https://mlxread.com/support) and choose
  “Privacy.” The temporary `mlxread-web.pages.dev` hostname may remain available
  for deployment compatibility, but `mlxread.com` is the canonical surface.
- For sensitive reports, request an encrypted channel through either route.

Include the affected version, macOS version, and reproducible steps. Do not
paste selected or spoken text into either report channel. Expect an
acknowledgement within a few days.

## Scope

In scope:

- The macOS app: selection capture, the Option–Escape event tap, clipboard
  fallback, audio, model loading, local storage, and privilege boundaries.
- Release and update integrity: Developer ID signing, notarization, Sparkle
  appcast configuration, and EdDSA verification.
- The unauthenticated public website (`website/`) and delivery Worker (`api/`),
  including contact/report submission, report storage, and download links.
- Build and dependency paths that could compromise the signed artifact.

MLXRead has no accounts, tenancy, analytics, or application cookies. Website
support messages and in-app reports are nevertheless user data: permitted
fields include reporter email, message/description, app/build/macOS/hardware
metadata, settings state, request IP metadata, and privacy-safe app logs.

Out of scope:

- A third-party dependency's own advisory when there is no demonstrated
  MLXRead-specific reachability or impact; report those upstream.
- Attacks that assume an adversary already controls root or an administrator
  account and cross no additional MLXRead boundary.

Same-user unprivileged attacks, local privilege escalation, signing/update
bypass, report-link disclosure, and violations of the selected-text boundary
remain in scope.

## Security invariants and controls

- **Reading content stays local.** Selected text is synthesized in-process,
  held only while needed, never written to disk, never placed in website or
  report payloads, and never logged. See [docs/privacy.md](docs/privacy.md).
- **Reports are deliberately bounded.** Debug bundles contain enumerated
  metadata and recent MLXRead logs only. The Worker enforces request and bundle
  size limits, best-effort throttling, and a mail binding restricted to the
  maintainer. User-entered descriptions are not automatically populated from a
  selection and must not include reading content.
- **Public report storage uses bearer capabilities.** R2 objects are addressed
  by random 128-bit identifiers and returned with `private, no-store`; anyone
  who obtains a download URL can read that bundle. Retention and authenticated
  maintainer access are tracked limitations, not protections that exist today.
- **Release artifacts are signed.** The manual-install DMG and its contained
  app must be Developer ID-signed, hardened, notarized, and stapled. The ZIP is
  retained as the separately verified Sparkle update archive. Debug builds
  deliberately have a weaker debugger posture and are not release artifacts.
- **Updates fail closed when unconfigured.** Sparkle starts only with a real
  HTTPS feed and non-placeholder public key, then verifies EdDSA signatures.
  The checked-in feed and project settings remain templates, so source builds
  do not currently establish an active update channel.
- **The public web surface is stateless.** It uses no accounts or cookies and
  applies a CSP, frame denial, content-type restrictions, same-origin checks,
  and body-size limits to server-function requests.

The repository-specific assessment is maintained in
[mlxread-threat-model.md](mlxread-threat-model.md).

## Handling

Confirmed app vulnerabilities are fixed in a new signed and notarized release.
When an update channel is configured for that release, its signed appcast is
updated as part of publication. Website and Worker fixes require their own
deployment and live readback; a source change or local build is not proof that
production changed. Credit is given in release notes unless the reporter asks
to remain anonymous.
