# Voice and readability handoff

The native voice/readability pass is implemented and locally verified. Voice
settings now centers on named voices, language-matched samples, native Kokoro
pace and reachable preview/stop controls. The final walkthrough also repaired
an empty-preview status mismatch and clipped floating-panel text.

HANDOFF_VERSION: OPS-1

WORK_ID: N/A — direct user task

CHAT_REF: 01a07a0e-bbbd-7960-a541-11540c8050b9

ROLE: TASK

STATUS: READY_FOR_REVIEW

REPO: /Users/star/dev/mlxread

TARGET_BRANCH: N/A — no integration assignment; observed branch is main

CANDIDATE_BRANCH: N/A — local uncommitted work on the existing checkout

BASE_SHA: ad3286998f70a3cfd8aa16581f45f441a47dc496

OBSERVED_HEAD: ad3286998f70a3cfd8aa16581f45f441a47dc496

TREE: Dirty, with pre-existing release/API/website work preserved. Git common
directory is /Users/star/dev/mlxread/.git. The legacy mail-routing worktree was
inventoried without mutation. No branch switch, commit, push or integration.

CANDIDATE_SHA: N/A — no candidate commit

REVIEW_TARGET_SHA: N/A

REVIEW_VERDICT: N/A

INTEGRATED_SHA: N/A

CHANGED:

- Voice names and language groups, matching in-memory samples, explicit model
  availability gating, empty-sample guidance, and model-specific voice retention.
- Kokoro synthesis duration control; Soprano playback-rate routing. Each reading
  retains its starting engine/configuration and cancellation targets that engine.
- Readable, scrollable native settings; clear selection-limit editing; concise
  recovery/status text; visible model details; immediate Show Setup; removal of
  the unused selection-preview preference.
- HUD labels and 160-point status / 44-point rate space prevent clipping. Stop
  and Hide have distinct accessible names and behavior.
- Related unit/integration tests, README, architecture/privacy explanations,
  and the six improve-app journey artifacts.
- Final resumed edits are limited to ModelManifest.swift, GeneralSettingsView,
  VoiceSettingsView, PlaybackHUD and journey/handoff documents. Existing release,
  API and website bytes match the resume baseline; .env was never opened.

VERIFIED:

- `script/test.sh` with local ad-hoc signing via the ignored
  `build/voice-local-signing.xcconfig`: **60 unit tests passed**, nine opt-in
  integration/benchmark cases skipped, no failures. Receipt:
  `build/voice-verified-tests.log` and
  `build/DerivedData/Logs/Test/Test-MLXRead-2026.09.06_23-52-50--0500.xcresult`.
- Retained real-model run: **67 tests passed**, two benchmarks skipped,
  including all seven integration cases. `build/voice-tests-adhoc.log` records
  Kokoro durations of 8.275 s at 1×, 5.325 s at 1.5× and 8.275 s restored to 1×;
  output was finite and non-silent. Later edits did not change speech logic.
- Final Xcode Debug build passes, including Metal kernels. Receipt:
  `build/voice-hud-verified-build.log`. The final HUD-only sizing change was
  checked by compilation and direct native interaction; no redundant unit rerun.
- `codesign --verify --deep --strict` succeeds for the local ad-hoc app.
- Native Dark-appearance walkthrough: all five settings tabs; English and
  Spanish voice/sample selection; real preview; empty-sample constraint and
  guidance; next-reading speed feedback; setup reopening; editable selection
  limit; model/report disclosures; truthful permission state and Recheck.
- Final HUD shows the complete Preparing speech label. Its Stop returns to the
  resting permission gate. Hide leaves speech playing, and the panel returns on
  the next reading. State evidence: `build/voice-native-state.log`.
- Original visible preferences restored: Kokoro/Aoede, 1×, 20,000 characters,
  HUD off. The temporary long sample was replaced with the built-in sample.
- `git diff --check` passes. Final binding of 48 native source/test files:
  `build/voice-final-source-sha256.json`; combined SHA-256
  `9a8334d2428dc3f5b68ef3b670c215f85af0be6ab733728c39defa503f91d93a`.
- Final executable SHA-256:
  `614f26082ed4c524d7c17ffaeca555858c43e56a61ce624fef3a5e07f4fc1f99`.

ESTABLISHED: The native experience supports an understandable voice comparison,
model-appropriate pace, visible recovery and controllable playback. The inspected
text is legible at the default window size; longer forms scroll normally.

INFERENCE: These changes should reduce voice-choice friction and make daily
listening easier. Customer preference and retention effects are not measured.

HYPOTHESIS: A listener may prefer Kokoro's native duration control to applying a
post-synthesis playback multiplier. Timing tests alone do not prove that preference.

UNRESOLVED: Subjective voice quality; Light appearance and a full accessibility
matrix; fresh-download failure/retry and Trash restoration through native UI;
network-disabled synthesis. This ad-hoc build has no Accessibility grant, so
ordinary cross-app selection/Option–Escape was not requalified. No grant was
changed and no report was sent. These limits are separate from verified preview,
speech routing and native layout behavior.

NEXT: Review the local diff and compare voices through Preview Voice. Remaining
evidence work is assigned in PRODUCT.md and EXPERIMENTS.md. No automatic research
or recurring task was created.

CAUTION: The running app is the local development bundle under
build/DerivedData/Build/Products/Debug. The installed app, distribution artifacts,
Cloudflare, release feed, publication and notarization were not updated. Build
receipts are local artifacts and can be removed by a later build cleanup.
