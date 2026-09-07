# Product

## Vision

Hear selected text comfortably without leaving the current task. Keep speech
local and the interface easy to read, with each control connected to a useful
listening decision.

## MVP Definition

Existing native macOS menu-bar app: selection capture, local synthesis, voice
and speed selection, model acquisition, permissions, optional HUD, and support.
This pass improves those surfaces; it does not introduce cloud speech, accounts,
a new model, or website/release changes.

## Outcome Roadmap

| Outcome / problem | Job served | Priority | Status | Owner |
|---|---|---|---|---|
| Understand and compare voices | Comfortable listening | P1 | Implemented | TASK |
| Use native Kokoro timing | Comfortable pace | P1 | Implemented | TASK |
| Read all settings and recovery text | Independent use | P1 | Implemented | TASK |
| Cut inert selection preview control | Trust exposed controls | P2 | Implemented | TASK |
| Replace reset-onboarding with Show Setup | Recover setup instructions | P2 | Implemented | TASK |
| Put model internals under details | Choose from useful information | P2 | Implemented | TASK |
| Confirm listener preference after timing change | Perceived voice quality | P2 | Awaiting human evidence | Product owner |

## Opportunity Solution Tree Notes

Comfortable speech → clear voice choice / understandable pace / immediate
preview and stop. Findings and experiments are in DESIGN.md and EXPERIMENTS.md.

## Hook Model

Trigger: a passage to hear. Action: Option–Escape. Reward: intelligible speech.
Investment: chosen voice and pace. Predictability matters more than variable
rewards in this utility. The weakest observed source surface is voice setup.

## Activation & Retention Plan

| Friction / moment | Fix | Owner | Status |
|---|---|---|---|
| First voice choice | Names, language, visible sample | TASK | Implemented |
| Model not available | Explicit download, progress and retry | TASK | Implemented |
| Daily playback | Truthful status and reachable stop | TASK | Implemented |

## Discovery Cadence

No recurring research task was requested. Human listening comparison remains a
named follow-up, not an invented interview result or scheduled activity.

## Final cold review — 2026-09-07

The One Thing is comfortable local listening to selected text. With an installed
model, voice comparison takes three actions from Voice settings: open the voice
picker, choose a voice, press Preview Voice. The settings open on Voice in a new
window, and the sample and action fit in the first view. The ordinary selection
shortcut remains dependent on Accessibility; this development build has no grant.

Binary verdict: **NOT DONE for a claim of preferred or superior sound.** The
defined local voice/readability changes pass their acceptance checks and are
ready for review. A listener must still compare voice quality. That evidence gap
is recorded separately from working preview, timing, layout and stop controls.

| Ranked cut / fix | Disposition | Owner / priority |
|---|---|---|
| 1. Raw voice IDs and an English-only preview | Replaced with names, language groups and matching samples | TASK / P1 |
| 2. Kokoro playback stretching at every selected speed | Replaced with native synthesis duration control | TASK / P1 |
| 3. Caption-size instructions, crowded preview and clipped HUD state | Repaired; final native inspection passed | TASK / P1 |
| 4. Empty preview saying Ready and language/accent miscount | Repaired | TASK / P1 |
| 5. Inert selection-preview toggle and preference-only setup reset | Removed toggle; Show Setup opens immediately | TASK / P2 |
| 6. Model internals in the main decision path | Kept under Model details | TASK / P2 |
| 7. Listener preference at normal and faster pace | Deferred; no subjective quality result claimed | Product owner / P2 |
| 8. Wider appearance/accessibility and fresh-download lifecycle checks | Deferred; native Dark walkthrough and local logic checks are complete | Product owner / P2 |

The secondary-surface audit covered General, Models, Permissions, Report,
setup and the floating panel. No paywall, billing, account or cancellation
surface exists in the native app. Website pages and release operations remain
with their existing owners. No customer experiment or publication occurred.
