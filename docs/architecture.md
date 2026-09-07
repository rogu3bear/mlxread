# Architecture

MLXRead is a menu-bar utility with one interaction: **Option–Escape** reads
the current selection aloud with a local MLX model; pressing it again cancels
everything immediately.

## Application startup

[`LSMultipleInstancesProhibited`](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html)
asks Launch Services to refuse extra instances.
Before constructing `AppState`, `AppDelegate` also acquires a nonblocking
exclusive file lock in the user's MLXRead application-support directory. This
covers direct executable launches and simultaneous starts from different app
copies before any model store, update service, or keyboard monitoring starts.
An already-running older copy is respected through `NSRunningApplication`.
Duplicate launches exit and reopen the existing app when it is ready. An older
binary that lacks both protections can still launch alongside this build; the
installed copy must be updated for the regular Applications-folder launch path.

The kernel releases the lock when the process exits, including a crash. The
empty file remains in place; it is not a PID file and must not be deleted as
startup cleanup. An unexpected lock error fails startup with a local error log.
XCTest hosting skips this process-global gate, as it already skips production
keyboard monitoring and window setup.

```
             CGEventTap (own thread)                 ┌─────────────────────┐
  ⌥⎋ ──────► GlobalHotkeyService ──── main queue ──► │  SpeechCoordinator  │ ◄── observed by
             (suppresses only ⌥⎋)                    │  (@MainActor, the   │     MenuBarContent,
                                                     │  ONLY state owner)  │     Settings, HUD
                                                     └──────────┬──────────┘
                 ┌───────────────────────────────┬──────────────┤
                 ▼                               ▼              ▼
      SelectedTextService              SpeechEngine       StreamingAudioPlayer
      1. AXSelectedTextReader          (protocol)         (actor)
         kAXFocusedUIElement           ├ NativeMLX…       AVAudioEngine
         kAXSelectedText[Range]        │  (actor, mlx-    └ AVAudioPlayerNode
      2. ClipboardSelectionReader      │   audio-swift)     └ AVAudioUnitTimePitch
         snapshot → ⌘C → bounded       └ MockSpeechEngine    bounded AudioQueue(4)
         wait → restore-if-safe
                 │                               │
                 ▼                               ▼
      PasteboardSnapshot            TextNormalizer → TextChunker → per-chunk
      (changeCount-guarded)         generateStream → SpeechAudioChunk stream
```

## The state machine

`SpeechCoordinator.state` (`SpeechState`) is the single source of truth:

```
permissionRequired / modelRequired / voiceRequired  (resting gates)
idle ─⌥⎋─► capturing ─► preparing ─► generating ─► playing ─► idle
  ▲                                     │             │
  └──────── stopping ◄──── ⌥⎋ ──────────┴─────────────┘
failed(error)  (retained until the next read, voice/model choice, or readiness change)
```

Availability refreshes compare the current permission/model gate with the
previous one. Download progress and other unchanged updates retain a reading
error; retrying or choosing another voice or model can clear it explicitly.
Catalog refreshes never change the saved voice. Model readiness also checks
the selected voice file, because an interrupted catalog can contain usable
weights and some voices while the saved voice is missing. Settings shows the
saved choice as unavailable and requires an explicit choice; reading and
selected-voice previews stay gated until that voice arrives or another available voice is chosen.
Individual previews validate their requested voice separately; a missing saved
voice does not prevent auditioning another available voice.

Every read gets a **generation UUID**. The UUID is checked:
1. in the coordinator loop before each chunk is forwarded,
2. in the player before each chunk is scheduled (session identity),
3. via the `AudioQueue` epoch for late buffer-completion callbacks.

A cancelled generation can therefore never leak audio into a newer session.

## Streaming model

Kokoro, Soprano, Chatterbox, and the pinned Pocket Swift implementation produce one audio
buffer per call (no incremental audio),
so MLXRead creates streaming at the app level: `TextChunker` splits the
normalized selection into deterministic sentence chunks (~300 chars target),
the engine synthesizes them sequentially, and each chunk is scheduled on the
player node the moment it exists. Playback begins after the first chunk;
synthesis of chunk N+1 overlaps playback of chunk N. `AudioQueue` caps
in-flight buffers at 4, so a long selection never piles up unbounded PCM.
Qwen's Swift implementation additionally emits audio within each sentence
chunk; MLXRead requests a 0.5-second streaming interval through the shared
generation protocol. Actual first-audio latency still includes model loading
and generation.

## Cancellation path (`stop()` / second ⌥⎋)

