# Testing

The original baseline below was produced on 2026-07-11 on this machine: Apple Silicon
(arm64), macOS 26.5.2, Xcode 26.6 (SDK macOS 26.5).

## Menu bar loading ring — 2026-09-07

Native menu bar screenshots during a Pocket voice preview showed five distinct
arc positions while speech was being prepared, followed by the filled speaking
icon when audio started. The menu stayed closed throughout. A later **Stop
preview** during preparation returned to readiness in 27 ms without starting
playback. The selected Pocket/Alba reading voice was retained.

The ring uses timer-driven template images; `TimelineView` caused a repeating
menu bar image update on this host and was removed. The timer subscription only
exists in the animated loading branch. Reduce Motion selects a stationary ring;
the system preference was not changed during verification.

The signed native unit suite executed **103 tests: 89 passed, 14 opt-in tests
skipped, 0 failures**. The temporary screenshot-capture test was removed after
use. These checks used the development app and did not replace the installed
application or change Accessibility permission.

## Duplicate-launch guard — 2026-09-07

The signed native unit run (`script/test.sh`) executed **103 tests: 89 passed,
14 opt-in integration/benchmark tests skipped, 0 failures**. Lock tests exercised
exclusive ownership, reacquisition after release, a leftover file without a live
lock, and filesystem failure. The signed development build passed launch and
deep strict signature verification.

Normal reopen, `open -n`, opening a second copy of the updated app, and direct
executions of both copies all left the original process as the sole instance.
Six simultaneous direct launches across two copies produced one survivor and
five clean exits. Force-killing that survivor allowed a subsequent launch to
acquire the existing lock file without deleting it. The normal development app
was then reopened and its Settings controls verified. The temporary app copy
was unregistered and removed.

An explicit installed-copy check found the version boundary: the updated build
refuses to start when the older installed app is already running, but that older
binary can still start alongside the updated build. Updating the installed copy
is therefore required for the normal Applications-folder launch path. These
checks did not replace the installed app or change Accessibility permission.

## Voice library and English handling — 2026-09-07

On the same M4 Max host described below, the signed native suite executed
99 tests: **97 passed, 2 opt-in benchmarks skipped, 0 failures**. The run used
the `script/test.sh --integration` Xcode arguments and skipped only
`testDownloadDeleteAndRedownloadInIsolatedLibrary`, which had already passed
in the preceding run. That first run was interrupted by an orderly app Quit
during the voice sweep; its overall result was failed. The complete voice sweep
was rerun successfully after that interruption.

- Every downloaded voice produced finite, non-silent PCM: **73 voices** across
  Chatterbox Turbo (1), Kokoro (54), Qwen (9), Pocket (8), and Soprano (1).
  Kokoro used each voice's native-language sample. Qwen used English for seven
  voices and Chinese for its two dialect-bound voices, Dylan and Eric.
- Chatterbox's download included its required S3 codec. Its real local synthesis
  produced 24 kHz audio; fixture tests also exercised missing-codec validation
  and deletion of all required components.
- Coordinator tests verified that auditioning another voice uses its requested
  configuration while the following reading retains the saved voice. Settings
  tests covered explicit English, persisted delivery, and rejection of the two
  Qwen dialect voices for English reading.

In the signed Debug app, Aiden's Preview reached playback while Sohee remained
selected. **Use Aiden** changed the saved voice; previewing Ryan with **Narration**
then left Aiden selected. Search filtered by voice name and language, and Kokoro's
**All languages** view exposed all 54 preview buttons. Chatterbox's Preview
completed, its Stop button returned to readiness, and Models reported its full
3.48 GB download ready. Screens were inspected in dark appearance. A final native
build verified the shorter explanatory copy and the single-voice layout.

These checks establish working audio generation, not listening preference or
pronunciation accuracy. They do not cover every Qwen voice/language/delivery
combination. Networking was available for first-use pronunciation assets.
The work was verified in the development app; the installed application was not
replaced, and no Accessibility permission was changed.

## Model catalog follow-up — 2026-09-07

Verified on an Apple M4 Max with 48 GB RAM, macOS 26.6.2, and Xcode 26.6.
The combined unit and real-model suite (`script/test.sh --integration`) executed
94 tests: **92 passed, 2 opt-in benchmarks skipped, 0 failures**. This covers the
existing Kokoro/Soprano paths plus Qwen3-TTS 1.7B CustomVoice 8-bit and Pocket TTS.

- Real Qwen and Pocket downloads loaded from the app's model directory and
  produced finite, non-silent audio. Qwen emitted 16 audio chunks; Pocket emitted
  one buffer for the test passage. Their single-run synthesis times were 8.67 s
  and 1.02 s respectively; these are test observations, not comparative benchmarks.
- An isolated temporary library exercised Pocket download → delete → redownload.
  Deletion removed about 240 MB and made the model unavailable before redownload.
- Controlled transport tests exercised cancellation, deletion while a cancelled
  writer was still finishing, retry, and rejection of stale progress updates.
  Other tests cover required tokenizer/voice files, saved choices per model,
  Qwen's independent reading language, and eviction of deleted or replaced engines.

The signed Debug app was then exercised through its visible Settings controls:

- Reopening the running menu-bar app opened Settings. Models and Voice were
  inspected in dark appearance; the catalog, status, sizes, and controls were legible.
- Qwen and Pocket **Preview** each reached `Speaking` and returned to readiness.
- Pocket **Delete** changed its row to **Not downloaded**, reduced the total from
  4.51 GB to 4.27 GB, and removed both its model directory and legacy cache path.
  **Download** displayed percentage progress, then returned to **Ready to preview**
  at 240.4 MB. Preview reached playback again after this fresh download.
