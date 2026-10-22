---
artifact: prd
version: "1.1"
created: 2026-10-22
status: draft
---

# PRD: Clear readiness and recovery for local listening

Product owner: James. Status: proposed scope and targets; not approved for
implementation. Source baseline: `main` at
`12b2abdd234bc64e53f54aa0fd15f954a35a2194`.

## Overview

### Problem Statement

A reader should know whether they can listen now and how to recover. Preview
can work before selection permission; menu reading can work without the
shortcut; another voice can preview while the saved voice is missing. One
Ready state risks hiding useful actions or promising an unavailable one.

Source confirms separate capability owners, setup completion before model
readiness, and some failures routed generally to Settings. Confusion is an
inferred risk, not a measured incident rate. [CUSTOMER.md](CUSTOMER.md) defines
the job: comfortable listening without losing one's place.

**Why now:** The [three approach options](APPROACH-OPTIONS.md) would reorganize
different parts of that experience. Establish their common behavior before
changing the entry flow. A, B, and C remain unselected, and
[ADR-001](adr/001-operation-readiness.md) remains Proposed.

### Solution Summary

Explain readiness for the attempted action, preserve other usable actions,
and provide recovery in existing surfaces. Keep playback status and Stop
available. Check current behavior first and repair only demonstrated gaps.

### Target Users

Apple Silicon Mac users who want private selection reading: first-time users
preparing a voice and returning users whose permissions, assets, or settings
have changed.

## Goals & Success Metrics

### Goals

1. Help the reader identify the next useful action and reach a successful local read.
2. Keep valid preview and reading paths available when another capability is blocked.
3. Preserve privacy, predictable Stop behavior, and the reader's saved choices.

### Success Metrics

Targets below are proposed acceptance criteria, not measured results. Measure
the baseline and candidate using the same fixtures and instructions.

| Metric | Current Baseline | Target | Timeline |
| --- | --- | --- | --- |
| M1: Correct action availability and recovery | Complete current matrix unmeasured | All 15 groups pass, including every listed condition; zero false-ready or wrongly blocked actions | M-B and M-C |
| M2: Reach the relevant recovery control | Not measured | At most 2 in-app activations from the displayed permission, model, voice, or shortcut blocker to its recovery control | M-B and M-C |
| M3: Status reflects an observed change | Not measured | Every affected visible control updates within 2 seconds of the owning service reporting a change | M-C |
| M4: Reader understands and recovers | No current user-study baseline | At least 4 of 5 representative Mac users recover from an assigned block and hear selected test text without coaching, with model assets cached | M-D |
| G1: Privacy and playback guardrails | Existing contracts and dated checks; no fresh candidate run | Zero failures in required privacy, clipboard, Stop, stale-session, and preference-preservation checks | M-C |

M2 counts control activations after the blocker is displayed; discovering it
from the source app with the menu closed is recorded separately under AC-07
and M4. OS interaction and download waiting are excluded. Reaching recovery
is not completing it. M3 begins at service observation, not
an undetected external change. M4 uses a public passage and consistent task
instructions; five participants provide directional evidence, not statistical
lift. Record scenario IDs, raw outcomes, actions, and times manually in existing
task evidence. Add no analytics, private passages, or scheduled research.

### Non-Goals

Voice-quality superiority, retention growth, faster synthesis, and a guarantee
that every app exposes its selection are not success claims for this initiative.

## User Stories

| ID | User Story | Priority |
| --- | --- | --- |
| US-1 | As a new reader, I want to preview a voice before granting selection access so I can hear what I am setting up. | P0 |
| US-2 | As a blocked reader, I want a specific explanation and recovery route so I can get back to my passage. | P0 |
| US-3 | As a reader with an unavailable shortcut or saved voice, I want other valid actions to remain usable. | P0 |
| US-4 | As an active listener, I want Stop and playback status to remain dependable while settings or prerequisites change. | P0 |
| US-5 | As a returning reader, I want current readiness and my saved choices to remain accurate after changes. | P1 |

All listed requirements and scenario groups must pass for this scope.

## Scope

### In Scope

- Readiness descriptions, action availability, and recovery routes in the menu,
  Voice, Models, Permissions, and existing setup surface.
- Consistent handling of missing assets, invalid voices, permission changes,
  shortcut recovery, and retained playback errors.
- Existing native keyboard access, labels, layout, and playback controls affected
  by those changes; the playback panel remains optional.

### Out of Scope

- Choosing or implementing the full A/B/C experience, changing setup order or
  automatic closure, replacing the default engine, or changing panel defaults.
- New models, cloud speech, accounts, saved text, reading history, transcripts,
  pause/resume, seeking, automatic language detection, or telemetry.
