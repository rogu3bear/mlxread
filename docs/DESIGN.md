# Design System

## Design Direction

A native listening utility. Voice settings answer three questions in order:
which voice, what pace, and how does it sound? The signature moment is a clear,
repeatable preview in the chosen language. No decorative dashboard or invented
voice quality ranking. Local source findings below precede implementation.

## Readiness and recovery screen proposal — 2026-10-22

Status: proposed layout, with an [editable interactive study](design/readiness-recovery.html).
This is a design artifact for the [draft PRD](PRD-READINESS-AND-RECOVERY.md),
not an implemented app change or an accepted A/B/C approach. Source baseline:
`12b2abdd234bc64e53f54aa0fd15f954a35a2194`. The historical implementation
and native checks later in this document retain their original date and scope.

The [sprint map and target](DESIGN-SPRINT-MAP-AND-TARGET.md) recommends testing
closed-menu recovery discovery. The [prototype plan](DESIGN-SPRINT-PROTOTYPE-PLAN.md)
defines a proposed participant version and repeatable interview protocol. The
existing HTML study remains a reviewer artifact: its diagnostic labels and
source-app hints must not be mistaken for an unprompted participant test.

**Task:** Know which listening action is available, recover a blocked one,
and return to the original passage. Keep the existing tabbed Settings window
at 600 × 680 pt, setup at 560 × 460 pt, the menu, and optional playback panel.
No new scene or navigation shell is proposed.

### Surfaces, hierarchy, and ownership

| Surface | Reading order and primary action | Existing layout and state owners |
| --- | --- | --- |
| Voice | Action-specific status → current engine and reading voice → editable sample and pace → voice rows. Preview auditions; Use selects. A missing model replaces unavailable rows with Download or Retry Download. | [VoiceSettingsView](../MLXRead/UI/VoiceSettingsView.swift); AppSettings, ModelStore, SpeechCoordinator |
| Models | Model name and purpose → asset state → Download/Retry or preview/selection actions → optional details. Recovery focuses the selected model's control, including scrolling it into view. | [ModelSettingsView](../MLXRead/UI/ModelSettingsView.swift); ModelStore, AppState, AppSettings |
| Permissions | Selection access and its explicit grant/settings action → shortcut state and Retry Shortcut → OS shortcut-conflict help. Menu reading remains available during shortcut recovery. | [PermissionView](../MLXRead/UI/PermissionView.swift); SelectionAccessService |
| Menu | Current operation or blocker → Read Selection and Stop → relevant recovery destination → other existing commands. Only eligible actions are enabled. | [MenuBarContent](../MLXRead/UI/MenuBarContent.swift), [MLXReadApp](../MLXRead/App/MLXReadApp.swift); AppState, SpeechCoordinator, SelectionAccessService |
| Setup | Selection access → voice preparation → return-to-text instructions and menu fallback. Keep explicit grant, Open Settings, and existing closure behavior. | [OnboardingWindow](../MLXRead/UI/OnboardingWindow.swift); SelectionAccessService, existing setup preference |
| Playback panel | Preparing/Speaking → Stop → active pace → Hide. Hide continues the current speech. | [PlaybackHUD](../MLXRead/UI/PlaybackHUD.swift); SpeechCoordinator's active session |

[SettingsView](../MLXRead/UI/SettingsView.swift) remains the tab-selection owner.
Direct recovery destinations need explicit tab/focus routing in future native
implementation; a generic Settings action is not proof of that route. General,
Report, catalog/language filters, and other menu commands retain their existing
behavior. The study uses a representative voice catalog and focused menu excerpt.

### Preview means two explicit actions

- **Voice → Preview:** audition the requested compatible voice/language without
  changing the saved reading voice. **Use** makes the explicit selection.
  Incompatible reading choices may still offer a labelled compatible-language
  preview, such as **Preview Chinese**.
- **Models → Use & Preview:** select the other model, then preview its sample.
  The label exposes the existing selecting effect. The selected model can keep
  **Preview**; **Use Model** selects without playing. Retain each model's saved
  voice and language. Models uses a fixed sample independently of the Voice
  editor; it still checks the saved voice/language and current assets before
  playback. An unavailable configuration has an explicit Choose Voice route.

### Discovery and recovery

