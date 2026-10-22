# MLXRead — Foundation Sprint approach options

Status: draft candidate set for James; no approach selected or approved.
Prepared: 2026-10-22. Source: `main` at
`12b2abdd234bc64e53f54aa0fd15f954a35a2194`, with the existing uncommitted
AGENTS.md context adoption preserved.

## Working frame

**Person and job:** A Mac user whose reading becomes tiring or interrupts
other work wants to hear the selected passage comfortably without losing their
place. [CUSTOMER.md](CUSTOMER.md) identifies daily listening as the priority.
This is product-source inference, not an interview or retention finding.

**Target:** The existing native macOS menu-bar application. The website's
first-read delivery plan is a separate scope. The current screens serve this
same listening job; the options below change which part organizes the experience.

**Two working differentiators**, recovered from
[POSITIONING.md](POSITIONING.md) and [PRODUCT.md](PRODUCT.md):

1. **Private local listening.** Selected text is synthesized on the Mac and
   is not transmitted, persisted, or logged.
2. **Listening in place.** Hear a passage from its original application and
   return attention to it, without copying it into a separate reader.

These are product commitments, not proven competitive advantages. Comfortable
voice and pace are the desired outcome; listener preference remains unmeasured.
There is no signed Foundation Sprint Basics or Differentiation bundle in the
reviewed repository documents. This working frame needs James's confirmation
before formal Magic Lenses evaluation; no Day 1 sign-off is being inferred.

**Two decision principles:** Preserve local, ephemeral reading content and
clipboard restoration; make readiness and control truthful, including explicit
downloads, accurate permission state, and a reliable Stop action. Offline
reading follows model and pronunciation-asset preparation; the app is not
network-free in every operation. [Privacy](privacy.md) remains the owner.

## Approach A — Ready, then disappear

**Label:** A / Shortcut

**What it is:** Prepare one usable voice, then let the reader listen and stop
with Option–Escape while staying in their document.

**Why it's a good idea:** The daily job in CUSTOMER.md is listening without
losing one's place. A clear default and a short readiness path could reduce
decisions before that habit forms. MLXRead already has selection capture,
Kokoro as its default engine, voice availability checks, and a menu-bar status
indicator. This approach concentrates those capabilities around the first
successful selection read. Whether fewer choices improve activation is untested.

**The strategic choice:** Optimize the whole experience for getting ready once
and doing almost nothing afterward. Other engines and voice comparison remain
available in Settings, secondary to a working default.

**Flow:** Setup → explicitly download the default model if needed → preview a
usable voice for the intended language → grant Accessibility and check shortcut
readiness → return to the original app, select text, press Option–Escape →
listen → press it again to stop, or let reading finish. Preview itself does not
need Accessibility. Existing selections and preferences remain respected.

**Sketch:**

```text
SETUP                            ORIGINAL APPLICATION
Prepare a voice                  [selected passage stays here]
[Download] → [Preview]            Option–Escape → speech
Allow selection access           Menu bar: Preparing / Speaking
[Open permission settings]       Option–Escape → stopped
Return to your text
```

**How it serves the differentiators:**

- Private local listening: use existing local model and capture paths; the
  setup sample never comes from a captured selection.
- Listening in place: once ready, no reading window or confirmation interrupts
  the ordinary select-and-listen loop.

**Change from current source:** Setup currently finishes automatically when
Accessibility is granted; model and voice preparation live in Settings. This
option would make setup's completion reflect the whole readiness path and make
the default route more prominent. It does not claim that the current app cannot
complete a first read.

**Top trade-off:** The first voice may not suit the listener. Quiet operation
also gives less visible reassurance during model loading. Readiness failures
must retain an explicit route to Permissions, Models, or Voice settings.

**Question to test:** Can a new reader reach a real selection read and explain
how to stop without exploring engine choices or mistaking permission for full
readiness?

## Approach B — Choose the voice first

**Label:** B / Audition

