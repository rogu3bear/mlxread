# MLXRead

A local, private replacement for macOS "Speak Selection": press **⌥⎋
(Option–Escape)** anywhere and the current selection is read aloud by an MLX
text-to-speech model running entirely on your Mac. Press ⌥⎋ again and it
stops instantly.

**[Download the latest release](https://github.com/rogu3bear/mlxread/releases/latest/download/MLXRead.dmg)** (signed and notarized DMG, macOS 14+ · Apple Silicon) · **Product website:** [mlxread.com](https://mlxread.com)

- Menu-bar utility (no Dock icon), SwiftUI + AppKit at the edges; optional
  **launch at login** keeps it always on, a keystroke away
- Local synthesis via [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift)
  — Chatterbox Turbo (English), Kokoro 82M (default), Qwen3-TTS 1.7B
  (delivery control), Pocket TTS, and Soprano 80M
- Selection capture via the Accessibility API, with a clipboard-preserving
  ⌘C fallback for apps that don't expose their selection
- No network after model download, no telemetry, no logging of your text

## Requirements

- Apple Silicon Mac
- macOS 14 or newer (built and verified on macOS 26.5 / Xcode 26.6)
- Disk space for the models you choose: Kokoro ~360 MB, Qwen ~3.1 GB,
  Pocket ~240 MB, Soprano ~200 MB, Chatterbox ~3.5 GB including its codec. One model is enough.

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
   The app checks access and shortcut health every second and when it regains
   focus. It picks up grants and retries transient shortcut failures
   automatically. Revoking access removes the keyboard tap and stops active
   reading on the next check. Settings → Permissions shows both access and
   shortcut readiness.
   The setup window closes when access is granted.
3. If Apple's built-in **Speak selection** shortcut is enabled and set to
   ⌥⎋, disable or reassign it under System Settings → Accessibility →
   Spoken Content. MLXRead will not change that setting for you.
4. Open Settings → **Models** and choose **Download** for a model (from Hugging Face into
   `~/Library/Application Support/MLXRead/Models`). Kokoro fetches small
   pronunciation assets on its first synthesis; after that everything is
   offline.

Models shows download progress, incomplete/failed downloads, deletion in
progress, and **Ready to preview** after required files are checked. **Preview**
selects the model and reads a sample; **Use Model** selects it without playing.
**Delete** removes that model's files and any legacy copy in the app's cache.
You can download it again later; its saved voice choice is retained. An active
reading must finish or stop before deleting the selected model. **Refresh Status**
rechecks files if you changed the models folder outside the app.
Only one MLXRead instance can run at a time. Opening it again reuses the running
app; reopening it while its windows are closed brings up Settings. Direct
executable launches also exit before starting duplicate services. Quit the
running app before switching between an installed and development build.

## Use

| Action | Result |
|---|---|
| ⌥⎋ with text selected | Selection is captured, synthesized sentence-by-sentence, playback starts as soon as the first chunk is ready |
| ⌥⎋ while reading | Generation cancelled, playback stopped, queue cleared — immediately |
| Menu bar → Read Selection / Stop | Same as the shortcut |
| Settings → Voice | Searchable voice previews, explicit reading language, speed (0.5–2×), editable local passage |

The menu bar icon shows a rotating progress ring while loading a voice or
preparing speech, then a filled waveform while speaking. With Reduce Motion
enabled, the progress ring stays still.

Voice settings opens first. Pick an engine and compare its voices using the
individual **Preview** buttons. Previews do not change the saved reading voice;
**Use** selects it. English voices appear first. Kokoro's **All languages** filter
exposes every installed voice, with a sample in that voice's language. The preview
passage stays in memory and is never saved or taken from another app's selection.

Qwen receives an explicit reading language, defaulting to English, and supports
**Natural**, **Narration**, and **Expressive** delivery instructions. These guide
the sound and are never prepended to the passage. Ryan and Aiden are its native
English voices. Dylan and Eric force a Chinese dialect in the pinned runtime, so
they can be previewed in Chinese but cannot be selected for English reading.
The other presets support cross-language speech, with their native-language
accents labeled. Chatterbox Turbo, Pocket, and Soprano are English-only.

Kokoro adjusts speech timing during synthesis; the other models use
pitch-preserving playback speed. Each reading snapshots its voice, language,
delivery, and speed. Only the most recently used model stays loaded in memory.

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
script/package.sh              # → .app + Sparkle ZIP + manual-install DMG
script/notarize.sh             # notarize + staple + publish DMG and ZIP
script/clean.sh                # trash scattered build-dir apps; keep only dist/
```

`dist/MLXRead.app` is the one app you should ever launch — signed and notarized.
Builds also drop a copy in `build/DerivedData` (and the benchmark tree); `build/`
is excluded from Spotlight and `script/clean.sh` trashes those stray copies so a
stale or unsigned build can't be opened by accident.

### Notarizing a release (one command)

`script/notarize.sh` builds (if needed), notarizes with Apple, staples the app,
rebuilds and notarizes the DMG, and updates both GitHub release assets — a
single command. People install from `MLXRead.dmg`; Sparkle continues to consume
`MLXRead.zip` as its update archive.

```bash
./script/notarize.sh
```

The first run prompts once for your Apple ID and an app-specific password
(create one at appleid.apple.com → Sign-In & Security), storing them in your
Keychain; every run after is automatic. Notarization prevents the unverified-
developer block; macOS may still show its standard first-open confirmation for
an app downloaded from the internet.

Measured results for this machine are recorded in
[docs/testing.md](docs/testing.md).

## System voice provider (Phase 2)

Status and evidence: [docs/system-voice-provider.md](docs/system-voice-provider.md).

## Website

A product and first-read site lives in [`website/`](website/) — Leptos SSR with
an interactive ⌥⎋ read-lifecycle preview, deployed to Cloudflare Pages at
**https://mlxread.com**. It also hosts the
[FAQ](https://mlxread.com/faq) and a
[Support](https://mlxread.com/support) page with a contact form.
Details in [website/README.md](website/README.md).

## Troubleshooting

- **⌥⎋ does nothing** — check Settings → Permissions. Grant missing
  Accessibility access; the shortcut starts automatically. If three automatic
  attempts fail, use **Retry Shortcut**. If another app also taps ⌥⎋
  (e.g. Apple Speak Selection), resolve the conflict.
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

- Kokoro/Soprano/Pocket/Chatterbox generate per sentence-chunk, not sample-streaming: time to
  first audio is one chunk's synthesis (~1–2 s warm for Kokoro on M-series;
  see docs/testing.md for measured values).
- Qwen streams within each sentence chunk. Its larger download and model load
  trade speed and memory for a different voice model; compare previews on your Mac.
- Kokoro cancellation takes effect at forward-pass boundaries (≤ one chunk);
  audible playback still stops instantly.
- Soprano ignores voice selection (single-voice model) and is English-only.
- The clipboard fallback cannot capture selections in apps that block
  synthetic ⌘C or use secure input; the clipboard is restored only when
  nothing else wrote to it mid-capture (by design).
- PDF viewers must expose a text layer through Accessibility or respond
  to ⌘C for capture to work.
- The published `.app` is Developer ID–signed, hardened-runtime, and
  **notarized by Apple**. macOS may show its standard first-open confirmation,
  but it should not block the app as an unidentified developer. Re-cut a
  notarized release anytime with `./script/notarize.sh`.

## Support

- **In the app:** Settings → **Report** attaches a privacy-safe debug bundle
  (never your text — only versions, model/permission state, and recent logs)
  and sends it straight to the maintainer.
- **FAQ & troubleshooting:**
  [mlxread.com/faq](https://mlxread.com/faq) and
  [/support](https://mlxread.com/support), which has a contact form.
- **Bugs & features:** open an issue at
  [github.com/rogu3bear/mlxread/issues](https://github.com/rogu3bear/mlxread/issues).
- **Security:** see [SECURITY.md](SECURITY.md) — please report privately first.

The contact/report backend is a small Cloudflare Worker in [`api/`](api/) that
emails the maintainer over Cloudflare Email Routing; the maintainer address is
never exposed to users.

## Licenses

MLXRead is MIT-licensed ([LICENSE](LICENSE)). Bundled dependencies and model
weights: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
