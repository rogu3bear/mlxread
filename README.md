# MLXRead

A local, private replacement for macOS "Speak Selection": press **⌥⎋
(Option–Escape)** anywhere and the current selection is read aloud by an MLX
text-to-speech model running entirely on your Mac. Press ⌥⎋ again and it
stops instantly.

- Menu-bar utility (no Dock icon), SwiftUI + AppKit at the edges
- Local synthesis via [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift)
  — Kokoro 82M (default, 54 voices) or Soprano 80M (fast, English)
- Selection capture via the Accessibility API, with a clipboard-preserving
  ⌘C fallback for apps that don't expose their selection
- No network after model download, no telemetry, no logging of your text

## Requirements

- Apple Silicon Mac
- macOS 14 or newer (built and verified on macOS 26.5 / Xcode 26.6)
- ~0.6 GB disk for both models (either alone is enough)

## Build

```bash
brew install xcodegen        # once
xcodegen generate            # regenerates MLXRead.xcodeproj from project.yml
script/build_and_run.sh      # build (xcodebuild) + launch
script/build_and_run.sh --verify   # build, launch, assert process + signature
```

Signing uses your local Apple Development certificate. Contributors override
the team without editing tracked files —
`DEVELOPMENT_TEAM=YOURTEAM script/build_and_run.sh`, or
`CODE_SIGNING_ALLOWED=NO script/build_and_run.sh` for a quick unsigned build
(see [CONTRIBUTING.md](CONTRIBUTING.md)). A stable identity is recommended so
the Accessibility grant persists across rebuilds. No paid account is required
to run locally. Plain `swift build` is not a supported path — mlx-swift's
Metal kernels need the Xcode build system.

## First launch

1. MLXRead appears as a waveform icon in the menu bar and shows a setup
   window.
2. Grant **Accessibility** access (System Settings → Privacy & Security →
   Accessibility). This powers both selection reading and the ⌥⎋ event tap.
   The app monitors trust continuously: it picks up the grant without a
   relaunch, and if you later **revoke** access it removes its keyboard tap and
   stops any active reading immediately. Settings → Permissions shows both the
   permission state and whether the ⌥⎋ shortcut is actually installed.
3. If Apple's built-in **Speak selection** shortcut is enabled and set to
   ⌥⎋, disable or reassign it under System Settings → Accessibility →
   Spoken Content. MLXRead will not change that setting for you.
4. Open Settings → **Models** and download a model (Kokoro ~360 MB or
   Soprano ~200 MB, from Hugging Face into
   `~/Library/Application Support/MLXRead/Models`). Kokoro fetches small
   pronunciation assets on its first synthesis; after that everything is
   offline.

## Use

| Action | Result |
|---|---|
| ⌥⎋ with text selected | Selection is captured, synthesized sentence-by-sentence, playback starts as soon as the first chunk is ready |
| ⌥⎋ while reading | Generation cancelled, playback stopped, queue cleared — immediately |
| Menu bar → Read Selection / Stop | Same as the shortcut |
| Settings → Voice | Model, voice (Kokoro), speed (0.5–2×), test phrase |

Long selections are truncated at a configurable limit (default 20,000
characters) at a word boundary; truncation is indicated in the menu.

## Updates

MLXRead auto-updates via [Sparkle 2](https://sparkle-project.org) with
**EdDSA-signed** appcasts over HTTPS — every update is cryptographically
verified before install. Check manually from the menu bar (**Check for
Updates…**) or Settings → General; automatic daily checks are on by default.
Update controls only appear in a build configured with a real feed and public
key; source/dev builds keep the updater inactive. Maintainer setup and the
release/signing process: [docs/updates.md](docs/updates.md).

## Offline behavior

After a model is downloaded (plus one first synthesis for Kokoro's G2P
assets), synthesis requires no network. Verification procedure:
[docs/privacy.md](docs/privacy.md).

## Privacy

Selected text never leaves the machine, is never written to disk, and never
appears in logs (lengths and timings only — verifiable with
`script/build_and_run.sh --logs`). No analytics, no crash reporting. Full
statement and enforcement points: [docs/privacy.md](docs/privacy.md).

## Tests and benchmarks

```bash
script/test.sh                 # unit tests (fast, no network, no models)
script/test.sh --integration   # + real model download & synthesis tests
script/test.sh --ui            # + UI launch smoke test
script/benchmark.sh [soprano|kokoro|all]   # measured synthesis benchmark
script/package.sh              # → dist/MLXRead.app (Development-signed, NOT notarized)
```

Measured results for this machine are recorded in
[docs/testing.md](docs/testing.md).

## System voice provider (Phase 2)

Status and evidence: [docs/system-voice-provider.md](docs/system-voice-provider.md).

## Website

A marketing + demo site lives in [`website/`](website/) — Leptos SSR with an
interactive ⌥⎋ demo, deployed to Cloudflare Pages at
**https://mlxread-web.pages.dev**. Details in
[website/README.md](website/README.md).

## Troubleshooting

- **⌥⎋ does nothing** — check Settings → Permissions; the event tap needs
  Accessibility access. After granting, use "Recheck". If another app also
  taps ⌥⎋ (e.g. Apple Speak Selection), resolve the conflict.
- **"No selected text was found"** — the frontmost app reported no
  selection. For apps without Accessibility text (some Electron apps,
  protected fields), enable the clipboard fallback in Settings → General.
- **"does not expose its selection"** — AX failed and the fallback is
  disabled or also failed. Secure input fields intentionally block both.
- **Model download failed** — retry from Settings → Models; partial
  downloads are detected and re-fetched. Check disk space.
- **First read after launch is slow** — that's the one-time model load
  (see benchmarks); the model then stays warm.
- **No audio** — check the selected output device; the app reports "audio
  device unavailable" if the engine cannot start.

## Known limitations

- Kokoro/Soprano generate per sentence-chunk, not sample-streaming: time to
  first audio is one chunk's synthesis (~1–2 s warm for Kokoro on M-series;
  see docs/testing.md for measured values).
- Kokoro cancellation takes effect at forward-pass boundaries (≤ one chunk);
  audible playback still stops instantly.
- Soprano ignores voice selection (single-voice model) and is English-only.
- The clipboard fallback cannot capture selections in apps that block
  synthetic ⌘C or use secure input; the clipboard is restored only when
  nothing else wrote to it mid-capture (by design).
- PDF viewers must expose a text layer through Accessibility or respond
  to ⌘C for capture to work.
- Not notarized; local/dev distribution only.

## Licenses

MLXRead is MIT-licensed ([LICENSE](LICENSE)). Bundled dependencies and model
weights: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
