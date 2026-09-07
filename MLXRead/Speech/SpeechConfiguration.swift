import Foundation

/// Per-utterance synthesis options. Only model-supported controls are exposed.
struct SpeechConfiguration: Sendable, Equatable {
    /// Voice identifier understood by the active model, or nil for its default.
    var voice: String?
    /// Playback/synthesis speed multiplier (1.0 = normal).
    var speed: Double
    /// BCP-47-ish language hint understood by the model, or nil.
    var language: String?
    var delivery: SpeechDelivery

    init(voice: String? = nil, speed: Double = 1.0, language: String? = nil, delivery: SpeechDelivery = .natural) {
        self.voice = voice
        self.speed = speed
        self.language = language
        self.delivery = delivery
    }

    /// Qwen's native adapter accepts a speaker followed by an optional instruction.
    /// This is conditioning, never text prepended to the passage being read.
    var qwenVoicePrompt: String { "\(voice ?? "ryan"), \(delivery.instruction)" }
}

enum SpeechDelivery: String, CaseIterable, Sendable {
    case natural = "Natural"
    case narration = "Narration"
    case expressive = "Expressive"

    var instruction: String {
        switch self {
        case .natural: return "Speak clearly in a natural conversational tone, with relaxed pacing and natural pauses."
        case .narration: return "Read as a calm audiobook narrator, with clear diction and thoughtful pauses."
        case .expressive: return "Speak with warm, lively intonation, following the emotion of the text."
        }
    }
}
