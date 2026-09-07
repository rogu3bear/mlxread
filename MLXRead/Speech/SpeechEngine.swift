import Foundation

/// Backend-independent speech synthesis interface.
///
/// Implementations: `NativeMLXSpeechEngine` (production), `MockSpeechEngine`
/// (tests and interaction proofs). A future `KokoroSpeechEngine` or any other
/// backend slots in here without touching selection, playback, hotkey, or UI.
protocol SpeechEngine: Sendable {
    var identifier: String { get }
    var displayName: String { get }
    /// Nominal output sample rate. Individual chunks carry their own
    /// authoritative rate (the loaded model is the source of truth).
    var sampleRate: Double { get }
    /// True when generation applies configuration.speed to speech duration.
    /// The player must then stay at 1× to avoid applying the rate twice.
    var handlesSpeechSpeed: Bool { get }

    func prepare() async throws

    func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error>

    func cancel() async
}

extension SpeechEngine {
    var handlesSpeechSpeed: Bool { false }
}
