---
artifact: design-sprint-prototype-plan
version: "1.0"
created: 2026-10-22
status: draft
---

# MLXRead: prototype plan for finding a working listening route

Prepared for James. This is the requested planning artifact; it does not build a
participant prototype, recruit or contact people, schedule sessions, or resume
the native app.

**Input status:** The [map-and-target bundle](DESIGN-SPRINT-MAP-AND-TARGET.md)
recommends T2, but James has not selected it. There is no signed Wednesday
storyboard. P1–P7 below are a proposed bridge from the existing
[screen design](DESIGN.md#readiness-and-recovery-screen-proposal--2026-10-22),
not a claimed sketch vote or approved storyboard. If the target changes, revise
the panels, Tasks act, fixtures, and outcome rules before building.

Source checkpoint: 722c778b6348dd2cbbdc7c7792d0fe94a6bafb1d.
No real participant outcomes or trial-run results exist for this plan.

## Prototype Role Plan

Named delivery staff are unconfirmed. These are proposed staffing slots and
allocations, not assignments to people who have accepted work. James retains the
Decider role. The current assistant prepared the plan, not a staffed sprint.

| Canonical role | Proposed owner slot | Allocation on build day | Concrete output |
| --- | --- | --- | --- |
| Maker | D: design implementer; unfilled | 09:30–12:00, 2.5 h | Participant desktop frame and P1–P7 surfaces, reusing existing components |
| Stitcher | D: same design implementer | 13:00–15:00, 2 h | Two valid recovery branches, deterministic responses, reset, keyboard and audio wiring |
| Writer | P: product writer; unfilled | 09:30–11:00, 1.5 h | Participant-visible copy and fixed task wording, reviewed for hints |
| Asset Collector | E: native/product technical reviewer; unfilled | 09:30–10:30, 1 h | Public passage, matching local audio fixture, icon assets and source-fact check |
| Interviewer | R: researcher; unfilled and dedicated | 10:30–12:00 script; 14:30–15:00 rehearsal; 16:00–17:00 trial, 3 h | Final script, scoring sheet, independent trial observations and readiness disposition |

D holds Maker and Stitcher; the other slots each hold one canonical role.
No one holds three roles. Keep R separate from the person operating any diagnostic
controls. If fewer people are available, explicitly revise capacity and dates;
do not silently assign the interviewer the whole build.

P is the proposed facilitator/recruiting coordinator as well; James confirms the
named person and any outreach scope separately. All times are illustrative local
America/Chicago time on an unbooked build day, not calendar appointments.

## Prototype Brief

**What to build:** One participant version of the existing HTML study, covering
T2 and P1–P7. Use a full desktop-sized frame on a Mac, with the source passage in
place, the MLXRead menu initially closed, and the shortcut unavailable. A reader
may use the menu directly or repair the shortcut before explicitly reading.

**Medium:** Local self-contained HTML with a prepared public audio clip. This is
a proposal to reuse the existing stack, not a new application. It can test choices
and comprehension inside a simulated desktop. It cannot establish the visibility
of a real macOS status item, event-tap recovery, selection capture, speech quality,
clipboard restoration, or PRD M4's native successful-read endpoint.

**Fidelity bar:** At a 1280 × 800 CSS px viewport, 100% browser zoom, and Light
appearance, every in-scope control responds, copy is final enough to interpret, and both routes
reach the matching audio fixture with a working Stop action. The prototype must
not coach through labels outside the product. A full desktop frame preserves
relative cue placement, but remains a simulation; do not report its discovery rate
as native discoverability. Stop polishing once these conditions and the trial
gates pass.

### Proposed storyboard

| Panel | Scene, action, and response |
| --- | --- |
| P1 / M1–M4 | Public passage selected; Settings/menu closed; static warning. Explore after the supplied silent-shortcut attempt. No popup or speech. |
| P2 / M4 | Reader opens the status item by pointer or keyboard; the menu exposes state and actions without removing the passage. |
| P3 / M5–M6 | Shortcut unavailable. Read Selection and Retry Shortcut are eligible; neither changes model, voice, or permission. |
| P4 / M7, optional branch | Retry shows Starting → Active after a fixed delay. Reading still requires an explicit request and remains available while retry starts. |
| P5 / M8 | Explicit reading request → Preparing → Speaking. Play the matching clip; keep the source passage visible. |
| P6 / M9 | In Task B, the reader reaches menu Stop and silences the clip. The optional playback panel stays off. |
| P7 / M9 | Return to the passage. The direct-menu route may leave the shortcut unavailable; the repaired route shows Active. |

P4 is optional: P3 may proceed directly to P5. The screen study's Voice, Models,
setup, and permission cases remain useful separate design evidence; do not add
them to this participant session merely because they already exist.

**Time bar:** Copy and assets precede stitching; feature work stops at 15:00.
Reserve 15:00–16:00 for defects and 16:00–17:00 for the independent trial.

**Outside the build:** Native services/TTS and model downloads; accounts,
reading history, telemetry, or a backend; alternative A/B/C experiences or a
two-prototype competition; full settings coverage; release packaging. The task
adds no OS notification or automatic replay. Detailed participant-mode changes
and the public fixture are in the build notes below.

## Participant Prototype Build Notes

### Changes required before a participant version exists

The current [HTML study](design/readiness-recovery.html) is an expert review
artifact. Its passing interaction checks do not make it ready for unprompted use.

- Remove the review-case picker, environment-step button, review notes, boundary
  explanations, and other diagnostic controls from the participant view and
  accessibility tree.
- Remove the source document's menu-bar explanation and its invented Open MLXRead
  Settings button. Replace the product-explaining passage with the neutral fixture
  below. Retain genuine proposed product help such as the status-item tooltip.
- Use a full desktop frame, not a phone layout or a scaled thumbnail of the Mac.
  Freeze size, browser zoom, appearance, cue location, and input method before sessions.
- Support the two valid routes and their returns. Show Starting then Active after
  the same fixed delay for every participant; manual hidden coaching must not decide
  when a route succeeds. Keep all timing explicitly simulated.
- Add the matching local audio fixture with Stop. Verify advertised keyboard
  actions within the mock on the study Mac; an external OS handler must not trigger
  an unrelated app. Do not change the user's Mac settings or stop another runtime
  to make the study work.
- Provide an interviewer-only reset to the complete S1 fixture. Reset the passage,
  model/voice, permissions, shortcut, playback, menus, and focus between sessions.

**Asset fixture:** Use the following original public test paragraph for both the
visible selection and the audio. It contains no task instructions or private text.

> On Saturday morning, the community garden opened for the season. Volunteers
> carried seedlings along the gravel path and placed them beside the empty beds.
> Near the gate, a small table held a map showing where each plant would grow.
> One group repaired the wooden signs while another filled watering cans from
> the rain barrel. By midday, the first rows were planted. Everyone took a break
> under the old apple tree, compared notes about the weather, and made a short
> list of jobs for the following weekend. A few spare seedlings remained for
> neighbors who would arrive later in the afternoon.

E prepares a local recording of this exact paragraph lasting at least 45 seconds
so Task B can exercise Stop; do not loop or substitute unrelated words. If no
suitable clip is ready, the trial fails the audio gate. A click-only session can
explore navigation but must not be scored as the planned listening task.

P supplies copy and E supplies assets before D stitches the flow. Rework after
a failed gate requires another trial of the changed path. Voice preference is
outside this study regardless of the recording chosen.

## Interview Script (Five-Act)

**Format proposal:** Moderated in person on one qualified study Mac, 60 minutes
per person: 55 minutes of script plus 5 minutes of buffer. Remote delivery would
require a revised input/observation setup and another trial. Notes are manual,
using participant IDs and the supplied passage; no recording or transcription
service is included. Confirm consent to observe and take notes before continuing.

### Act 1: Welcome — 5 minutes

“Thanks for joining. We’re testing an interface for listening to text on a Mac.
We’re interested in what you would do, including anything that seems confusing.
We’ll use prepared passages, and I’d like to take notes about what happens. You
can skip a question or stop at any point. Is that okay?”

Confirm the session length and observation arrangement. Explain any agreed
compensation accurately; do not promise an amount, method, or payment that has
not been arranged.

### Act 2: Context — 8 minutes

1. Tell me about the kinds of reading you do on your Mac during a normal week.
2. When do you choose to listen to text instead of reading it silently?
3. Think of the last time that listening did not work as expected. What happened next?
4. Which Mac controls or shortcuts do you use for listening now?

Ask for examples in conversation, not demonstrations from private documents.
Do not mention the MLXRead menu-bar warning, its status wording, or the recovery
route. Record prior menu-bar experience; do not teach it here.

### Act 3: Intro — 5 minutes

“This is an interactive model of MLXRead, not the installed app. Some areas
outside today’s task are not implemented. We’ll use a prepared document and
prepared speech rather than your own text. Please act as you normally would
and tell me what you’re trying to do. I’ll mostly watch.”

Show the neutral source document only. Explain prototype mechanics necessary to
operate the screen without naming a recovery control. Do not run through the
task or show the correct menu in advance.

### Act 4: Tasks — 27 minutes

**Task A — find a way to continue listening, Q1/Q2:**

“You have already set up MLXRead and listened with it earlier. This passage is
selected in your document. Your usual shortcut has just produced no audio.
Show me what you would do to continue listening.”

Begin at S1. Allow up to five minutes without directional help. The starting
context supplies the unsuccessful attempt; do not require an actual global
keystroke to create it. Either valid route may succeed.

After success, timeout, or abandonment, record the independent result before
probing. If audio is playing, proceed immediately to Task B; ask the retrospective
questions after the Stop attempt. If they did not finish, a later assisted
exploration is diagnostic only.

**Task B — retain control, Q5:**

Within five seconds of the Task A audio endpoint, while the fixed passage is
speaking: “You’ve heard enough for now. Show me how you would stop and return
to the passage.”

If Task A did not start audio, or the clip has already finished, the interviewer
may start the clip after recording Task A's result and explicitly mark Task B
as an assisted start. Give up to
20 seconds to stop before recording a control difficulty; end the sound if the
participant requests it. This is a proposed observation window, not a latency SLA.

After both initial attempts, ask “What did you think was happening?” and “What
made you choose that action?” Use the rest of the act for retrospective probes
and, if needed, a reset showing the other valid route. Such repeats are learned/
assisted observations and never replace the first-exposure result.

**Permitted neutral probes:** “What are you thinking?”; “What did you expect?”
During Task A, use “What are you thinking?” at most once after 30 seconds of
silence. If asked what to click, reply once, “Try what you would normally do.”
The clock continues. Naming, pointing at, or recommending a control is assistance.

### Act 5: Debrief — 10 minutes

1. What seemed to be wrong when you first saw the screen?
2. Which actions did you believe were still available?
3. What did you expect to happen to your voice, settings, and selected passage?
4. How would you handle this situation in your actual reading workflow?
5. What would you change first, and why?

Do not ask whether the route was “easy” or whether the participant “liked the
warning.” Pricing is outside this task. Thank the participant and explain only
the follow-up that has actually been agreed.

### Repeatable task protocol

**Protocol identity:** S1, draft v1.0. Freeze the document revision, prototype
artifact hash, audio hash, fixture, task wording, scoring rules, and session setup
before the first scored participant. Record later changes as a new version;
do not pool results across versions.

**Participant profile:** Five adults who use a Mac at least four days per week,
read sustained text at least three days per week, and have tried listening to
text within the last three months. Exclude people who built/reviewed MLXRead or
have seen this prototype. Record whether anyone is an actual MLXRead user.
These are proposed eligibility criteria, not a claim that this sample represents
all readers. Do not require health information.

Aim for two people who regularly use menu-bar utilities and three who use them
occasionally; record actual experience and any deviation before interpreting
results. All five receive the same S1 task as their first exposure. Do not assign
an easier scenario to some participants and combine the counts.

**S1 starting condition:** 1280 × 800 CSS px viewport, 100% zoom, Light appearance,
initial focus in the source document; public passage selected;
Kokoro/Heart at 1×; model assets treated as ready; selection permission treated
as granted; shortcut retry-needed; idle playback; Settings, setup, and menu closed;
playback panel off. No prior error banner or tutorial is visible. The static
proposed warning and its genuine help remain. This isolates shortcut discovery.

| Measure | Observable endpoint or record | Interpretation |
| --- | --- | --- |
| P-01: Independent recovery | Within five minutes, the participant independently chooses a valid route and explicitly starts the matching prepared audio | Proposed directional target: at least 4 of 5 first-exposure sessions. This is a prototype result, not PRD M4 |
| P-02: Discovery | Time and actions until the participant opens the relevant MLXRead status/recovery surface; also record when no discovery occurs | Report separately from navigation after the blocker is displayed; no invented baseline |
| P-03: Recovery navigation | Control activations from the first displayed blocker to the chosen reading/recovery control | Compare with the proposed two-activation M2 design target, labelled as prototype evidence only |
| P-04: Interpretation | Participant's post-task explanation of what was unavailable and what still worked | Record their words and contradictions; do not infer comprehension from one successful click |
| P-05: Control | Whether Task B stops the audio within its 20-second observation window and leaves the passage available | Report independent versus assisted start separately; no native Stop claim |

A click, Enter, or Space that activates a control counts once. Navigation keys
and elapsed waiting are logged but are not M2-style activations. Route A is direct
menu reading; Route B is shortcut recovery followed by an explicit reading action.
Both count. No automatic speech or forced voice/permission change counts as success.

**Timeout and abandonment:** Task A ends at five minutes, when the participant
chooses to stop, or when help reveals a route. Record the outcome as independent
success, timeout, abandonment, or assisted. Repeated random activation that
happens to play audio can satisfy the action endpoint but does not establish P-04
understanding; report both. A prototype malfunction is a technical-invalid run,
not participant failure. Keep it in the ledger with its reason, repair and retrial
before more sessions, and use the buffer for a new first-exposure participant.

**Observation sheet fields:** Participant ID; eligibility/experience; protocol,
prototype and audio hashes; screen size/zoom/appearance; task start time;
first status-discovery time; action sequence; direct/repair route; first audio
time; independent outcome; assistance/time; P-04 explanation; Stop result;
technical fault/deviation. Use public fixture IDs rather than private passages.

**Decision rule:** With five valid first-exposure sessions, four or five independent
Task A successes support advancing this route to native evaluation. Revise and
retest if three or fewer succeed, if at least two participants explain the displayed
shortcut failure as all listening being unavailable, or if at least two cannot
find Stop within Task B's window. An activated Stop that fails, automatic audio,
or an unrequested voice/permission change fails the prototype gate regardless
of participant counts; correct it and retrial. Five qualitative sessions do not
establish population rates, retention, or causal lift.

**Native M4 transfer:** To evaluate the PRD's actual successful-read criterion,
reuse this fixed S1 task and eligibility/assistance rules on an explicitly resumed,
qualified native candidate with real cached assets and real public-text capture.
The endpoint is hearing that selected passage through the app, not the prepared
clip. Use five first-exposure participants for that native evaluation; prototype
participants are already exposed and must not be reported as unprimed. If comparing
a human baseline with a candidate, use separate equivalently recruited first-exposure
cohorts and the same fixture/script. Do not compare a participant's first attempt
with their coached or repeated attempt. Without a human baseline, report the
candidate counts and leave improvement unknown. Native sessions and any additional
cohort are future scope, not booked by this plan.

This supplies a proposed resolution to F-04's protocol gap. Review, freeze, and
actual observation remain outstanding.

## Trial-Run Checklist

Run with a non-participant teammate who has not seen the intended route, playing
the target profile. Their result is a rehearsal, not one of the five customer
outcomes. R records yes/no and evidence for each item; all are currently **not run**.

- [ ] T-01: James's target and P1–P7 scope are recorded; each canonical role has a named owner who accepted the allocation.
- [ ] T-02: Every in-scope panel and both valid routes are reachable without dead links.
- [ ] T-03: Reviewer labels, case selectors, explanatory source hints, and fake Settings shortcuts are absent from the participant view and accessibility tree.
- [ ] T-04: Desktop size, zoom, appearance, input methods, cue position, and the complete S1 reset are recorded and repeatable.
- [ ] T-05: Advertised pointer/keyboard actions and visible focus work in the mock; no external shortcut handler triggers a real app.
- [ ] T-06: Only an explicit valid request starts the correct local clip; Stop silences it; the passage and saved choices remain.
- [ ] T-07: Retry, Starting, Active, and direct-menu reading behave consistently; no hidden moderator action determines success.
- [ ] T-08: All copy and assets are final for this test; the passage/audio match and contain no private customer data.
- [ ] T-09: The unprimed rehearsal produces observable choices; the Tasks wording gives no menu or repair hint.
- [ ] T-10: The 55-minute script plus buffer fits one hour; timeout, assistance, malfunction, and independent-result recording are understood.
- [ ] T-11: Manual-note consent, silent observer arrangement, and intervention for participant discomfort are confirmed. No recording is enabled.
- [ ] T-12: Five primary participants and one buffer have actual confirmations, a named coordinator, and usable session logistics.
- [ ] T-13: A frozen artifact/protocol version and outcome sheet exist; the native M4 boundary is stated in the result template.

If a gate fails, repair only the affected scope and rerun the relevant trial checks.
An unchecked box is not a pass. Do not start scored sessions while a required gate
is open. A shorter diagnostic walkthrough must be labelled separately.

## Participant Confirmation Tracker

**Current state:** No participants identified, contacted, or confirmed. P01–P06
are reserved identifiers, not six people. Session date and location are unset;
times below are a proposed local America/Chicago timetable.

| Slot | Reserved ID | Proposed time | Current status | Next coordinator action, once authorized |
| --- | --- | --- | --- | --- |
| Primary 1 | P01 | 09:00–10:00 | Not recruited | Check eligibility, availability, and consent |
| Primary 2 | P02 | 10:15–11:15 | Not recruited | Check eligibility, availability, and consent |
| Primary 3 | P03 | 11:30–12:30 | Not recruited | Check eligibility, availability, and consent |
| Primary 4 | P04 | 13:30–14:30 | Not recruited | Check eligibility, availability, and consent |
| Primary 5 | P05 | 14:45–15:45 | Not recruited | Check eligibility, availability, and consent |
| Buffer | P06 | 16:00–17:00 | Not recruited | Confirm willingness to cover a cancellation or technical-invalid slot |

**Recruiting proposal:** A named coordinator screens volunteers from James's
existing professional/community contacts who meet the profile; include people
outside the delivery team and close product circle. No contacts or invitations
are supplied here. Recruitment channel, incentive, budget, date, and venue need
their owning decision; no purchase or outreach was performed.

**Confirmation cadence:** Once sessions exist, reconfirm the day before and check
again on the build-day morning. Record actual replies, not just sent reminders.
Activate the buffer only after contacting that person through an authorized
channel. Keep cancellation, nonresponse, and technical invalidation distinct.

**Cohort rule:** Aim for five completed independent sessions. Four usable sessions
require an explicit reduced-evidence decision; report successes out of four and
the missing slot separately, without claiming the five-person target. Fewer than four
triggers a Decider choice to postpone or authorize a differently scoped diagnostic
test. No scheduling or automatic follow-up is created by this rule.

**Current delivery risk:** High: there is no named interviewer, participant cohort,
participant-ready artifact, or passed trial. These are execution prerequisites,
not reasons to withhold the completed planning proposal.

## Decider Checkpoint

The requested prototype-plan method requires a target/storyboard and confirmation
of roles, fidelity, Tasks wording, and trial gates before the team starts its build.
This plan prepares those choices without inferring them.

- [ ] James selects T2 or a revised target and confirms the primary questions.
- [ ] James approves or revises P1–P7 as the storyboard input; no Wednesday vote is implied.
- [ ] Named D/P/E/R owners accept the five-role allocation; R remains a dedicated interviewer.
- [ ] James confirms the medium, its native-evidence limits, and the stated fidelity/time bar.
- [ ] James and the interviewer approve Task A/B, S1, eligibility, five-minute/20-second windows, assistance rules, and the proposed learning threshold before results.
- [ ] The team accepts all trial gates and the cohort reduction rule.
- [ ] A named coordinator owns dates, recruiting authority, confirmations, consent, and any incentive; the tracker reflects actual replies.
- [ ] If a full sprint is scheduled, James confirms attendance for the target/storyboard decisions and the post-interview review.

**Signed:** Pending. No role, session, budget, or native resume is confirmed.