- Website/API changes, credential work, packaging, installation, and publication.

### Future Considerations

Evaluate A/B/C separately for broader experience direction. Listener preference
needs its own listening evidence. Stronger offline-readiness claims would need
additional asset and network-blocked verification; none is inferred here.

## Solution Design

### Functional Requirements

#### Explain and recover

- **FR-1 — Action-specific status (US-1, US-3).** Distinguish preview, selection,
  and shortcut readiness. A blocked capability must not disable another eligible
  operation. Setup completion must not imply all three are available.
- **FR-2 — Named next action (US-2).** A blocked primary action must have an
  adjacent explanation and a clearly named recovery route: permission controls,
  download/retry, voice choice, or shortcut retry. Reach that control within M2.
  Show the first actionable blocker; do not open windows or prompt solely
  because a status is rendered. A received blocked request updates the existing
  menu-bar warning/help; opening the menu reveals its reason and recovery.
  If the shortcut cannot receive requests, expose its known unavailable state
  through that same static indicator and explain the menu fallback in setup.
  Do not imply that an unheard keystroke triggered feedback. The
  [screen proposal](DESIGN.md#readiness-and-recovery-screen-proposal--2026-10-22)
  specifies the proposed destinations and focus behavior.
- **FR-3 — Honest setup state (US-5).** Distinguish selection access from
  model/voice preparation. Closing setup or receiving a grant cannot make
  unavailable actions appear ready. Preserve the completion key, closure
  behavior, and Show Setup action.

#### Preserve valid paths

- **FR-4 — Explicit preview semantics (US-1, US-3).** Voice settings Preview
  auditions a valid requested voice/language without selection permission or
  shortcut health, even when the saved voice is unavailable. It preserves the
  reading voice; Use explicitly selects the replacement. Models preview keeps
  its existing effect: select that model, then play its sample. Label the
  unselected-model action Use & Preview; Use Model selects without playback.
  Preserve per-model saved voices and existing configuration rules. Neither
  preview captures a selection. Empty Voice sample input starts no engine.
- **FR-5 — Selection and shortcut boundaries (US-3).** Menu reading requires
  current selection permission and a usable selected configuration, not shortcut
  health. Shortcut guidance distinguishes active, starting, and retry-needed
  states. Preserve existing retry limits and explicit permission controls.
- **FR-6 — Explicit asset recovery (US-2).** Missing or incomplete model assets
  require an explicit download/retry. Reflect downloading, cancellation, checking,
  and deletion honestly, with only actions supported by that operation. A missing
  or incompatible voice requires explicit selection or asset recovery; do not
  silently change voices or reacquire deleted weights. A failed/incomplete
  download retains an understandable failure and explicit Retry Download.
  Preserve choices and entered sample text through retry; show readiness only
  after asset validation, then support a successful explicit preview/read.

#### Keep state and control trustworthy

- **FR-7 — Fresh state (US-5).** Reflect reported permission, model, voice,
  language, and shortcut changes within M3. Keep Refresh Status for externally
  changed assets; add no automatic filesystem monitor.
- **FR-8 — Useful failures (US-2).** Preserve capture and synthesis errors across
  unrelated refreshes. Identify a useful next step and allow user-initiated retry.
  No selection leads back to selecting accessible text in the original app.
  A previous readiness result never bypasses runtime checks.
- **FR-9 — Stop and active configuration (US-4).** During an active session, Stop
  remains available through existing controls regardless of prerequisites for
  another read. Preserve cancellation and stale-audio protection. Hiding an
  enabled playback panel continues speech; displayed pace reflects the active
  reading, while setting changes apply to the next one.
- **FR-10 — Privacy and preferences (US-1, US-5).** Preserve local, ephemeral
  reading content, clipboard restoration, saved settings, and explicit downloads.
  Store no readiness flag, captured passage, or preview text. Status and diagnostics
  must not expose reading text. No new telemetry or persistence schema is required.
- **FR-11 — Accessible native controls (US-2, US-4).** Explain status in text,
  provide meaningful accessibility labels, retain visible keyboard focus, and
  keep the primary recovery action usable at the existing Settings size. Long
  errors wrap or disclose details without clipping the action. Color alone must
  not convey availability.

### User Experience

The ordinary path remains: choose a voice → return to the source app → select
text → read → stop or finish. A blocked reader sees why, opens the relevant
existing control, repairs the condition, and returns to the passage. Never
automatically replay a selection. Keep native styling and current views.
The [proposed screen layouts and recovery routes](DESIGN.md#readiness-and-recovery-screen-proposal--2026-10-22)
and [interactive study](design/readiness-recovery.html) make the design reviewable;
they do not establish implementation, native usability, or acceptance.

### Edge Cases and Acceptance Matrix

All rows assume idle playback unless stated. Each listed condition within a
row must pass; these are 15 scenario groups, not 15 claimed test executions.

| ID | Scenario | Expected Behavior | Requirements |
| --- | --- | --- | --- |
| AC-01 | Valid assets, voice/language, permission, and shortcut | Preview and both reading entries work on the public fixture; completion returns to current readiness | FR-1, FR-4, FR-5 |
| AC-02 | Accessibility not granted | Valid sample previews work; selection entries explain permission recovery | FR-1, FR-2, FR-4, FR-5 |
| AC-03 | Setup flag is complete but the selected model is absent | No false-ready state; explicit download route; stored preferences remain | FR-2, FR-3, FR-6, FR-10 |
| AC-04 | Model is downloading, cancelling, checking, or deleting | State and supported actions match the operation; no new read on unavailable assets | FR-6, FR-7 |
| AC-05 | Saved voice missing; another compatible voice is installed | The valid alternative previews without becoming selected; reading stays gated until explicit recovery | FR-1, FR-4, FR-6 |
| AC-06 | Requested voice/language pair is unsupported | That request is blocked; a row may offer a clearly labelled compatible-language preview; no silent reading-language change | FR-4, FR-6 |
| AC-07 | Permission granted; shortcut starting or retry needed; begin in the source app with the menu closed | Preview and menu reading remain usable; the static menu-bar warning/help exposes the unavailable shortcut without receiving a keystroke; opening the menu reveals status, retry, and menu reading. Record discovery separately from the M2 navigation count | FR-1, FR-2, FR-5 |
| AC-08 | Permission is revoked during reading | Existing revocation path stops the session; selection becomes gated; a subsequent valid sample remains eligible | FR-5, FR-7, FR-9 |
| AC-09 | Assets change externally, then Refresh Status observes the change | Affected actions reflect the new availability within M3; refresh does not alter the saved voice | FR-6, FR-7, FR-10 |
| AC-10 | Empty sample, or no capturable selection | Empty preview starts no engine; failed capture gives an actionable error without persisting text | FR-4, FR-8, FR-10 |
| AC-11 | Capture/synthesis fails, then unrelated availability refreshes | Error remains visible until the existing explicit retry or relevant-change behavior resolves it | FR-7, FR-8 |
| AC-12 | Reading is active; settings or new-read availability changes | Stop remains dependable; active pace remains accurate; Hide continues playback; a new read uses current settings | FR-7, FR-9 |
| AC-13 | Another downloaded model is available; invoke Models Use & Preview | The label states its selecting effect; the chosen model becomes active and its sample plays. Per-model saved voices remain; the following read uses the chosen model. Voice-row audition remains nonselecting | FR-1, FR-4, FR-10 |
| AC-14 | Controlled transport failure, then separately an incomplete asset result, followed by retry | Failure explains recovery; Retry is explicit; choices and edited sample remain. Validation completes before readiness; a subsequent explicit preview or selection read succeeds, with no automatic replay | FR-2, FR-6, FR-7, FR-8, FR-10 |
| AC-15 | An eligible action is displayed, then permission or assets change before presentation refreshes | Exercise each prerequisite separately. Runtime checks reject or safely fail the stale-ready request, retain useful recovery, and start no implicit download or preference change; recovery allows a subsequent explicit request | FR-5, FR-6, FR-7, FR-8, FR-10 |

Apply FR-11 to every affected surface and privacy/clipboard guardrails across
the matrix. Missing selection or audio-device failure must remain actionable
even when prerequisites were satisfied.

## Technical Considerations

### Constraints

Keep SwiftUI/AppKit, local synthesis, and model compatibility. Use Xcode;
plain `swift build` lacks required Metal kernels.
[ADR-001](adr/001-operation-readiness.md) proposes shared AppState queries.
It remains Proposed; these product requirements do not prescribe that design.

### Integration Points

Reuse ModelStore for assets, SelectionAccessService for permission/shortcut,
and SpeechCoordinator for speech/Stop/errors, through existing views. Add no
external API integration.

### Data Requirements

Retain preferences; keep samples in memory and captured text out of status,
storage, and logs. No analytics schema is proposed. Downloads and online
previews do not prove offline readiness; [privacy.md](privacy.md) owns that claim.

## Dependencies & Risks

### Dependencies

Owners below identify responsibility, not newly assigned workers.

| Dependency | Owner | Status | Impact if Delayed |
| --- | --- | --- | --- |
| Scope, targets, and recovery placement | James | Draft; review pending | Product scope remains provisional |
| Implementation approach, including ADR disposition | Existing native implementation owner with James | ADR Proposed; no implementation assigned here | Internal design cannot be treated as settled |
| Native app resume and current build/test admission | James and existing native owner | Existing hold remains; this request produces documents | Native baseline and implementation wait for explicit resume and valid admission |
| Suitable test Mac, signing identity, local assets, and permission access | Existing native owner | Recheck at authorized execution | Native behavior and offline claims cannot be established |
| Five participant sessions | James/product owner | Proposed; participants and dates not booked | M4 remains unknown; engineering checks cannot substitute |

### Risks

Likelihoods are planning judgments, not measured incident rates.

| Risk | Likelihood | Impact | Owner / Mitigation |
| --- | --- | --- | --- |
| A global Ready state blocks valid previews or menu reading | Medium | High | Native owner: preserve operation-specific AC-02, AC-05, AC-07 |
| A refresh hides an error or interferes with Stop | Medium | High | Native owner: preserve coordinator contracts and AC-08, AC-11, AC-12 |
| Scope grows into an unselected A/B/C redesign | Medium | Medium | James: retain present flow and defaults; approve broader direction separately |
| Download/device variability obscures usability results | High | Medium | Native owner/product owner: cache assets for M4; exercise acquisition states in AC-03/04 and completed failure/retry recovery in AC-14 |
| Small study is reported as proven growth or voice preference | Medium | Medium | Product owner: report counts and conditions; make neither claim |

## Timeline & Milestones

Dates remain uncommitted. Work follows the scope decision and native resume;
reuse prior evidence only while its inputs and conditions still match.

| Milestone | Description / Exit | Target |
| --- | --- | --- |
| M-A: Scope | Resolve material questions; confirm requirements and targets; record ADR disposition | Before implementation |
| M-B: Baseline | Exercise existing behavior, record matrix/action counts, identify actual gaps; retain passing behavior | First authorized native assessment |
| M-C: Candidate | Repair only scoped gaps; pass M1–M3 and G1, relevant `script/test.sh` checks, and affected native controls | After baseline; before implementation completion claim |
| M-D: Product validation | Complete the five-reader check and report M4 with limitations; revise if the proposed target is missed | After a usable candidate and participant availability |
| M-E: Handoff | Bind source, checks, unresolved limits, and product evidence; James decides acceptance | After candidate and product review |

This work has no launch milestone. Packaging, installation, and publication
remain separately scoped actions.

## Open Questions

- [ ] Confirm this bounded readiness/recovery scope independently of A/B/C. Owner: James; before implementation.
- [ ] Confirm the two-action, two-second, and 4-of-5 targets after baseline review; any change must be recorded before candidate evaluation. Owner: James with native/product owners.
- [ ] Accept, revise, or decline ADR-001's shared-query design. Owner: James with the native owner; before dependent code changes.
- [ ] Confirm exact recovery copy and placement within existing surfaces. Owner: James/design with native owner; before UI changes.
- [ ] Identify participants and a manual observation window for M4. Owner: James/product owner; before scheduling sessions.
- [ ] Resolve PM finding F-04: freeze participant characteristics, fixed starting conditions, scenario assignments, allowed instructions, timeout/abandonment, and successful-read criteria before comparing baseline and candidate; report by scenario. Owner: James/product owner; before M-D.
- [ ] Re-review proposed dispositions for F-01/02/03/05 against the screen study and acceptance matrix; native verification remains outstanding. Owner: James with design/native owner; before engineering handoff.

## Appendix

### Related Documents

- [Customer job](CUSTOMER.md), [product](PRODUCT.md), and [positioning](POSITIONING.md) — existing intent and its evidence limits.
- [Approach options](APPROACH-OPTIONS.md) — three draft organizing approaches; no winner selected.
- [ADR-001](adr/001-operation-readiness.md) and [architecture](architecture.md) — proposed and implemented technical context, respectively.
- [Design](DESIGN.md), [experiments](EXPERIMENTS.md), and [testing](testing.md) — established UI direction and dated evidence.
- [Privacy](privacy.md) and [contributing](../CONTRIBUTING.md) — invariants, native setup, and verification entrypoints.

### Revision History

| Version | Date | Author | Changes |
| --- | --- | --- | --- |
| 1.0 | 2026-10-22 | Codex; prepared for James | Initial draft; scope, targets, and implementation remain unapproved |
| 1.1 | 2026-10-22 | Codex; prepared for James | Screen-design proposal distinguishes preview effects, adds discovery and completed recovery, and extends the matrix to 15 groups. F-04 remains open; other findings have proposed dispositions pending re-review and native proof. Status remains draft |
