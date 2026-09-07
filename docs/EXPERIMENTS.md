# Experiments

## Experiment Cards

Criteria recorded before implementation on 2026-09-06. These are local
acceptance experiments, not measured customer preference or retention results.

### EXP-001 — Choose and hear a voice
- Hypothesis: Names, language filtering, and matching preview text make voice comparison understandable.
- Type: smoke test
- Primary metric & threshold (pre-committed): Choose an installed voice and start its visible sample in at most three actions from Voice settings; no asset-missing preview reaches engine preparation.
- Guardrail metric: No captured text persisted or inserted into preview; preview does not require Accessibility.
- Decision rule (pivot / persevere / iterate): Iterate if choice is ambiguous or preview can silently acquire the base model.
- Result & verdict: PASS for the local interaction. Native Voice picker → Heart → Preview took three actions and reached Speaking; Spanish changed both the voice list and sample. Empty text disabled Preview and now explains how to proceed. Unit tests prove missing-model previews never prepare an engine and previews bypass selection permission. Subjective voice preference was not measured.
- Owner / priority: TASK / P1. Findings: V1, V3.

### EXP-002 — Comfortable pace without applying speed twice
- Hypothesis: Kokoro's existing duration control can set pace during synthesis while Soprano retains pitch-preserving playback rate.
- Type: smoke test
- Primary metric & threshold (pre-committed): Real Kokoro speech at 1.5× is shorter than the same sample at 1×, finite and non-silent; coordinator sends 1× playback rate to engines that handle speed.
- Guardrail metric: Soprano receives the selected playback rate; stop and stale-generation tests pass.
- Decision rule (pivot / persevere / iterate): Iterate on duration/routing failure; subjective quality requires listening evidence and is not claimed from PCM tests.
- Result & verdict: PASS for timing/routing. Real Kokoro: 8.275 s at 1×, 5.325 s at 1.5×, and 8.275 s after restoring 1×. All outputs finite/non-silent. Coordinator tests cover native/playback routing, active snapshot, and cancelling the originating engine. Subjective preference remains unmeasured.
- Owner / priority: TASK / P1. Findings: V2, V5. Evidence: build/voice-tests-adhoc.log; 2026-09-06.

### EXP-003 — Every screen reads and every control earns its place
- Hypothesis: Body text, wrapping, space, and direct actions reduce interpretation and dead ends.
- Type: smoke test
- Primary metric & threshold (pre-committed): All five settings tabs reachable; no truncated primary labels/help at default window size; no caption-sized instructions; setup action visibly opens setup; HUD buttons have names. Final-walkthrough additions, recorded before their edits: empty preview states explain the disabled action, speed-range labels use body text, and the selection limit has an editing affordance.
- Guardrail metric: Privacy, clipboard restoration, permission truth, and existing tests preserved; existing release edits remain byte-identical.
- HUD criterion, recorded before the V15 fix: Preparing speech and Speaking render fully, Stop returns to ready, and hiding the panel leaves speech active.
- Decision rule (pivot / persevere / iterate): Iterate on clipping or dead controls; state an explicit gap if native visual inspection is unavailable.
- Result & verdict: PASS for the inspected native surfaces in Dark appearance. All five tabs were reached; longer forms and expanded details scroll, primary labels wrap, Show Setup opens its window, the number field accepts edits, and the preview/stop/hide cycle works. The final HUD shows Preparing speech fully and exposes named Stop/Hide buttons. Original Aoede, 1×, 20,000-character limit, and HUD-off preferences were restored. Light appearance and the complete assistive-technology matrix remain unverified.
- Owner / priority: TASK / P1. Findings: V4–V15. First native walkthrough found preview below the initial view and a duplicate character label; layout was corrected before final verification.

## Experiment Backlog

| Idea | ICE (impact/confidence/ease) | Status | Owner / priority |
|---|---|---|---|
| EXP-001 voice choice and preview | 9/8/8 | Passed local acceptance | TASK / P1 |
| EXP-002 native pace | 9/7/6 | Passed timing/routing | TASK / P1 |
| EXP-003 readable purposeful controls | 8/9/8 | Passed inspected native surfaces | TASK / P1 |
| Listener preference comparison at 1× and 1.5× | 9/5/5 | Awaiting human listening evidence | Product owner / P2 |

## Verification evidence

- `build/voice-verified-tests.log`: 60 passing unit tests; nine opt-in integration/benchmark tests skipped.
- `build/voice-tests-adhoc.log`: retained real-model run, 67 passed and two benchmarks skipped; seven integration tests passed. Speech implementation was unchanged by the later visual fixes.
- `build/voice-hud-verified-build.log`: final Debug build passes; ad-hoc signature verifies. The final HUD-only sizing edit was verified by compilation and native interaction.
- `build/voice-native-state.log`: final preview enters Speaking; Stop reaches the resting permission gate, and hiding the HUD leaves speech active.
- `build/voice-final-source-sha256.json`: native source/test binding. Detailed bounds and the cold-review disposition are in VOICE-UX-HANDOFF.md and PRODUCT.md.