1. coordinator flips to `.stopping`, invalidates the generation UUID;
2. reading task is cancelled (Swift structured cancellation reaches the
   engine's token loop — Soprano checks per token, Kokoro per forward pass);
3. `engine.cancel()` cancels the generation task explicitly;
4. `player.stopImmediately()` stops the node (clears every scheduled
   buffer), stops the engine, resets the queue epoch;
5. state returns to `.idle`.

Playback ceases in step 4 regardless of how long the model takes to notice
cancellation; stale chunks are dropped by the UUID/session gates.

## Layers and ownership

| Layer | Type | Isolation |
|---|---|---|
| `AppState` | composition root | `@MainActor` |
| `SpeechCoordinator` | state machine | `@MainActor @Observable` |
| `AppSettings`, `ModelStore`, `SelectionAccessService` | services | `@MainActor @Observable` |
| `NativeMLXSpeechEngine` | model load + generate | actor |
| `StreamingAudioPlayer` + `AudioQueue` | playback | actors |
| `GlobalHotkeyService` | CGEventTap | own thread, lock-guarded |
| `AXSelectedTextReader` / `ClipboardSelectionReader` | capture | background tasks, value results |

The UI (menu bar, settings tabs, HUD, onboarding) only ever observes
`SpeechCoordinator`, `AppSettings`, `ModelStore`, and `SelectionAccessService`.
Mocks (`MockSpeechEngine`, fakes in tests) implement the same protocols
(`SpeechEngine`, `SelectionCapturing`, `AudioPlaying`), which is how the
entire pipeline is exercised without a model.

`SelectionAccessService` owns permission observation and shortcut recovery.
Launch starts one monitor; onboarding and settings never install event taps.
Each one-second check reads Accessibility trust and the tap's current validity,
enabled state, and worker readiness. An unhealthy shortcut gets at most three
attempts before an explicit retry is offered. Returning to the app or regaining
permission starts a fresh attempt. Revocation stops the tap before notifying
the speech coordinator. Shortcut recovery alone does not clear reading errors
or stop previews. The tap worker and teardown share one lock; an old worker
cannot attach to or clear a replacement tap.

Each reading snapshots its engine and configuration before asynchronous work.
Stop cancels that engine even if settings change. Kokoro applies the requested
rate to phoneme durations during synthesis (`handlesSpeechSpeed`); its player
rate stays at 1×. Soprano, Pocket, Chatterbox, and Qwen use `AVAudioUnitTimePitch` for playback rate. The HUD
shows the active snapshot's rate, and setting changes affect the next reading.

Preview bypasses selection capture and its Accessibility gate, while retaining
a separate model-availability gate. Missing models require an explicit download.
Preview text lives only in the Voice view's memory and never comes from captured
selections. Model-store state changes refresh the coordinator's resting state.

`ModelManifest` owns the supported model catalog, required tokenizer files,
and voice sources. Kokoro discovers `voices/`, Pocket discovers `embeddings/`,
and Qwen uses named presets. A boolean voice flag must not imply a Kokoro
directory layout. Qwen's reading language is independent of its preset voice,
except for the pinned runtime's Dylan/Eric dialect override. Their manifest
entries restrict reading to Chinese; both the availability gate and engine
reject an incompatible language. Their preview rows explicitly use Chinese.

Individual previews pass an immutable configuration override into the existing
coordinator. They neither mutate saved preferences nor create a second playback
owner. Qwen's delivery setting becomes the native adapter's `speaker, instruction`
conditioning string; the passage itself remains unchanged.

Chatterbox Turbo uses the native Chatterbox implementation and bundled default
voice conditioning. Its loader also requires S3TokenizerV2. Both repositories
belong to its manifest download, readiness check, disk usage, and deletion. The
engine checks the complete app-owned download before invoking that loader.

`ModelStore` owns each download operation until its writer finishes. Progress
is bound to that operation; an old callback cannot update a subsequent retry.
Cancellation stays visible until completion. Deletion first marks the model
unavailable, cancels and joins any download, then removes the model directory
and its legacy Hub cache. Incomplete tokenizer/voice assets gate reading.
Downloads use the Hub snapshot API directly with one destination; inference
loads that local directory and never implicitly restores deleted weights.
The engine cache keeps only the most recently used model and drops it when
its download becomes unavailable. Voice choices survive model deletion.

A future `KokoroSpeechEngine` or any other backend implements `SpeechEngine`
and plugs into `AppState`'s engine provider; selection, hotkey, playback, and
UI layers are untouched by backend changes.
