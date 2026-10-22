---
artifact: design-sprint-map-and-target
version: "1.0"
created: 2026-10-22
status: draft
---

# MLXRead: map and target for recovery without losing your place

Prepared for James, the product owner and proposed Decider. This is a source-grounded
planning bundle. No workshop, expert interview, team vote, or Decider sign-off is
being reported. The recommended target is a proposal; the prior A/B/C approaches
remain unselected.

Source checkpoint: 722c778b6348dd2cbbdc7c7792d0fe94a6bafb1d. The native application
is unchanged from the earlier source baseline. The existing native/release holds
remain separate from this planning work.

## Working brief and evidence

**Challenge:** A reader wants to hear a passage in its original Mac application.
If their usual shortcut produces no speech, can they discover a useful next action
and continue listening without unnecessary setup or a change of voice?

**Why this work now:** The readiness PRD and screen study describe recovery, but
they do not show that a reader will discover it. PM finding F-02 identifies this
gap; F-04 identifies the missing repeatable observation protocol. This is a useful
learning target before native implementation, not evidence of an urgent measured
customer incident.

**Proposed frame:** One moderated study of a single recovery moment, using a
participant version of the existing HTML study. Use a supplied public passage,
cached-model conditions, and one fixed starting state. The
[prototype plan](DESIGN-SPRINT-PROTOTYPE-PLAN.md) supplies the proposed medium,
storyboard, roles, script, and participant protocol.

No locked sprint brief or signed Wednesday storyboard was found in the repository
or supplied conversation. Dates, named delivery staff, expert sessions, and
participants are unconfirmed. This bundle supplies reviewable working inputs;
it does not declare Monday or Wednesday complete or authorize a live workshop,
prototype build, outreach, or study.

