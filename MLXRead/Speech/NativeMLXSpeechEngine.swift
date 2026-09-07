import Foundation
@preconcurrency import MLX
import MLXAudioCore
import MLXAudioTTS
import MLXLMCommon

/// Production speech engine on mlx-audio-swift.
///
/// Kokoro, Soprano, Chatterbox, and the current Pocket port emit one final audio buffer per `generateStream`
/// call (no incremental audio), so incremental playback comes from
/// synthesizing our deterministic sentence chunks sequentially and yielding
/// each chunk's audio as it completes. The first chunk is deliberately small
/// (the chunker's target length) to keep time-to-first-audio low.
/// Qwen additionally streams audio within each sentence chunk.
///
/// - preparation is single-flight (`prepareTask` reused);
/// - the loaded model stays warm for subsequent reads;
/// - cancellation stops delivery immediately and drains the current sentence
///   before allowing the model's mutable decoder to be reused;
/// - selected text only ever lives in memory here.
actor NativeMLXSpeechEngine: SpeechEngine {
    nonisolated let modelInfo: ModelInfo
    nonisolated var identifier: String { modelInfo.id }
    nonisolated var displayName: String { modelInfo.displayName }
    nonisolated var sampleRate: Double { modelInfo.nominalSampleRate }
    nonisolated var handlesSpeechSpeed: Bool { modelInfo.id == ModelManifest.kokoro.id }

    private var model: SpeechGenerationModel?
    private var prepareTask: Task<Void, Error>?
    private var generation: (request: GenerationRequest, task: Task<Void, Never>)?
    private let modelDirectory: URL
    private let loadModel: @Sendable (ModelInfo, URL) async throws -> SpeechGenerationModel

    init(modelInfo: ModelInfo, modelDirectory: URL? = nil,
         loadModel: @escaping @Sendable (ModelInfo, URL) async throws -> SpeechGenerationModel = NativeMLXSpeechEngine.loadLocalModel) {
        self.modelInfo = modelInfo
        self.modelDirectory = modelDirectory ?? Constants.modelsDirectory.appendingPathComponent(modelInfo.cacheSubdirectory)
        self.loadModel = loadModel
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
            defer { self.prepareTask = nil }
            if !info.additionalDownloads.isEmpty {
                // Chatterbox's native loader also opens its S3 codec. Require the
                // complete app-owned download before that loader can run.
                let expected = Constants.modelsDirectory.appendingPathComponent(info.cacheSubdirectory)
                guard self.modelDirectory.standardizedFileURL == expected.standardizedFileURL,
                      await MainActor.run(body: { ModelStore().validate(info) }) else {
                    throw UserFacingSpeechError.modelFilesIncomplete
                }
            }
            AppLogger.speech.info("Loading model \(info.id)")
            let start = ContinuousClock.now
            // Bound MLX's GPU buffer cache so a resident menu-bar app stays lean.
            Memory.cacheLimit = 256 * 1024 * 1024
            // Downloads belong to ModelStore. Loading a local snapshot must not
            // silently start another weights download after deletion.
            let loaded = try await self.loadModel(info, self.modelDirectory)
            self.model = loaded
            let elapsed = ContinuousClock.now - start
            AppLogger.speech.info("Model \(info.id) ready in \(elapsed.description) (sampleRate \(loaded.sampleRate))")
        }
        prepareTask = task
        do {
            try await task.value
        } catch {
            AppLogger.speech.error("Model load failed: \(error.localizedDescription)")
            throw UserFacingSpeechError.modelLoadFailed(error.localizedDescription)
        }
    }

    nonisolated func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let request = GenerationRequest()
            Task {
                await self.enqueueGeneration(text: text, configuration: configuration,
                                             request: request, continuation: continuation)
            }
            continuation.onTermination = { _ in
                request.cancel()
            }
        }
    }

    func cancel() async {
        let current = generation
        current?.request.cancel()
        await current?.task.value
        // Preparation may outlive a cancelled caller. Join it before deletion
        // or a model switch can release its files and loaded state.
        try? await prepareTask?.value
    }

    /// Releases the loaded model (memory pressure). Next read reloads.
    func unload() {
        guard generation == nil, prepareTask == nil else { return }
        model = nil
        prepareTask = nil
        Memory.clearCache()
        AppLogger.speech.notice("Model released under memory pressure")
    }

    // MARK: - Internals

    private func enqueueGeneration(
        text: String, configuration: SpeechConfiguration, request: GenerationRequest,
        continuation: AsyncThrowingStream<SpeechAudioChunk, Error>.Continuation
    ) async {
        let previous = generation
        previous?.request.cancel()
        let task = Task {
            await previous?.task.value
            await self.runGeneration(text: text, configuration: configuration,
                                     request: request, continuation: continuation)
        }
        generation = (request, task)
        await task.value
        if generation?.request === request { generation = nil }
    }

    private func runGeneration(
        text: String,
        configuration: SpeechConfiguration,
        request: GenerationRequest,
        continuation: AsyncThrowingStream<SpeechAudioChunk, Error>.Continuation
    ) async {
        do {
            try request.checkCancellation()
            let language = modelInfo.readingLanguage(voice: configuration.voice, requested: configuration.language)
            guard modelInfo.canRead(voice: configuration.voice, language: language) else {
                throw UserFacingSpeechError.synthesisFailed("This dialect voice cannot read \(VoiceOption.languageName(language)) in the current engine. Choose another voice.")
            }
            try await prepare()
            try request.checkCancellation()
            guard let model else {
                throw UserFacingSpeechError.modelLoadFailed("model unavailable after prepare")
            }
            if let kokoro = model as? KokoroModel {
                // Let the model adjust phoneme durations before generating audio.
                // Soprano has no equivalent; its rate stays in the audio player.
                kokoro.speed = Float(configuration.speed.isFinite ? min(max(configuration.speed, 0.5), 2.0) : 1.0)
            }
            let pieces = TextChunker.chunk(text)
            AppLogger.speech.info("Generating \(pieces.count) chunk(s), \(text.count) chars total")
            var index = 0
            let voice = model is Qwen3TTSModel ? configuration.qwenVoicePrompt
                : modelInfo.supportsVoices ? (configuration.voice ?? modelInfo.defaultVoice) : nil
            for piece in pieces {
                try request.checkCancellation()
                let stream = model.generateStream(
                    text: piece,
                    voice: voice,
                    refAudio: nil,
                    refText: nil,
                    language: model is Qwen3TTSModel ? qwenLanguage(language) : language,
                    generationParameters: model.defaultGenerationParameters,
                    streamingInterval: 0.5
                )
                for try await event in stream {
                    // Upstream streams own unstructured producer tasks. Cancelling
                    // their iterator does not join those tasks. Drain to the real
                    // terminal event so decoder cleanup precedes the next read.
                    if request.isCancelled { continue }
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
                try request.checkCancellation()
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

    private nonisolated static func loadLocalModel(_ info: ModelInfo, _ directory: URL) async throws -> SpeechGenerationModel {
        guard FileManager.default.fileExists(atPath: directory.appendingPathComponent("config.json").path) else {
            throw UserFacingSpeechError.modelFilesIncomplete
        }
        switch info.id {
        case ModelManifest.kokoro.id:
            return try await KokoroModel.fromModelDirectory(directory, textProcessor: KokoroMultilingualProcessor())
        case ModelManifest.soprano.id:
            return try await SopranoModel.fromModelDirectory(directory, repo: info.id)
        case ModelManifest.qwen.id:
            return try await Qwen3TTSModel.fromModelDirectory(directory)
        case ModelManifest.pocket.id:
            return try await PocketTTSModel.fromModelDirectory(directory)
        case ModelManifest.chatterbox.id:
            return try await ChatterboxModel.fromModelDirectory(directory, hfToken: nil)
        default:
            throw UserFacingSpeechError.modelFilesIncomplete
        }
    }

    private func qwenLanguage(_ code: String?) -> String {
        switch code?.split(separator: "-").first {
        case "zh": return "Chinese"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "de": return "German"
        case "fr": return "French"
        case "ru": return "Russian"
        case "pt": return "Portuguese"
        case "es": return "Spanish"
        case "it": return "Italian"
        default: return "English"
        }
    }
}

/// Cancellation belongs to the request, not the task draining the model stream.
private final class GenerationRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
    func checkCancellation() throws {
        if isCancelled { throw CancellationError() }
    }
}
