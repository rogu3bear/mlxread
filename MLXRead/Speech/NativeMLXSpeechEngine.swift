import Foundation
@preconcurrency import MLX
import MLXAudioCore
import MLXAudioTTS
import MLXLMCommon

/// Production speech engine on mlx-audio-swift.
///
/// Kokoro and Soprano both emit one final audio buffer per `generateStream`
/// call (no incremental audio), so incremental playback comes from
/// synthesizing our deterministic sentence chunks sequentially and yielding
/// each chunk's audio as it completes. The first chunk is deliberately small
/// (the chunker's target length) to keep time-to-first-audio low.
///
/// - preparation is single-flight (`prepareTask` reused);
/// - the loaded model stays warm for subsequent reads;
/// - `cancel()` cancels the in-flight generation task; Soprano honors
///   token-level cancellation, Kokoro at forward-pass boundaries;
/// - selected text only ever lives in memory here.
actor NativeMLXSpeechEngine: SpeechEngine {
    nonisolated let modelInfo: ModelInfo
    nonisolated var identifier: String { modelInfo.id }
    nonisolated var displayName: String { modelInfo.displayName }
    nonisolated var sampleRate: Double { modelInfo.nominalSampleRate }

    private var model: SpeechGenerationModel?
    private var prepareTask: Task<Void, Error>?
    private var generationTask: Task<Void, Never>?

    init(modelInfo: ModelInfo) {
        self.modelInfo = modelInfo
    }

    // MARK: - SpeechEngine

    func prepare() async throws {
        if model != nil { return }
        if let prepareTask {
            try await prepareTask.value
            return
        }
        let info = modelInfo
        let task = Task<Void, Error> {
            AppLogger.speech.info("Loading model \(info.id)")
            let start = ContinuousClock.now
            // Bound MLX's GPU buffer cache so a resident menu-bar app stays lean.
            Memory.cacheLimit = 256 * 1024 * 1024
            let loaded = try await TTS.loadModel(modelRepo: info.id)
            self.model = loaded
            let elapsed = ContinuousClock.now - start
            AppLogger.speech.info("Model \(info.id) ready in \(elapsed.description) (sampleRate \(loaded.sampleRate))")
        }
        prepareTask = task
        do {
            try await task.value
        } catch {
            prepareTask = nil
            AppLogger.speech.error("Model load failed: \(error.localizedDescription)")
            throw UserFacingSpeechError.modelLoadFailed(error.localizedDescription)
        }
    }

    nonisolated func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.runGeneration(text: text, configuration: configuration, continuation: continuation)
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
            Task { await self.storeGenerationTask(task) }
        }
    }

    func cancel() async {
        generationTask?.cancel()
        generationTask = nil
    }

    /// Releases the loaded model (memory pressure). Next read reloads.
    func unload() {
        guard generationTask == nil else { return }
        model = nil
        prepareTask = nil
        Memory.clearCache()
        AppLogger.speech.notice("Model released under memory pressure")
    }

    // MARK: - Internals

    private func storeGenerationTask(_ task: Task<Void, Never>) {
        generationTask = task
    }

    private func runGeneration(
        text: String,
        configuration: SpeechConfiguration,
        continuation: AsyncThrowingStream<SpeechAudioChunk, Error>.Continuation
    ) async {
        do {
            try await prepare()
            guard let model else {
                throw UserFacingSpeechError.modelLoadFailed("model unavailable after prepare")
            }
            let pieces = TextChunker.chunk(text)
            AppLogger.speech.info("Generating \(pieces.count) chunk(s), \(text.count) chars total")
            var index = 0
            let voice = modelInfo.supportsVoices ? (configuration.voice ?? modelInfo.defaultVoice) : nil
            for piece in pieces {
                try Task.checkCancellation()
                let stream = model.generateStream(
                    text: piece,
                    voice: voice,
                    refAudio: nil,
                    refText: nil,
                    language: configuration.language,
                    generationParameters: model.defaultGenerationParameters
                )
                for try await event in stream {
                    try Task.checkCancellation()
                    if case .audio(let audio) = event {
                        let samples: [Float] = audio.asArray(Float.self)
                        guard !samples.isEmpty else { continue }
                        continuation.yield(SpeechAudioChunk(
                            samples: samples,
                            sampleRate: Double(model.sampleRate),
                            index: index
                        ))
                        index += 1
                    }
                }
            }
            Memory.clearCache()
            continuation.finish()
        } catch is CancellationError {
            Memory.clearCache()
            continuation.finish(throwing: CancellationError())
        } catch let error as UserFacingSpeechError {
            continuation.finish(throwing: error)
        } catch {
            AppLogger.speech.error("Synthesis failed: \(error.localizedDescription)")
            continuation.finish(throwing: UserFacingSpeechError.synthesisFailed(error.localizedDescription))
        }
    }
}
