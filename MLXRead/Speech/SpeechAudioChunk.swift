import Foundation

/// A contiguous run of mono PCM samples produced by a speech engine.
struct SpeechAudioChunk: Sendable {
    /// Mono float32 samples in [-1, 1].
    let samples: [Float]
    /// Authoritative sample rate for these samples.
    let sampleRate: Double
    /// Monotonic index within the generation, starting at 0.
    let index: Int

    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / sampleRate
    }

    /// Zero samples lasting `seconds`, or nil when that rounds to no frames.
    static func silence(seconds: Double, sampleRate: Double, index: Int) -> SpeechAudioChunk? {
        let frames = Int((seconds * sampleRate).rounded())
        guard frames > 0 else { return nil }
        return SpeechAudioChunk(samples: [Float](repeating: 0, count: frames), sampleRate: sampleRate, index: index)
    }
}
