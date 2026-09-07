# Design System

## Design Direction

A native listening utility. Voice settings answer three questions in order:
which voice, what pace, and how does it sound? The signature moment is a clear,
repeatable preview in the chosen language. No decorative dashboard or invented
voice quality ranking. Local source findings below precede implementation.

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
