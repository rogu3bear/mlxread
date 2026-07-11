import Foundation

/// Deterministic tone-generating engine used to prove the full
/// hotkey → capture → synthesize → play interaction without a model, and by
/// unit tests. Enabled via MLXREAD_ENGINE=mock.
actor MockSpeechEngine: SpeechEngine {
    nonisolated let identifier = "mock"
    nonisolated let displayName = "Mock (test tone)"
    nonisolated let sampleRate: Double = 24_000

    /// Simulated synthesis delay per chunk.
    let chunkDelay: Duration
    /// Audio seconds produced per text chunk.
    let secondsPerChunk: Double

    private(set) var prepareCallCount = 0
    private var generationTask: Task<Void, Never>?

    init(chunkDelay: Duration = .milliseconds(80), secondsPerChunk: Double = 0.6) {
        self.chunkDelay = chunkDelay
        self.secondsPerChunk = secondsPerChunk
    }

    func prepare() async throws {
        prepareCallCount += 1
    }

    nonisolated func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        let rate = sampleRate
        let delay = chunkDelay
        let seconds = secondsPerChunk
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let pieces = TextChunker.chunk(text)
                    for (index, piece) in pieces.enumerated() {
                        try Task.checkCancellation()
                        try await Task.sleep(for: delay)
                        // Pitch varies with chunk content so ordering is audible.
                        let frequency = 220.0 + Double(piece.count % 12) * 40.0
                        let frames = Int(rate * seconds)
                        let samples = (0..<frames).map { i -> Float in
                            let t = Double(i) / rate
                            let envelope = min(1.0, min(t / 0.02, (seconds - t) / 0.05))
                            return Float(sin(2 * .pi * frequency * t) * 0.25 * max(0, envelope))
                        }
                        continuation.yield(SpeechAudioChunk(samples: samples, sampleRate: rate, index: index))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: CancellationError())
                }
            }
            continuation.onTermination = { _ in task.cancel() }
            Task { await self.storeTask(task) }
        }
    }

    func cancel() async {
        generationTask?.cancel()
        generationTask = nil
    }

    private func storeTask(_ task: Task<Void, Never>) {
        generationTask = task
    }
}
