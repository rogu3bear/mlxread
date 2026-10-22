---
artifact: adr
version: "1.0"
created: 2026-10-22
status: draft
---

# ADR-001: Derived operation readiness

## Status

Proposed

**Date:** 2026-10-22
**Decider:** James; review pending.
**Source baseline:** `12b2abdd234bc64e53f54aa0fd15f954a35a2194`.

Initial proposal; no acceptance or implementation is recorded. The three
product approaches remain unselected. This record proposes how the application
answers readiness questions, independently of which experience is chosen.

## Context

MLXRead reads selected text through local synthesis. Its proposed shortcut,
voice-audition, and visible-control experiences all need to explain which
actions are available. They share services but have different prerequisites.
A single application-wide Ready flag would lose those distinctions.

Current source distributes the relevant facts and checks:

- `ModelStore.availability` checks the model's downloaded state, the requested
  voice, and language compatibility.
- `SelectionAccessService` separately owns Accessibility trust, shortcut health,
  and shortcut recovery. Permission can be granted while the shortcut is still
  starting or needs a retry.
- `AppState.wireAvailability` supplies distinct selection and sample checks to
  `SpeechCoordinator`. Samples need model assets but no selection permission.
  The menu and Voice view also query their relevant prerequisites directly.
- `OnboardingView` sets the persisted `onboardingCompleted` flag when setup is
  closed or Accessibility becomes trusted. That flag records a setup event;
  it does not establish model availability or current shortcut health.

These distinctions are intentional. A listener can preview a different valid
voice while their saved reading voice is unavailable. Menu reading can remain
usable when the keyboard shortcut is unhealthy. Neither completing setup nor
having downloaded weights proves that synthesis will succeed or that every
pronunciation asset is cached for offline use.

Reorganizing the UI creates a choice: extend separate view-level predicates,
persist a broad completion flag, or provide one shared way to query the existing
owners. We need consistent prerequisites without introducing another speech
state machine or choosing product approach A, B, or C by implication.

## Decision

We will expose a shared, derived operation-readiness contract through the
existing `AppState` composition root. Views and coordinator availability
callbacks will use it for prerequisite checks. Existing services will continue
to own the facts, and `SpeechCoordinator` will continue to own execution,
cancellation, and retained errors.

The proposed contract has three operation-specific queries:

1. **Voice preview:** Check the requested model, voice, and language using the
   existing model-availability rules. Use the preview's configuration, which
   can differ from the saved reading voice. Require neither Accessibility
   permission nor an active shortcut.
2. **Selection reading from the menu:** Check Accessibility trust and the
   selected model, voice, and language. Do not require an active shortcut.
3. **Selection reading through the shortcut:** Apply selection-reading checks
   and additionally report whether the shortcut is active. Preserve the
   existing distinction between starting and requiring an explicit retry.

Each query returns eligible-to-attempt or a named blocking reason. Preserve the
current permission → model → voice priority for selection checks; shortcut
health adds its own condition. Reuse `ModelStore.availability` and the existing
permission/shortcut owner rather than creating another asset inventory or
permission monitor. Adapt the selection and preview results to the existing
coordinator gate callbacks; shortcut health must not enter the shared selection
callback and inadvertently disable menu reading.

Readiness describes prerequisites, not playback state. Views combine it with
`SpeechCoordinator.state` and local input validity when enabling an action.
Empty sample input remains a command guard. Busy-state handling and Stop run
through the existing coordinator; Stop is never gated on readiness for a new
read. A readiness refresh must not erase a retained synthesis or capture error
when the existing coordinator contract would preserve it.

Queries will not persist readiness, change preferences, prompt for permission,
download assets, load an engine, or start background work. They reuse existing
read-only availability checks. There is no new service, actor, polling loop,
database, or network surface. Selected and sample text are not inputs to the
shared readiness value and are never retained by it.

Keep the existing `onboardingCompleted` storage key and dismissal behavior
until an explicitly selected flow changes them. Do not use that stored flag as
runtime readiness. This ADR does not choose setup order, automatic setup
closure, the default voice, catalog presentation, or the playback-panel default.

The projection is advisory to presentation. Action entry points and the engine
retain their existing checks against current conditions; a prior eligible
result is not a reservation. Do not expose an offline-verified result from
download state or a previous successful preview. Offline behavior retains its
separate model/asset and verification requirements.

## Consequences

### Positive

