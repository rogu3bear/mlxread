import Foundation

/// Per-utterance synthesis options. Only model-supported controls are exposed.
struct SpeechConfiguration: Sendable, Equatable {
    /// Voice identifier understood by the active model, or nil for its default.
    var voice: String?
    /// Playback/synthesis speed multiplier (1.0 = normal).
    var speed: Double
    /// BCP-47-ish language hint understood by the model, or nil.
    var language: String?

    init(voice: String? = nil, speed: Double = 1.0, language: String? = nil) {
        self.voice = voice
        self.speed = speed
        self.language = language
    }
}