- Pocket's picker exposed all eight voices, Qwen exposed separate language and
  voice controls, and returning to Kokoro restored the saved Aoede voice at 1×.

The new models remained downloaded. This pass used the development build and
did not replace the installed application. It did not exercise every Qwen
voice/language combination or judge subjective voice quality. Networking was
available; physically disconnected operation remains a separate manual check.

## Automated suites

| Suite | Command | Result |
|---|---|---|
| Unit tests (61 tests: normalizer, chunker, coordinator state machine, cancellation, stale-generation rejection, pasteboard snapshot/restore, audio queue/converter, model store validation, settings persistence, engine single-flight) | `script/test.sh` | **PASS** — 61 executed, 0 failures (8 opt-in tests skipped by design) |
| Integration (real models: Soprano + Kokoro prepare/synthesize, valid non-silent PCM at 32 kHz/24 kHz, cancellation latency, repeated generation reuse, chunk ordering, download state machine) | `script/test.sh --integration` | **PASS** — 6 executed, 0 failures (first run downloads models) |
| UI launch smoke (menu-bar utility launches, stays running) | `script/test.sh --ui` | **PASS** — 1 executed, 0 failures |

Two real bugs were caught by the suites during development and fixed:
NLTokenizer splitting URLs at `?` (chunker merge pass added) and an
`@Observable` + `didSet` self-assignment recursion crash in settings
clamping.

## Measured benchmarks (`script/benchmark.sh`, Release, arm64)

488-character prose passage, warm model (one warm-up pass), each model in
its own process:

| Metric | Soprano 80M | Kokoro 82M |
|---|---|---|
| Cold model load (API call) | 0.221 s | 0.287 s |
| Warm time to first audio | 0.874 s | 1.676 s |
| Total synthesis | 1.462 s | 2.809 s |
| Audio produced | 26.9 s | 32.4 s |
| Real-time factor | 18.4× | 11.5× |
| Peak phys footprint (process) | 770 MB | 2406 MB |

Cold-load numbers measure `TTS.loadModel` (weights are mmap'd lazily); the
first end-to-end read in a fresh app process measured **2.46 s from
keypress to audible speech** (Kokoro, Debug build, 2464-char selection —
includes capture, load, G2P prep, first-chunk synthesis).

Stop latency, measured from the state log in live runs: **34–46 ms** from
second ⌥⎋ to Idle (playback ceases immediately; three runs: 34/42/46 ms).

## End-to-end interaction proofs (scripted, real keystrokes)

Method: MLXRead launched from a trusted shell (inherits Accessibility
attribution), target app opened and verified frontmost, real CGEvents
posted (⌘A, ⌥⎋, ⌥⎋), `log stream` captured. Selected text never appears in
logs — counts only (content shows as `<private>`).

| Application | Capture | Fallback needed | Playback | 2nd ⌥⎋ stops | Clipboard preserved |
|---|---|---|---|---|---|
| TextEdit (2464-char file) | AX, 2464 chars | No | Kokoro, real audio, 12 chunks | Yes (42 ms) | Yes (untouched) |
| Safari (local HTML) | AX, 122 chars | No | Kokoro, real audio | Yes (46 ms) | Yes (untouched) |
| Preview (PDF with text layer) | AX, 2484 chars | No | mock-engine session | Yes | Yes (sentinel verified before/after) |
| TextEdit, no-selection case | — | Fallback attempted, timed out cleanly | — | — | Yes |
| Notes | not automatable in this environment (no Apple Events authorization) — **pending manual pass** | | | | |
| Xcode | pending manual pass | | | | |
| Mail | pending manual pass | | | | |

The no-selection row was observed when a modal sheet blocked ⌘A: AX
returned no selection, the clipboard fallback synthesized ⌘C, nothing was
copied, the bounded wait expired, and the app surfaced "No selected text
was found" then auto-returned to Idle — the exact designed failure path.

Example state trace (TextEdit + Kokoro, from `log stream`):

```
18:52:41.158 State: Idle → Capturing selection…
18:52:41.229 Captured 2464 chars via accessibility
18:52:41.232 State: Capturing selection… → Preparing model…
18:52:41.405 State: Preparing model… → Generating…   (12 chunks)
18:52:43.619 State: Generating… → Speaking            (audio playing)
18:53:06.334 State: Speaking → Stopping…              (second ⌥⎋)
18:53:06.376 State: Stopping… → Idle                  (42 ms)
```

## Offline verification

- After download, model loads and synthesis run entirely from
  `~/Library/Application Support/MLXRead/Models` — verified by re-running
  the integration suite with everything cached: no re-download occurred
  (Kokoro prepare+synthesize completed in 1.7 s; the download path takes
  minutes) and `ModelUtils` logged "Using cached model".
- A true pull-the-cable run (disable networking, then read) is a manual
  step documented in docs/privacy.md; it was not automated because
  disabling the machine's networking from an unattended session is
  disruptive.

## System voice provider proofs

See docs/system-voice-provider.md for the full evidence list (pluginkit
discovery, AudioComponent registry, `speechVoices()`, `say` rendering
non-silent AIFF, repeated synthesis, cancellation).

## Not verified / honest gaps

- Manual matrix rows: Notes, Xcode, Mail, and a user-driven pass of the
  PDF row with the real engine.
- System Settings voice picker and native Speak Selection using the
  provider voice (requires manual user selection of the voice).
- Offline synthesis with networking physically disabled (manual procedure
  documented).