| Source | Established context | Limit |
| --- | --- | --- |
| E1: [Customer](CUSTOMER.md) and [product](PRODUCT.md) | Listening comfortably while keeping one's place is the stated job; daily use has priority. | Customer.md explicitly identifies the job as inference, not interview evidence. Its older underdelivery descriptions are not all current defects. |
| E2: [PRD](PRD-READINESS-AND-RECOVERY.md), FR-1/2/5 and AC-07 | Preview, menu reading, and shortcut operation have different prerequisites; discovery and recovery are separate questions. | Proposed requirements and source boundaries do not prove native behavior or user understanding. |
| E3: [Design record](DESIGN.md#readiness-and-recovery-screen-proposal--2026-10-22) | The proposal uses a static menu warning, text explanation, and named recovery actions. | F-02 remains a proposed disposition awaiting human and native evidence. |
| E4: [HTML study](design/readiness-recovery.html) | The reviewed artifact contains a closed-menu shortcut scenario and working simulated transitions. | Reviewer instructions, scenario labels, and a source-app Settings button reveal the route; no audio or real selection capture occurs. |
| E5: [Experiments](EXPERIMENTS.md) | Dated native checks support earlier layout, playback, and timing work. | They contain no current five-reader discovery result, preference result, or retention baseline. |
| E6: [Privacy](privacy.md) | Selected reading text stays local and ephemeral; preparation can require downloads. | A prototype cannot prove clipboard, network, or native permission guarantees. |

No current funnel measurements, participant transcripts, or measured abandonment
rates were available in these inputs. Do not assign numerical drop-off to the map.

## Long-Term Goal

By 2028, daily Mac readers can rely on private local listening as an ordinary part
of their work and recover from interruptions without losing their place.

This is a two-year aspiration, not a sprint outcome or a delivery commitment.

## Sprint Questions

1. **Q1:** Can readers discover what to do when their usual shortcut produces no speech?
2. **Q2:** Will readers recognize and use a listening action that still works while the shortcut is unavailable?
3. **Q3:** Will readers distinguish trying a voice from choosing it for future readings?
4. **Q4:** Can readers recover from an interrupted model download without losing their choices or mistaking incomplete files for readiness?
5. **Q5:** Can readers stop playback and return to the passage without confusing current playback with settings for the next reading?

Q1 and Q2 are the recommended primary questions. Q5 supplies a control check after
the primary task. Q3 and Q4 remain visible alternatives; this target will not
answer them.

## Customer or System Map

**Key player:** A regular Mac reader who wants to continue listening to selected
text in the application where they found it. The study recruits a proxy for a
returning MLXRead user; it must disclose that limit.

**Actors:** Reader; original application; MLXRead; macOS permission/shortcut
services; local model assets. The map describes the job and possible branches.
It does not claim every proposed recovery surface already exists natively.

    Reader in original app
      M1 Choose a passage
       |
      M2 Ask to listen
       |
      M3 Does speech begin? ------------------------------+
       | no                                              | yes
      M4 Find a useful status or next action [TARGET]     |
       |                                                 |
      M5 Understand what is unavailable [TARGET]          |
       |                                                 |
      M6 Choose an available action or repair [TARGET]   |
       |                 |                               |
       | direct read     M7 Complete required recovery   |
       |                 |                               |
       +-----------------+-------------------------------+
                         |
                        M8 Hear the intended passage
                         |
                        M9 Stop or finish; remain in context
                         |
                  Repeated use supports the long-term goal

    At M1 or M4–M7, the reader may instead:
    read silently / use macOS Speak Selection / copy into another reader /
    postpone or skip the passage.

| Step | Reader or system action | Decision or uncertainty |
| --- | --- | --- |
| M1 | Reader selects a passage in its source application. | The passage must be accessible; selection support is not universal. |
| M2 | Reader invokes the familiar shortcut or a menu action. | A disabled event tap may never receive a shortcut attempt. |
| M3 | Speech starts, or the reader experiences silence/a visible blocker. | Silence can be interpreted as waiting, failure, or an ineffective shortcut; actual interpretations are unknown. |
| M4 | Reader looks for an explanation or another route. | Whether they notice the proposed menu-bar cue is unmeasured. |
| M5 | Reader interprets the displayed capability status. | Shortcut failure must not imply that all listening is unavailable. |
| M6 | Reader chooses a usable listening action or explicit recovery. | A direct menu read is a legitimate success; repairing the shortcut is not mandatory for listening. |
| M7 | Relevant owner completes recovery: shortcut service, macOS permission, or model assets. | Waiting, failure, and cancellation need truthful states. Only shortcut recovery is included in this proposed study. |
| M8 | Reader explicitly starts speech from the intended passage. | A prototype clip demonstrates a choice and response; actual capture/synthesis needs native proof. |
| M9 | Reader stops or finishes and keeps their place. | A successful session does not establish habitual use or retention. |

**Map narrative:** The reader starts with text they already want to hear. The
ordinary path goes directly from the listening request to speech. When that
request produces no audio, discovery precedes diagnosis and recovery; a clearly
labelled repair is useful only after the reader finds it. Some readers may choose
another listening route or abandon listening, but their frequency and reasons
are unknown. Successful recovery returns to the original passage rather than
creating a new reading workspace.

## Expert Interview Notes

**Status: not conducted.** The entries below are proposed cameo briefs, not
synthesized interviews. There are no expert quotations, observed answers, or
interview-derived HMW notes yet. Schedule only through a later authorized action.

### E-01: Regular Mac reader who uses text-to-speech

- **Person/status:** Not identified or invited; outside the delivery team.
- **Reason to invite:** Understand what silence means during an actual reading task.
- **Ask:** Describe the last time a listening action failed. What did you try next?
  What made you stop troubleshooting? Which app did you return to?
- **Source prompt, not testimony:** E1 names keeping one's place as the job.
- **Notes/result:** None. Potential HMW themes: C1 discovery and C5 return/control.

### E-02: macOS Accessibility/shortcut engineer

- **Person/status:** Not identified or invited; consult the existing native owner
  for implementation facts without inventing a new owner.
- **Reason to invite:** Check which failures can be observed and which attempts
  cannot be received.
- **Ask:** Which status changes are reliable? What could make a menu cue stale?
  Which recovery paths can retain the original application and selected passage?
- **Source prompt, not testimony:** E2 separates event reception, permission,
  assets, and playback.
- **Notes/result:** None. Potential HMW themes: C2 valid actions and C4 recovery.

### E-03: Researcher experienced with desktop utilities

- **Person/status:** Not identified or invited; preferably not the prototype author.
- **Reason to invite:** Challenge cue priming and the limits of a simulated desktop.
- **Ask:** Which instructions reveal the answer? What observation would distinguish
  discovery from guessing? What can this medium not tell us?
- **Source prompt, not testimony:** E4 contains reviewer aids that bias a novice test.
- **Notes/result:** None. Potential HMW themes: C1 discovery and C6 explanations.

Allow 20–25 minutes per cameo if arranged. Preserve disagreements and revise the
map when the evidence warrants it; do not convert these prompts into findings.

## HMW Cluster Board

These are **30 seeded How Might We notes**, authored from E1–E6 for review.
They are not independent team contributions or expert results. All vote totals
are **not run**; no top-voted cluster is claimed.

| Cluster | Theme | Notes | Heat-map votes | Question links |
| --- | --- | --- | --- | --- |
| C1 | Discover the next action | 5: H01–H05 | Not run | Q1 |
| C2 | Keep useful listening paths available | 5: H06–H10 | Not run | Q2 |
| C3 | Make choices predictable | 5: H11–H15 | Not run | Q3 |
| C4 | Complete asset recovery | 5: H16–H20 | Not run | Q4 |
| C5 | Return to the passage and retain control | 5: H21–H25 | Not run | Q5 |
| C6 | Explain trust and prerequisites | 5: H26–H30 | Not run | Q1, Q2, Q4 |

### C1: Discover the next action

- **H01:** How might we expose an unavailable shortcut without requiring it to receive an event?
- **H02:** How might we help a reader find MLXRead when its windows are closed?
- **H03:** How might we distinguish a blocked request from speech that is still preparing?
- **H04:** How might we make a small status cue understandable without interrupting the document?
- **H05:** How might we help someone who knows only the shortcut discover another route?

### C2: Keep useful listening paths available

- **H06:** How might we make menu reading discoverable while shortcut recovery is pending?
- **H07:** How might we let a reader try a voice before deciding about selection access?
- **H08:** How might we expose a valid alternative voice while preserving an unavailable saved choice?
- **H09:** How might we distinguish an active reading from readiness to start another?
- **H10:** How might we name the next useful action when several prerequisites differ?

### C3: Make choices predictable

- **H11:** How might we distinguish an audition from a change to future readings?
- **H12:** How might we keep the current model and reading voice clear during comparison?
- **H13:** How might we explain a compatible-language preview without changing the reading language?
- **H14:** How might we preserve the reader's choices while files are unavailable?
- **H15:** How might we make the effect of Use & Preview clear before it is activated?

### C4: Complete asset recovery

- **H16:** How might we explain a failed download in terms of the next action?
- **H17:** How might we keep progress, validation, and usable assets distinct?
- **H18:** How might we make cancellation honest while a file writer is still stopping?
- **H19:** How might we preserve entered sample text through a download retry?
- **H20:** How might we explain first-use preparation without promising network-free setup?

### C5: Return to the passage and retain control

- **H21:** How might we help a reader return to the original selection after repair?
- **H22:** How might we prevent recovery from unexpectedly replaying old text?
- **H23:** How might we keep Stop reachable when another capability becomes unavailable?
- **H24:** How might we distinguish the active pace from a setting for the next reading?
- **H25:** How might we make hiding playback controls clearly different from stopping speech?

### C6: Explain trust and prerequisites

- **H26:** How might we explain why selection needs permission while a sample does not?
- **H27:** How might we explain local reading without implying that every app operation is offline?
- **H28:** How might we make empty and error states point toward different useful actions?
- **H29:** How might we make recovery understandable through text and keyboard focus, not color alone?
- **H30:** How might we teach the fallback once without turning every reading into setup?

**Suggested synthesis:** Review C1 and C2 first because they address Q1/Q2 and
F-02 directly. That is an author recommendation, not a vote result.

If a team is convened, use a short note-and-vote: independent additions before
showing these seeds, silent allocation of three dots per person, discussion of
the resulting distribution, then James's target decision. Record real counts and
dissent. If James is deciding alone, use direct judgment; do not stage a vote.

## Target Moment

**Recommended target T2:** M4–M6, beginning in the source app immediately after
the usual shortcut has produced no speech, with MLXRead's menu closed. The
reader must find an explanation and choose a valid route back to listening.
Carry the prototype through M8 and M9 to make the result and control visible.

| Candidate | Risk it tests | Why choose or defer it |
| --- | --- | --- |
| T1: Try a voice before selection permission, around M2/M3 | Q3; whether audition and selection are understood | Useful, but preview effects are now specified and the entry is already visible. Defer in this proposed sprint. |
| T2: Find a usable path after silent shortcut failure, M4–M6 | Q1/Q2; whether recovery is discovered and interpreted | Recommend. This assumption cannot be established by a labelled button or the existing DOM checks. |
| T3: Recover a failed model download, M6/M7 | Q4; whether explicit retry reaches usable speech | Important, but broader acquisition conditions need controlled native proof. Keep AC-14 as a separate requirement. |

**Proposed rationale:** T2 joins a meaningful user outcome to the least supported
part of the current proposal: finding the recovery surface. The source already
permits the idea of separate capabilities, but people may still read a shortcut
failure as total failure. One route may let them continue immediately; another
may repair the shortcut first. The study should accept either successful route.

**Primary question links:** Q1 and Q2. **Supporting control question:** Q5.

**Decider-selected target:** Pending.
**Decider rationale:** Not supplied.
**Decision status:** Recommended, not ratified. Choosing T2 does not select the
broader A/B/C product direction or approve ADR-001.

## Decider Checkpoint

The requested map-and-target method reserves target selection to the Decider.
The requested prototype-plan method consumes an approved storyboard. The work
above makes those decisions concrete; no workshop attendance or signature is
inferred from this document.

- [ ] James confirms or revises the two-year goal and Q1–Q5.
- [ ] James confirms the map as a working account, including its uncertainty.
- [ ] James selects T1, T2, T3, or a revised target; record the rationale.
- [ ] James chooses direct decision or a real team synthesis; any vote remains absent until conducted.
- [ ] James reviews the proposed P1–P7 storyboard and study scope in the linked prototype plan.
- [ ] If a full sprint is scheduled, confirm the actual brief, named roster, expert access, dates, and Decider attendance before calling the stages complete.

**Signed:** Pending; no date or attendance commitment recorded.
