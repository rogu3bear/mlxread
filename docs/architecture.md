# Architecture

MLXRead is a menu-bar utility with one interaction: **Option–Escape** reads
the current selection aloud with a local MLX model; pressing it again cancels
everything immediately.

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
previewing stay gated until that voice arrives or another available voice is chosen.

Every read gets a **generation UUID**. The UUID is checked:
1. in the coordinator loop before each chunk is forwarded,
2. in the player before each chunk is scheduled (session identity),
3. via the `AudioQueue` epoch for late buffer-completion callbacks.

A cancelled generation can therefore never leak audio into a newer session.

## Streaming model

Kokoro and Soprano produce one audio buffer per call (no incremental audio),
so MLXRead creates streaming at the app level: `TextChunker` splits the
normalized selection into deterministic sentence chunks (~300 chars target),
the engine synthesizes them sequentially, and each chunk is scheduled on the
player node the moment it exists. Playback begins after the first chunk;
synthesis of chunk N+1 overlaps playback of chunk N. `AudioQueue` caps
in-flight buffers at 4, so a long selection never piles up unbounded PCM.

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
| `AppSettings`, `ModelStore`, `AccessibilityPermissionService` | services | `@MainActor @Observable` |
| `NativeMLXSpeechEngine` | model load + generate | actor |
| `StreamingAudioPlayer` + `AudioQueue` | playback | actors |
| `GlobalHotkeyService` | CGEventTap | own thread, lock-guarded |
| `AXSelectedTextReader` / `ClipboardSelectionReader` | capture | background tasks, value results |

The UI (menu bar, settings tabs, HUD, onboarding) only ever observes
`SpeechCoordinator`, `AppSettings`, `ModelStore`, and the permission service.
Mocks (`MockSpeechEngine`, fakes in tests) implement the same protocols
(`SpeechEngine`, `SelectionCapturing`, `AudioPlaying`), which is how the
entire pipeline is exercised without a model.

Each reading snapshots its engine and configuration before asynchronous work.
Stop cancels that engine even if settings change. Kokoro applies the requested
rate to phoneme durations during synthesis (`handlesSpeechSpeed`); its player
rate stays at 1×. Soprano uses `AVAudioUnitTimePitch` for playback rate. The HUD
shows the active snapshot's rate, and setting changes affect the next reading.

Preview bypasses selection capture and its Accessibility gate, while retaining
a separate model-availability gate. Missing models require an explicit download.
Preview text lives only in the Voice view's memory and never comes from captured
selections. Model-store state changes refresh the coordinator's resting state.

A future `KokoroSpeechEngine` or any other backend implements `SpeechEngine`
and plugs into `AppState`'s engine provider; selection, hotkey, playback, and
UI layers are untouched by backend changes.
