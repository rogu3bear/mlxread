# Testing

All results below were produced on 2026-07-11 on this machine: Apple Silicon
(arm64), macOS 26.5.2, Xcode 26.6 (SDK macOS 26.5).

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