When a received reading request is blocked, update the existing menu-bar item
with a static exclamation badge and meaningful help/accessibility text. Opening
the menu reveals the reason and the recovery action. When the shortcut cannot
receive an attempt, show the same state from the known service status; do not
claim that an unheard keystroke caused a response. Setup and Permissions explain
the menu fallback. No flashing cue, automatic window, or notification is added.

| Blocker | Visible copy | Route from the displayed blocker |
| --- | --- | --- |
| Selection access absent | Voice previews are ready. Selection reading needs Accessibility access. | Open Permissions… → Grant Accessibility Access… |
| Selected model absent/incomplete | Download needed, or The download did not finish. | Open Models… → Download / Retry Download on that model |
| Saved voice absent | Reading voice unavailable. Preview another voice, then choose Use. | Choose Voice… → Use on an available compatible row |
| Shortcut unavailable | Read from this menu while the shortcut recovers. | Retry Shortcut; Read Selection remains an independent option |
| No selected text | No selected text was found. Return to your app, select accessible text, and try again. | Close Settings if open, return to the source app, and explicitly retry |

For the first four cases, the proposed route reaches its recovery control in
at most two in-app activations after the blocker is displayed. Opening the menu
from the source app is a separate discovery step. OS decisions, download waiting,
and returning to the passage are not hidden inside that navigation metric.
The badge's discoverability still needs human observation; a drawn warning does
not establish that a reader will notice or understand it.

### State behavior

| State | Copy, action, and preservation |
| --- | --- |
| Empty sample | Explain Enter a passage or use the sample to preview a voice. Preview is disabled; Use sample text restores the public sample. |
| Missing model | Show Download and its approximate size; keep the saved voice visible. Explain that the first preview can fetch pronunciation assets. |
| Failed acquisition | Keep the failure and Retry Download beside the affected model. Preserve choices and the edited sample. Details wrap/disclose without hiding recovery. |
| Downloading/cancelling/checking | Show the current operation; offer Cancel only while supported. Wait for the writer to stop or validation to finish before claiming readiness. |
| Assets validated | Show Model files ready and eligible actions. Do not start speech or replay a selection automatically. |
| Preparing/speaking | Show the active operation, its captured pace, and Stop. Changes to future pace do not relabel the active session. |
| Missing or incompatible voice | Explain the restriction in text. Keep a valid alternative preview available; select only on Use. |
| Permission/shortcut recovery | Show Granted/Not granted separately from Active/Starting/Unavailable. A permission request does not itself establish a grant. |
| Retained capture/synthesis error | Keep the explanation through unrelated refreshes; preserve the coordinator's explicit retry/relevant-change behavior. |
| Prerequisite changes before action | Runtime checks must reject or safely fail the stale-ready request. The study demonstrates the asset case; real asset and permission races remain unverified. |

### Fit and focus

Keep native system typography, adaptive form surfaces, the established spacing
scale, and text labels alongside status color. Primary previews and recovery
controls fit the initial Settings view; longer catalogs and details scroll.
Navigation focuses the relevant control, scrolls it into view, and starts no
speech. Menu arrows skip disabled items; Escape closes the menu and restores
focus to its status item. Covered background controls are not keyboard targets
in the study. Native focus, accessibility labels, and window behavior still
need inspection on macOS after an authorized implementation.

### Review disposition and design checks

The PM critique reviewed PRD v1.0, SHA-256
`e002df06d5534425c9a13f9ff0e866f95d29c2fe8f367482e07309c0ef3ee18d`.
Its findings remain traceable; this design is not an independent re-review.