**What it is:** Find a voice and pace you want to hear, keep that choice, then
use it wherever you select text on your Mac.

**Why it's a good idea:** PRODUCT.md's remaining product question is whether
the listener prefers the sound. Local tests established preview and timing
behavior, not preference. VoiceSettingsView already supports language-aware
samples, independent Preview and Use actions, and speed control. This approach
makes hearing and choosing the value moment, using capabilities already present
instead of claiming that one voice is best for everyone.

**The strategic choice:** Optimize first use and occasional return visits for
audible preference. The everyday shortcut is the payoff after that choice.
The cost of comparing voices is accepted as part of the product's value.

**Flow:** Open Voice → explicitly acquire a suitable existing model if needed →
hear a visible sample at the intended language and pace → preview another
available voice → choose Use → complete selection permission if needed → return
to the original passage and press Option–Escape. A short default path remains
available to someone who does not want to compare.

**Sketch:**

```text
VOICE SETTINGS
Language: English     Pace: 1×
Sample passage       [Edit sample]
Voice one            [Preview] [Use]
Voice two            [Preview] [Use]
Selected voice: …
Then: return to your text → Option–Escape
```

**How it serves the differentiators:**

- Private local listening: audition uses local synthesis and an in-memory
  sample; captured passages are never inserted into the preview field.
- Listening in place: the chosen settings carry into the existing selection
  shortcut; daily use does not return to a voice workspace.

**Change from current source:** Settings already opens on Voice, and Preview
already differs from Use. The bet is a focused first-use comparison path with
language, pace, and a manageable starting selection visible together, while
retaining the full catalog. It is not simply adding another voice picker.

**Top trade-off:** More audition and download time before the first real read;
too much choice can turn setup into browsing. Preview does not silently acquire
a missing base model or replace the saved reading voice. An unavailable chosen
voice must lead to an explicit replacement or model recovery.

**Question to test:** Does the listener find a setting they want to keep, and
does that preference justify the additional setup effort?

## Approach C — Keep controls within reach

**Label:** C / Visible control

**What it is:** Read the current selection with a small, familiar control panel
that shows what is happening and keeps Stop within reach.

**Why it's a good idea:** CUSTOMER.md identifies control and understandable
recovery as part of the job. MLXRead already has menu actions and a nonactivating
playback panel that shows state, active speed, Stop, and Hide. This approach
builds confidence through visible behavior while keeping the original app in
focus. Whether readers prefer that reassurance over a quiet menu-bar utility
is an open product question.

**The strategic choice:** Organize first use, daily playback, and recovery around
a visible listening controller. The shortcut stays available, but remembering
it is not the only way to find a control or understand a transition.

**Flow:** Complete model, voice, and permission setup → select in the original
app → choose Read Selection from the menu or press Option–Escape → see Preparing
then Speaking beside the document → Stop, Hide while speech continues, or let
reading finish. After Stop, another read captures the current selection anew.

**Sketch:**

```text
ORIGINAL APPLICATION — keeps keyboard focus
[selected passage stays in this application]

                 MLXRead
                 Speaking · 1×   [Stop] [Hide]
                 No captured text in this panel
```

**How it serves the differentiators:**

- Private local listening: the panel shows coordinator state and settings,
  never captured text, reading history, or an uploaded passage.
- Listening in place: retain the existing nonactivating panel and source-app
  selection; the controller accompanies a read without becoming its document.

**Change from current source:** The playback panel is currently optional and
off by default. This option would introduce it during setup and make it the
normal visible control surface for new users who choose this experience.
Existing preferences must be preserved. Recovery remains in the relevant
existing Settings tab rather than a new diagnostic workspace.

**Top trade-off:** Persistent controls occupy attention and screen space. The
panel must remain optional, hide without stopping speech, and avoid stealing
focus. Pause, resume, seeking, a transcript, and duration estimates are not
promised by the current domain layer and are excluded from this option.

**Question to test:** Does visible state and Stop help the reader feel in
control without covering the passage or repeatedly drawing attention away?

