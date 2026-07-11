# Privacy

MLXRead's privacy posture is enforced in code, not just promised:

- **Selected text stays local.** Synthesis runs in-process via MLX on the
  local GPU. There is no remote API, no account, no telemetry, no crash
  reporter.
- **Selected text lives only in memory, only while needed.** It flows
  capture → normalize → chunk → model → PCM and is released with the reading
  task. Nothing writes it to disk. The models directory contains model
  assets only.
- **Selected text is never logged.** `AppLogger` call sites log lengths,
  counts, durations, and error descriptions. The rule is stated in
  `AppLogger.swift` and enforced in review; `log stream` during a read shows
  character counts, never content.
- **Optional preview is off by default.** Settings → General has a
  "selection preview" toggle (default **off**); nothing in the UI displays
  captured text unless the user turns that on.
- **Clipboard hygiene.** The fallback snapshots the pasteboard, synthesizes
  ⌘C, reads the fresh text, and restores the snapshot **only** when the
  pasteboard's `changeCount` proves nothing else wrote in between. If the
  user or another app raced us, their data wins and no restore happens.
- **Network is used exactly twice, both user-visible:** the model snapshot
  download started from Settings → Models, and Kokoro's first-synthesis G2P
  asset fetch (small lexicon repos, cached forever after). After those,
  MLXRead works with networking disabled.

## Offline verification procedure

1. Download a model in Settings → Models and play the test phrase once
   (this also caches Kokoro's G2P assets).
2. Quit MLXRead. Disable Wi-Fi/Ethernet (or block the app with a firewall).
3. Relaunch MLXRead, select text anywhere, press ⌥⎋.
4. Expected: speech plays normally. Settings → Models shows the model as
   downloaded. No error states appear.

An automated equivalent (network-blocked synthesis via unshare of network
reachability) is not scriptable on stock macOS without root; the manual
procedure above plus the integration test's cached-path run
(`script/test.sh --integration` with models already on disk and networking
off) are the supported checks.