| Finding | Proposed treatment | Remaining work |
| --- | --- | --- |
| F-01 / P1: Preview conflates audition and model selection | Separate Voice Preview/Use from Models Use & Preview; PRD FR-4 and AC-13 specify both. | Review the wording and verify actual preferences/playback after native resume. |
| F-02 / P1: Shortcut recovery lacks discovery | Static menu-bar warning, help text, setup fallback, and closed-menu starting condition in AC-07. | Validate native behavior and human discovery; no discoverability claim yet. |
| F-03 / P1: Asset acceptance stops before successful recovery | Failure → explicit Retry → checking → ready → successful preview/read in AC-14. | Real transport failure, incomplete assets, and successful recovery remain unrun. |
| F-04 / P2: M4 has no repeatable usability protocol | The [prototype plan](DESIGN-SPRINT-PROTOTYPE-PLAN.md#repeatable-task-protocol) proposes fixed S1 conditions, first-exposure recruitment, tasks, assistance/timeout rules, and a separate native M4 transfer. | Review and freeze the protocol before use. Target, roster, participants, and trial remain unconfirmed; simulated audio cannot satisfy native M4. |
| F-05 / P2: Stale-ready transition is missing | AC-15 adds both permission and asset changes before action; study shows the asset case. | Verify real runtime guards; a simulated transition is not proof. |

HTML checks on 2026-10-22: 23 interaction assertions and 8 layout/focus assertions
passed; all 12 fixture layouts had no horizontal control overflow. Inspected
Voice in light/dark appearance, failed download, the shortcut menu, and a narrow
360 px review pane. Settings content measured 600 × 680 CSS px; setup measured
560 × 460. The narrow pane scrolls the desktop study horizontally.
The later candidate review found Models-preview prerequisite bypass and language
reset defects in the study. The corrected study checks the saved configuration
and stale assets, retains per-model languages, and focuses the missing-voice
recovery control. Added checks cover both reproductions, alternative audition,
model switching, incompatible language, and Models' independent fixed sample;
the affected Models layouts were inspected again.
The shared browser snapshot timed out twice; the HTML preview renderer supplied
the inspected images and DOM checks. No native build, launch, audio, permission
change, asset download, or user study was performed for this proposal.

## Typography

System text, body-size explanations (13 pt default on macOS), readable 14 pt
preview text, semantic headings. Long help/error text wraps; no caption-sized
instructions. Use monospaced digits for changing speed/progress, not prose.

## Tokens

Native adaptive foregrounds and form surfaces in light/dark appearance. Primary
text for instructions; secondary text only for supporting information. Color
never carries state alone. Spacing: 4/8/16/24/32. A 600 pt settings window gives
forms room without stretching prose; scroll overflow instead of shrinking text.

## Components

| Component | Decision | Status | Owner / priority |
|---|---|---|---|
| Voice form | Voice first tab; model explanation, language filter, named voices | Implemented | TASK / P1 |
| Preview | Visible language-matched text and a single preview/stop action | Implemented | TASK / P1 |
| Models | Explain benefit and download size; hide repository/license under details | Implemented | TASK / P2 |
| Permission/setup | Distinguish access from shortcut readiness; direct next steps | Implemented | TASK / P1 |
| HUD | Readable status, actual session rate, labelled stop/dismiss | Implemented | TASK / P2 |

## UX Audit Findings

| Issue | Heuristic | Severity (0-4) | Fix | Status | Owner / priority |
|---|---|---|---|---|---|
| V1: Raw voice IDs, ungrouped multilingual list, English-only sample | Recognition; match to real world | 3 | Named voices, language filter, matching samples | Implemented | TASK / P1 |
| V2: Speed always uses post-synthesis stretching although Kokoro exposes native duration control | Match to user intent | 3 | Native Kokoro rate; no double speed application | Implemented | TASK / P1 |
| V3: Preview skips all availability checks and may fetch a model | Norman execution gulf; user control | 3 | Separate model-only preview gate and explicit download action | Implemented | TASK / P1 |
| V4: 480 pt fixed window and caption explanations | Aesthetic clarity; recognition | 3 | 600 pt window, body text, wrapping and scrolling | Implemented | TASK / P1 |
| V5: Settings may change during playback; HUD displays next setting, not active rate | Norman evaluation gulf; visibility | 2 | Freeze utterance configuration and show its rate; explain next-read changes | Implemented | TASK / P1 |
| V6: Selection preview toggle has no consumer; reset onboarding does not show setup | Consistency; feedback | 2 | Remove dead toggle; make Show Setup open the window | Implemented | TASK / P2 |
| V7: Silent model-removal errors and no recovery | Error recovery | 2 | Move assets to Trash, explain redownload/restore, show failure | Implemented | TASK / P2 |
| V8: HUD icons have no explicit accessibility label; errors can become very long menu titles | Recognition; error recovery | 2 | Label controls, concise menu status, full detail in Voice | Implemented | TASK / P2 |
| V9: Onboarding overstates offline readiness; report copy obscures user-entered content | Match to real world | 2 | Mention first language preview asset fetch; state report contents clearly | Implemented | TASK / P2 |
| V10: Native walkthrough placed Preview below the first view; character field repeated its label | Visibility; aesthetic clarity | 3 | Remove redundant intro, group pace/preview controls, hide nested field label | Implemented; native check passed | TASK / P1 |
| V11: Setup link promised Voice but reopened the prior General tab | Consistency | 2 | Say Open Settings; explicitly initialize Voice tab selection | Implemented; native check passed | TASK / P2 |
| V12: Empty preview disables its button but still says Ready | Norman evaluation gulf; feedback | 2 | Explain that a passage or the sample is needed | Implemented | TASK / P1 |
| V13: Model summary counts US and UK English as two languages | Match to real world | 1 | Describe eight languages with distinct English accents in the picker | Implemented | TASK / P2 |
| V14: Speed-range labels render small; selection limit looks like a static value | Legibility; signifiers | 2 | Body-size range labels and a bordered number field | Implemented | TASK / P1 |
| V15: Floating panel clips Preparing speech to Prep even though AX exposes the full text | Visibility; legibility | 3 | Reserve room for each busy status and the full rate value | Implemented | TASK / P1 |

Trunk test (source assessment): Settings identifies the app and tabs, but starts
on General instead of the listening decision. Models leads with repository IDs
rather than purpose. Voice offers actions but hides what the sample will say.
No app-wide search is needed for this bounded utility; the voice list needs a
language filter. No customer severity-4 failure is established.

## Microinteraction Inventory

| Interaction | Trigger/Rules/Feedback/Loops | Fix | Status | Owner / priority |
|---|---|---|---|---|
| Preview | Click; require assets and nonempty sample; preparing/speaking/stop; repeat | Show actual sample and live state in one place | Implemented | TASK / P1 |
| Voice/language | Explicit choice; existing downloaded voices only; selected name; persistent voice | Language follows voice without resetting valid choice on appear | Implemented | TASK / P1 |
| Speed | Slider/preset; 0.5–2×; visible value; applies to next read | Native Kokoro timing, reset to 1×, actual HUD rate | Implemented | TASK / P1 |
| Download | Explicit click; single flight; percent/cancel/retry; ready | Keep ready state synced when download finishes | Implemented | TASK / P1 |
| Remove model | Click; unavailable while speaking; Trash or error; restore/redownload | Reversible removal and visible error | Implemented | TASK / P2 |
| Setup | Show Setup; singleton window; visible steps; repeatable | Replace preference-only reset | Implemented | TASK / P2 |

State coverage to verify: missing assets, downloading, ready, preparing,
speaking, stopping, failure, empty sample, and disabled controls. Browser
INP/LCP/CLS do not apply to this native scope. Native preview and stop are
verified separately; no speed benchmark is inferred from UI feedback.

## Native verification — 2026-09-07

Settings was inspected at its default 600-point width in Dark appearance. Voice
choice, pace, editable sample and Preview fit together without scrolling. General
and Models use normal vertical scrolling for longer content; expanded model and
report details remain readable. The number field has a visible editing border.
The HUD reserves 160 points for status and 44 for rate so its preparation message
stays legible. Stop and Hide were exercised on real Kokoro playback.

| Surface / check | Result | Owner / priority |
|---|---|---|
| Voice picker, English/Spanish sample change, empty sample | Native pass; empty state now explains the disabled action | TASK / P1 |
| Real preview, normal completion, Stop, next-read speed message | Native pass plus coordinator tests | TASK / P1 |
| General and Show Setup; selection limit 12,000 then restored to 20,000 | Native pass | TASK / P1 |
| Model details and Report disclosure | Native visual pass; no removal, report transmission or provider operation performed | TASK / P2 |
| Permissions | Truthful Not granted / Needs Accessibility access state; Recheck exercised | TASK / P1 |
| HUD preparation label, Stop, Hide, next-read reappearance | Native pass after repairing reproduced clipping | TASK / P1 |
| Light appearance and broader accessibility settings | Deferred: current native capture remained Dark; no global settings changed | Product owner / P2 |
| Fresh-download failure/retry and Trash restoration | Implementation/source checked; full native lifecycle deferred | Product owner / P2 |

Browser performance metrics are not applicable. Native state logs record
preparation and playback transitions; no perceptual latency improvement or
network-disabled operation is inferred from them.