- Setup, Voice, menu actions, and permission guidance can share the same
  prerequisite semantics while presenting different experiences.
- Legitimate partial capability remains visible: previews without selection
  permission, menu reading without a healthy shortcut, and audition of a valid
  alternative to an unavailable saved voice.
- Ownership stays with existing services. No persisted readiness state needs
  invalidation after permission revocation, model deletion, or voice changes.
- The proposal supports all three product approaches without selecting one or
  changing the local, ephemeral reading-content boundary.

### Negative

- Introducing a shared result and adapting callers costs more than retaining
  the current predicates. Migration must preserve their useful differences.
- Changes to model compatibility or operation prerequisites now affect a shared
  contract and require checking every consumer, not only the edited view.
- Derived checks cannot guarantee future capture or synthesis success. The
  source application, files, permission, or audio device may change after a
  check; runtime guards and actionable errors remain necessary.
- Read-only model checks may inspect local files. This proposal does not claim
  that computing readiness is free or authorize an independent cache to hide
  that cost.

### Neutral

- No new persisted schema, dependency, or model is required. Saved voice,
  language, pace, and panel preferences keep their existing meaning.
- Current architecture documentation continues to describe the implemented
  system. This Proposed record governs no runtime until it is accepted and
  implemented through a separately authorized change.
- Native app and release holds remain in force. Source inspection establishes
  the design inputs; no build, native interaction, or offline test was run for
  this documentation change.

If implementation is later authorized, its focused verification must retain
the existing preview-permission, preview-voice, error-retention, and Stop
contracts. Add coverage for menu reading with an unhealthy shortcut, immediate
readiness changes after permission/model/voice changes, and a completed setup
flag coexisting with unavailable capabilities. Use the existing
`script/test.sh` entrypoint and native checks for affected controls; do not
treat these planned checks as completed evidence.

## Alternatives Considered

### Keep all existing view-level predicates

This remains a valid implementation for the current app and has the lowest
immediate cost. It is not the proposed direction for a UI reorganization
because multiple surfaces would continue to assemble the same prerequisites
independently. If no consumer needs a shared contract, do not implement an
abstraction merely because this draft exists.

### Persist one ready or setup-complete flag

This is simple to display but becomes stale when permission, model assets,
voice selection, or shortcut health changes. It also conflates preview,
selection, and shortcut capability. The existing setup flag is retained as
history rather than promoted into that role.

### Add a separate readiness service with its own observed state

An independent observable service could publish updates, but would duplicate
facts and lifecycle responsibilities already owned by `ModelStore` and
`SelectionAccessService`. The proposed derived contract needs no separate
monitor, mutable readiness cache, or new service lifecycle.

### Expand SpeechState into a complete capability model

`SpeechState` already represents playback and resting gates. Encoding every
combination of permission, shortcut, preview, and selected-voice availability
there would mix independent capabilities with one active speech session.
Keeping readiness derived alongside that state preserves the coordinator's
current cancellation and error-retention semantics.

## References

- [Product approach options](../APPROACH-OPTIONS.md) — draft alternatives, not a selected implementation.
- [Current architecture](../architecture.md) — implemented state and service ownership.
- [Technical decisions](../technical-decisions.md) — model, cache, build, and concurrency rationale.
- [Privacy](../privacy.md) — reading-content and offline boundaries.
- [AppState](../../MLXRead/App/AppState.swift) — composition and separate availability callbacks.
- [ModelStore](../../MLXRead/Models/ModelStore.swift) — asset, voice, and language availability.
- [SelectionAccessService](../../MLXRead/Accessibility/SelectionAccessService.swift) — permission and shortcut facts.
- [OnboardingWindow](../../MLXRead/UI/OnboardingWindow.swift) — setup completion behavior.
- [MenuBarContent](../../MLXRead/UI/MenuBarContent.swift) and [VoiceSettingsView](../../MLXRead/UI/VoiceSettingsView.swift) — current prerequisite consumers.
- [SpeechCoordinator](../../MLXRead/Speech/SpeechCoordinator.swift) — execution, preview, Stop, and retained errors.
- [Coordinator tests](../../MLXReadTests/SpeechCoordinatorTests.swift), [selection-access tests](../../MLXReadTests/SelectionAccessTests.swift), and [settings/model tests](../../MLXReadTests/SettingsAndModelTests.swift) — existing contracts to preserve; not executed for this record.
