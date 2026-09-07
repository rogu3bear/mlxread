# Technical decisions

## Dependency pin

| Dependency | Version | Commit | License |
|---|---|---|---|
| Blaizzy/mlx-audio-swift | v0.1.3 (exact) | `d302a5c6080d2bb97bae38c7418f82abb76013b6` | MIT |
| ml-explore/mlx-swift | 0.31.6 (resolved) | — | MIT |
| ml-explore/mlx-swift-lm | 3.31.4 (resolved) | — | MIT |
| huggingface/swift-transformers | 1.3.3 (resolved) | — | Apache-2.0 |
| huggingface/swift-huggingface | 0.9.0 (resolved) | — | Apache-2.0 |

`mlx-audio-swift` is pinned with `exactVersion: 0.1.3` in `project.yml`; the
tag was verified against the GitHub ref
(`git/ref/tags/v0.1.3 → d302a5c…`). Transitive versions above are what SPM
resolved at project creation and are locked in
`MLXRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Model decision

MLXRead keeps Kokoro as the default and offers four optional alternatives.
All five have native implementations in the pinned mlx-audio-swift v0.1.3;
adding them does not require a Python process or a remote speech service.

| Model | Repo | Revision at verification | Weights license | Role |
|---|---|---|---|---|
| Kokoro 82M | `mlx-community/Kokoro-82M-bf16` | `a71e4d38b236` (main) | Apache-2.0 | Default; 54 voices, multilingual |
| Soprano 80M | `mlx-community/Soprano-80M-bf16` | `b7da048eff3d` (main) | Apache-2.0 | Low-latency English alternative |
| Qwen3-TTS 1.7B CustomVoice, 8-bit | `mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-8bit` | main | Apache-2.0 | Nine presets; delivery instructions; explicit language with dialect restrictions |
| Chatterbox Turbo fp16 | `mlx-community/chatterbox-turbo-fp16` + `mlx-community/S3TokenizerV2` | main | Apache-2.0 (MLX card), MIT (original model); codec Apache-2.0 upstream | English engine with one built-in voice |
| Pocket TTS | `mlx-community/pocket-tts` | main | CC-BY-4.0 | Eight English voices; small download |

Measured disk usage after download is shown live in Settings → Models
(approximate manifest sizes: Kokoro ~360 MB including voices, Soprano
~200 MB, Qwen ~3.1 GB including its speech tokenizer, Pocket ~240 MB, Chatterbox ~3.5 GB including its codec).

Facts that shaped the engine design (verified by reading the v0.1.3 source):

- **Kokoro, Soprano, Pocket, and Chatterbox produce one audio buffer per call.** They implement
  `generateStream` as a single final `.audio` event
  (`KokoroModel.swift:182-210`; Soprano decodes audio once after token
  generation, `Soprano.swift:693-798`). The `streamingInterval:` overload is
  a protocol-extension no-op for them (`Generation.swift:119-137`).
  → Streaming behavior in MLXRead therefore comes from **our own sentence
  chunking** (`TextChunker`): chunks are synthesized sequentially and each
  chunk's audio is scheduled as soon as it exists. This is the mechanism
  behind "playback starts before the full selection is synthesized".
  Qwen also streams audio within each sentence chunk; the app requests a
  0.5-second streaming interval. This is not a promise about first-audio latency.
- **Cancellation:** Soprano checks `Task.isCancelled` per generated token
  (`Soprano.swift:837`); Kokoro only checks around its single forward pass
  (`KokoroModel.swift:176-179`). MLXRead additionally checks cancellation
  between chunks, so worst-case generation-cancel latency is one chunk's
  forward pass. Playback stop is always immediate regardless.
- **Voice support:** Kokoro voices live in `voices/<name>.safetensors` and
  are enumerated from disk. Soprano ignores the `voice` argument entirely
  (model README + `Soprano.swift:283-297`), so MLXRead exposes no voice
  control for it.
  Pocket discovers `embeddings/<name>.safetensors`; Qwen's presets are embedded
  in the checkpoint rather than separate voice files. Required tokenizer files
  belong to each model's manifest entry, not a shared Kokoro-only check.
- **Speed:** Kokoro adjusts phoneme durations during synthesis. The other
  models use `AVAudioUnitTimePitch` (pitch-preserving rate control).

### Language and delivery

Qwen's CustomVoice API accepts separate text, language, speaker, and optional
instructions ([upstream guide](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-CustomVoice)).
The pinned Swift adapter carries speaker and instruction in its `voice` argument
as `speaker, instruction`. MLXRead uses this supported format for three delivery
presets and maps the explicit reading language to Qwen's language names. It does
not insert a chat system prompt into text-to-speech input.

The pinned `prepareGenerationInputs` unconditionally replaces the language ID
for Dylan and Eric with the speaker's Chinese dialect. The downloaded config
maps them to Beijing/Sichuan dialects. MLXRead therefore advertises and validates
Chinese-only use for those two voices. They remain previewable with a Chinese
sample. Other Qwen voices retain independent language choice; native English
voices appear first and every voice's native language is visible.

[Chatterbox Turbo](https://github.com/resemble-ai/chatterbox) supplies a distinct
English-only architecture and default voice. Its local Swift loader also opens
S3TokenizerV2. Download prefetches both assets, validates them, and includes both
in storage and deletion; preparation gates incomplete assets before invoking the
loader. This pass uses the unquantized checkpoint named `chatterbox-turbo-fp16`
to avoid adding quantization as a quality variable; its published tensor metadata
reports F32 weights.
A better voice preference must still be established by listening.

## Model cache and the HF_HUB_CACHE bootstrap

mlx-audio stores model snapshots under
`<hub-cache>/mlx-audio/<owner>_<repo>/` (`ModelUtils.swift`). Two Kokoro G2P
code paths (`KokoroMultilingualProcessor`, `MisakiTextProcessor`) **hardcode
`HubCache.default`** and ignore a custom cache passed to `fromPretrained`.
To keep every asset in one user-visible location,
`ModelStore.bootstrapEnvironment()` sets `HF_HUB_CACHE` to
`~/Library/Application Support/MLXRead/Models` before anything touches
`HubCache.default` (env resolution order verified in `HubCache.swift:30-37`).
Everything — model weights, Kokoro voices, English G2P lexicons
(`beshkenadze/kitten-tts-g2p`), multilingual lexicons/ByT5 — lands under that
directory.

Kokoro English G2P downloads an additional small asset repo on first
synthesis (Misaki lexicons). This is why "first read" can require network
even after the main model download; Settings → Models' Download button
performs only the weight snapshot. The G2P assets are then cached forever.
(A fully offline-after-download guarantee is verified in docs/testing.md.)

Downloads use `HubClient.downloadSnapshot` directly with byte-weighted progress
and a destination inside the app's models directory. The pinned Hub client
requires a cache even when given a destination, so completed downloads discard
that extra cache after its resolved files have been copied. Any retained cache
is included in disk usage and deleted with the model. This bypasses `ModelUtils`' cache shortcut,
which treats config plus any nonempty weights file as complete and can skip
missing tokenizer or voice assets. ModelStore checks each model's required files
after download and on refresh. The engine loads that local directory, so a
preview cannot silently redownload deleted weights.

Delete marks the model unavailable, cancels and joins an active download, then
removes both the model folder and any legacy Hub cache for that model. Operation
identities reject progress from earlier downloads. The engine cache releases
unavailable models and keeps only the last used engine warm. Preferences retain
each model's voice and Qwen's reading language across deletion and re-download.

## Project generation

The Xcode project is generated by **xcodegen** from `project.yml` (single
source of truth for bundle IDs, team, deployment target). Regenerate with
`xcodegen generate`. Builds must go through `xcodebuild`/Xcode — mlx-swift's
Metal kernels do not build via plain `swift build`.

`-skipPackagePluginValidation -skipMacroValidation` are required for
non-interactive `xcodebuild` because mlx-swift ships a build plugin
(`CudaBuild`) that Xcode otherwise wants interactively trusted.

## Concurrency model

- UI state: `@MainActor` `@Observable` (`SpeechCoordinator`, `AppSettings`,
  `ModelStore`, `SelectionAccessService`).
- Model load + generation: `NativeMLXSpeechEngine` actor; single-flight
  prepare task. Stop ends playback immediately, then joins preparation and
  drains the current sentence's producer before reusing or releasing a decoder.
  Model deletion waits for that work before removing assets.
- Playback: `StreamingAudioPlayer` actor over one persistent
  `AVAudioEngine`; bounded in-flight buffers via `AudioQueue` (capacity 4);
  epoch counter invalidates stale completion callbacks.
- Selection capture: value-typed results from a `Sendable` service; AX calls
  run on a detached background task (they block up to the AX messaging
  timeout).
- Event tap: dedicated thread + CFRunLoop; the C callback trampolines into
  the service via `Unmanaged`.
- Build uses `SWIFT_STRICT_CONCURRENCY=complete` in Swift 5 language mode.
  Known isolation exception: `SpeechGenerationModel` (mlx-audio) is not
  `Sendable`; it is confined to the engine actor after load.

## Signing

Development signing with the local "Apple Development" identity
(team `NB3G4L6ZD4`, configurable in `project.yml`). A stable identity keeps
the TCC Accessibility grant valid across rebuilds; ad hoc signing would
re-prompt after every build. `script/package.sh` produces a
Development-signed, non-notarized app and says so.
