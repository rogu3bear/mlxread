# Improve App Plan

## Context

Started 2026-09-06. User direction: “improve voice is the goal, make all text
legible and each part of the UX meaningful”; `--force-auto` delegates routine
phase and design choices. Native macOS selection-to-speech app. Evidence is the
current source, cached models, and subsequent local checks; no customer
interviews, retention data, or listening preference results were supplied.
The individual framework skills are unavailable locally; use the journey's
Brief methods. No prior improve-app tracker or shared artifacts existed.

Direct TASK on `/Users/star/dev/mlxread`, branch `main`, base
`ad3286998f70a3cfd8aa16581f45f441a47dc496`. Scope: native voice/readability
experience, its direct logic/tests, and these journey artifacts. Preserve the
existing release/API/website changes and untracked files. No commit or release
is part of this request. Repository ANCHOR.md is absent; AGENTS.md routes to
README.md, CONTRIBUTING.md, and the existing architecture/privacy owners.

## Phase Status

| Phase | Skill | Status | Artifact | Date |
|---|---|---|---|---|
| 1 | jobs-to-be-done | done | CUSTOMER.md | 2026-09-06 |
| 2 | ux-heuristics | done | DESIGN.md, EXPERIMENTS.md | 2026-09-06 |
| 3 | design-everyday-things | done | DESIGN.md, EXPERIMENTS.md | 2026-09-06 |
| 4 | refactoring-ui | done | DESIGN.md, EXPERIMENTS.md | 2026-09-07 |
| 5 | microinteractions | done | DESIGN.md, EXPERIMENTS.md | 2026-09-07 |
| 6 | made-to-stick | done | POSITIONING.md, EXPERIMENTS.md | 2026-09-07 |
| 7 | influence-psychology | skipped: no native upsell surface | POSITIONING.md | 2026-09-06 |
| 8 | high-perf-browser | skipped: native app; website outside scope | DESIGN.md | 2026-09-06 |
| 9 | steve-jobs-design-review | done | PRODUCT.md, DESIGN.md, EXPERIMENTS.md | 2026-09-07 |

Statuses: pending · in-progress · awaiting-evidence · done · deferred: reason · skipped: reason

## Key Decisions

| Date | Phase | Decision | Rationale |
|---|---|---|---|
| 2026-09-06 | 1 | Prioritize comfortable daily listening; functional underdelivery first | Direct user goal; retention impact is unmeasured |
| 2026-09-06 | 2–3 | Fix opaque voices, implicit download, misleading controls, and small text now | Severity × daily exposure; no observed severity-4 issue |
| 2026-09-06 | 3 | Block preview until assets exist; keep stop reachable | Prevent accidental download and ambiguous activity |
| 2026-09-06 | 4 | Keep native forms and adaptive colors; increase room and body text | Readable grayscale hierarchy before decoration |
| 2026-09-06 | 5 | Voice preview is the signature interaction; keep it explicit | Hearing a voice is the useful decision point |
| 2026-09-06 | 5 | Kokoro uses native duration control; Soprano uses playback rate | Existing model capability; no new voice model or download |
| 2026-09-06 | 6 | Name voices and languages, show the actual sample, explain next action | Replace engine vocabulary with listening decisions |
| 2026-09-06 | 7 | No persuasion additions | There is no paywall or upgrade flow |
| 2026-09-06 | 9 | Remove the nonfunctional selection-preview toggle; make setup reopening immediate | Every exposed control must have an observable purpose |

| 2026-09-07 | 4–6 | Fix empty-preview feedback, small range labels, number-field signifiers, language count, and clipped HUD status | Reproduced in the native walkthrough; V12–V15 recorded before edits |
| 2026-09-07 | 9 | Finish local UX changes; defer subjective listening preference and a broader appearance/accessibility matrix | Native preview and stop work; no listener preference study or new system permission is available |

## Next Actions

- [x] Implement and verify the recorded experiments (owner: TASK; completed 2026-09-07).
- [x] Record the final cold walkthrough and remaining evidence gaps in PRODUCT.md (owner: TASK; completed 2026-09-07).

Local journey closed. Remaining evidence work is assigned in PRODUCT.md and
EXPERIMENTS.md. See [VOICE-UX-HANDOFF.md](VOICE-UX-HANDOFF.md) for exact local
proof and limitations; this is not publication or integration.