## Approach set summary

| Label | Approach | Primary capture / interaction | Primary value | Top trade-off |
| --- | --- | --- | --- | --- |
| A | Ready, then disappear | Prepare a default; select text and use the shortcut | Few decisions during ordinary listening | Default voice may not fit; less visible reassurance |
| B | Choose the voice first | Audition locally, select a voice, then use the shortcut | Deliberate comfort and voice preference | More time and choice before the first real read |
| C | Keep controls within reach | Select text; menu or shortcut starts visible playback controls | Understandable state and reachable Stop | More visual presence beside the original passage |

All three capture from the original application. Repeat use means selecting
another passage, not recalling a saved text library. These are alternative
organizing approaches, not three features to build together. They intentionally
share the existing synthesis and capture foundation. Their distinguishing bets
are minimum decision effort, preference before habit, and visible control.
No winner, score, customer validation, or formal team vote is asserted.

## App pathway: layout and state owners

These are proposed composition priorities, not implemented screens. Preserve
native system typography, controls, keyboard focus, and the existing 600 × 680
Settings window unless a selected design demonstrates a specific need to change
it. All options retain explicit language and model compatibility.

| Region or state | Existing source owner | Role in the options |
| --- | --- | --- |
| Setup and completion | [OnboardingWindow.swift](../MLXRead/UI/OnboardingWindow.swift) | A: complete readiness sequence; B: route into audition; C: introduce visible controls |
| Voice, language, sample, pace | [VoiceSettingsView.swift](../MLXRead/UI/VoiceSettingsView.swift), [SettingsView.swift](../MLXRead/UI/SettingsView.swift) | B's primary decision surface; secondary customization for A and C |
| Model download and recovery | [ModelSettingsView.swift](../MLXRead/UI/ModelSettingsView.swift), [ModelStore.swift](../MLXRead/Models/ModelStore.swift) | Explicit download, progress, cancel, retry, and readiness for every option |
| Permission and shortcut readiness | [PermissionView.swift](../MLXRead/UI/PermissionView.swift), [AppState.swift](../MLXRead/App/AppState.swift) | Selection requires permission; a built-in voice sample does not |
| Capture and playback state | [SpeechCoordinator.swift](../MLXRead/Speech/SpeechCoordinator.swift), [SelectedTextService.swift](../MLXRead/Accessibility/SelectedTextService.swift) | Shared source of truth; no duplicated UI-derived speech state |
| Daily actions and status | [MenuBarContent.swift](../MLXRead/UI/MenuBarContent.swift), [PlaybackHUD.swift](../MLXRead/UI/PlaybackHUD.swift) | A emphasizes the menu bar; C emphasizes the existing nonactivating panel |

Common exits: missing model → explicit download/retry; missing or incompatible
voice → Voice; selection access unavailable → Permissions; empty or inaccessible
selection → return to the source app and select accessible text; synthesis
failure → readable error and user-initiated retry. Download cancellation and
closing setup leave the app honestly unready. Stop and natural completion return
to the ready or relevant gated state. Changed pace applies to the next reading.

Source inspection supports the owner map. [EXPERIMENTS.md](EXPERIMENTS.md) and
[testing.md](testing.md) contain dated local evidence, not current native proof
or customer preference. This planning task did not launch the app, build it,
change runtime settings, publish, or resume the existing app/release holds.

## Decider checkpoint

The requested output is this candidate set. Formal evaluation starts only after
the framing and set are confirmed; implementation is a separate request.

- [ ] James confirms the native daily-listening job and the two recovered differentiators.
- [ ] James confirms A, B, and C as the three approaches advancing to Magic Lenses.
- [ ] James confirms all three honor the two decision principles and serve both differentiators.
- [ ] James confirms the organizing approaches are sufficiently distinct to compare.
- [ ] James acknowledges that Magic Lenses will narrow to one top bet and one backup, without preselecting either here.

Signed: pending — no name or date has been entered on the Decider's behalf.
