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

    func prepare() async throws

    func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error>

    func cancel() async
}
