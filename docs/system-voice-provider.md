# System voice provider (Phase 2)

**Status: partially verified** — provider discovery, host-app synthesis,
repeated synthesis, and cancellation are all proven with runtime evidence on
this machine (macOS 26.5.2, Xcode 26.6, Development signing). System
Settings visibility and native Speak Selection usage require a manual user
step that MLXRead must not automate. The extension's render path currently
produces a deterministic placeholder waveform, not MLX speech — see
"Remaining work".

## Confirmed SDK facts

- The provider API lives in **AVFAudio** (not AVFoundation):
  `MacOSX26.5.sdk/System/Library/Frameworks/AVFAudio.framework/Versions/A/Headers/AVSpeechSynthesisProvider.h`
  - `AVSpeechSynthesisProviderVoice` — `API_AVAILABLE(ios(16.0), macos(13.0), watchos(9.0), tvos(16.0))`;
    `+updateSpeechVoices`, name/identifier/languages; header states provider
    voices surface via `AVSpeechSynthesisVoice.speechVoices()` with quality
    always `.enhanced`.
  - `AVSpeechSynthesisProviderRequest` — carries `ssmlRepresentation` and the
    target voice.
  - `AVSpeechSynthesisProviderAudioUnit : AUAudioUnit` —
    `speechVoices`, `speechSynthesisOutputMetadataBlock`,
    `synthesizeSpeechRequest:`, `cancelSpeechRequest`. Completion is signaled
    from `internalRenderBlock` with
    `kAudioOfflineUnitRenderAction_Complete`. `API_UNAVAILABLE(watchos)`.
- Xcode 26.6 ships the template: *Multiplatform → Application Extension →
  Audio Unit Extension → type "Speech Synthesizer"*, generating an
  `AudioComponents` entry with `type = ausp` and
  `NSExtensionPointIdentifier = com.apple.AudioUnit`. The template notes the
  AU renders offline, so Swift is safe.
- Apple's own system voices are implemented exactly this way:
  `MacinTalkAUSP.appex` (`type=ausp`, extension point
  `com.apple.AudioUnit-Speech`), SiriAUSP, KonaSynthesizer, MauiAUSP.
  Apple's providers additionally carry the private entitlement
  `com.apple.accessibility.systemvoiceprovider`; **third-party discovery
  does not require it** (verified below).

## MLXRead extension

Target `SystemVoiceProvider` (appex, embedded in MLXRead.app/Contents/PlugIns):

- `AudioComponents`: `type ausp`, subtype `mlxr`, manufacturer `JKCA`,
  `sandboxSafe true`; extension point `com.apple.AudioUnit` (template
  value; the `com.apple.AudioUnit-Speech` variant was not needed).
- Sandboxed (`com.apple.security.app-sandbox`), signed with the same
  Apple Development identity as the app.
- `MLXReadProviderAudioUnit` subclasses `AVSpeechSynthesisProviderAudioUnit`:
  one voice ("MLXRead Preview", `me.jkca.mlxread.voice.preview`, en-US),
  24 kHz mono float output bus, buffered offline render, cancellation
  clears the pending buffer.

## Directly observed runtime evidence (2026-07-11)

1. **Installed + signed** — `Contents/PlugIns/SystemVoiceProvider.appex`;
   `codesign -dvv` shows `Apple Development: James Auchterlonie (3UB9P555B8)`
   chain; `codesign --verify --deep --strict MLXRead.app` passes.
2. **PluginKit discovery** — after launching the app once:
   `pluginkit -m -v -i me.jkca.mlxread.SystemVoiceProvider` lists the appex.
3. **AudioComponent registry** — enumerating `ausp` components returns
   6 entries: Apple's five plus `JKCA: MLXRead Voice`.
4. **speechVoices()** — `AVSpeechSynthesisVoice.speechVoices()` (181 voices)
   contains `MLXRead Preview
   [me.jkca.mlxread.SystemVoiceProvider.me.jkca.mlxread.voice.preview]`.
   `say -v '?'` also lists it.
5. **System-path synthesis** —
   `say -v "MLXRead Preview" -o test.aiff "hello from the provider test"`
   produced 0.80 s of non-silent PCM (peak 9830/32767 after LEI16
   conversion), matching the placeholder's designed 5-pulse output for a
   5-word input. This exercises the full chain: speech daemon → appex launch
   → `createAudioUnit` → `synthesizeSpeechRequest` → offline render.
6. **Host-app synthesis, repeated** — `AVSpeechSynthesizer.write()` with the
   voice: pass 1 = 15,357 frames (4 words → expected 15,360), pass 2 =
   23,037 frames (6 words → expected 23,040); both non-silent. Two
   consecutive requests through one extension lifetime.
7. **Cancellation** — `speak()` + `stopSpeaking(at: .immediate)` after 2 s
   returns true and `isSpeaking` goes false.

Caveat on the probe technique: `AVSpeechSynthesizer.write` delivers buffers
via the main run loop; a probe that blocks the main thread on a semaphore
times out. Pump the run loop.

## Not verified (and why)

- **System Settings voice picker / native Speak Selection / VoiceOver usage.**
  Selecting the voice as the system voice is a user action in System
  Settings; MLXRead does not modify accessibility settings, and scripting
  System Settings requires Apple Events/UI automation this environment does
  not have. Given evidence items 4–6 (the same `speechVoices` catalog and
  provider path back Spoken Content), it is *expected* to work, but it has
  not been observed. Manual check: System Settings → Accessibility → Spoken
  Content → System voice → Manage Voices… → look for "MLXRead Preview".

## Remaining work (known, deliberate)

- The render path emits a deterministic pulse waveform, not MLX speech.
  Real synthesis inside the sandboxed appex needs the Kokoro/Soprano model
  readable from an app-group container shared with the host app (the appex
  cannot read `~/Library/Application Support/MLXRead`), plus memory-bounded
  MLX inference inside the extension and asynchronous model preparation off
  the render path. The provider was intentionally kept model-free until
  discovery was proven; discovery is now proven, so this is the next
  increment.
- `AVSpeechSynthesisProviderVoice.updateSpeechVoices()` should be called by
  the host app when models/voices change.
