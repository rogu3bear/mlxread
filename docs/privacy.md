# Privacy

MLXRead separates reading content from the networked surfaces used to acquire
assets, deliver updates, and support users.

- **Selected and spoken text stays local.** Synthesis runs in-process via MLX
  on the local GPU. Reading content is never sent to the website, support form,
  delivery Worker, update service, analytics, or a remote speech API.
- **Reading content lives only in memory, only while needed.** It flows capture
  → normalize → chunk → model → PCM and is released with the reading task.
  Nothing writes it to disk; the models directory contains model assets only.
- **Reading content is never logged.** `AppLogger` records lengths, counts,
  durations, states, and error descriptions. The invariant applies to every log
  line included in a diagnostic report.
- **Optional preview is off by default.** Settings → General has a selection
  preview toggle; nothing in the UI displays captured text unless the user
  enables it.
- **Clipboard fallback is narrow but observable to local software.** The app
  snapshots the general pasteboard, synthesizes Command-C, reads the fresh text,
  and restores the snapshot only when `changeCount` proves nothing else wrote in
  between. A clipboard manager or same-user process may still observe the
  temporary selection during that fallback window.

## Network use

The app can make these outbound requests:

1. A user-started model snapshot download from Settings → Models.
2. Kokoro pronunciation/G2P asset downloads on first synthesis, cached for
   later offline use.
3. Sparkle update checks only in a release whose HTTPS feed and public key are
   fully configured. Placeholder source builds keep the updater inactive.
4. A user-started in-app problem report containing an optional email and
   description plus a diagnostic ZIP. The app never inserts selected or spoken
   text into these fields or the bundle.

The website can receive a user-started support message. That message, its
email/name/topic fields, and standard request metadata are sent through the
Cloudflare delivery Worker to the maintainer. Users must not paste selected or
spoken text into support or report descriptions.

The diagnostic ZIP contains app/build version, macOS and hardware model, model
and voice settings, speed, model state, Accessibility/hotkey/launch-at-login
state, and up to about ten minutes of MLXRead logs. The Worker may also retain
reporter email, app/macOS version, and request IP as R2 object metadata. Report
download links are high-entropy bearer links: anyone with a link can retrieve
the corresponding bundle. No automatic deletion policy is asserted by the
current source.

## Website data

The website has no accounts, analytics, trackers, application cookies, or
advertising. Cloudflare and GitHub process standard request/download metadata
under their own policies. The site itself does not add behavioral tracking.

## Offline verification procedure

1. Download a model in Settings → Models and play the test phrase once so the
   model and pronunciation assets are cached.
2. Quit MLXRead. Disable networking or block the app with a firewall.
3. Relaunch MLXRead, select text anywhere, and press Option–Escape.
4. Expected: speech plays normally and the downloaded model remains available.
   Update checks, support, and problem-report submission are unavailable while
   offline, without affecting local reading.

An automated network-blocked synthesis equivalent is not scriptable on stock
macOS without root. The supported evidence is the manual procedure above plus
the integration test's cached-path run (`script/test.sh --integration`) with
models already on disk and networking disabled.
