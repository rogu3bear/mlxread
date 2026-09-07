import XCTest
@testable import MLXRead

/// Opt-in integration tests against the real MLX models.
///
/// Enable with: TEST_RUNNER_MLXREAD_INTEGRATION=1 (script/test.sh --integration)
/// First run downloads model assets into the MLXRead models directory; after
/// that these tests work offline.
final class IntegrationTests: XCTestCase {

    static var enabled: Bool {
        ProcessInfo.processInfo.environment["MLXREAD_INTEGRATION"] == "1"
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(Self.enabled, "integration tests are opt-in (MLXREAD_INTEGRATION=1)")
        ModelStore.bootstrapEnvironment()
    }

    // MARK: - Helpers

    private func downloadedEngine(_ model: ModelInfo) async throws -> NativeMLXSpeechEngine {
        let store = await MainActor.run { ModelStore() }
        try await download(model, in: store)
        return NativeMLXSpeechEngine(modelInfo: model)
    }

    private func download(_ model: ModelInfo, in store: ModelStore) async throws {
        await MainActor.run { store.download(model) }
        let deadline = ContinuousClock.now + .seconds(1800)
        while await MainActor.run(body: { store.state(for: model).isBusy }) {
            guard ContinuousClock.now < deadline else {
                throw UserFacingSpeechError.modelDownloadFailed("download timed out")
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        let state = await MainActor.run { store.state(for: model) }
        if case .failed(let reason) = state { throw UserFacingSpeechError.modelDownloadFailed(reason) }
        guard state == .downloaded else { throw UserFacingSpeechError.modelFilesIncomplete }
    }

    private func collectChunks(
        engine: NativeMLXSpeechEngine,
        text: String,
        configuration: SpeechConfiguration = SpeechConfiguration()
    ) async throws -> [SpeechAudioChunk] {
        var chunks: [SpeechAudioChunk] = []
        for try await chunk in engine.generate(text: text, configuration: configuration) {
            chunks.append(chunk)
        }
        return chunks
    }

    private func assertValidAudio(_ chunks: [SpeechAudioChunk], expectedRate: Double, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(chunks.isEmpty, "no audio produced", file: file, line: line)
        for chunk in chunks {
            XCTAssertEqual(chunk.sampleRate, expectedRate, file: file, line: line)
            XCTAssertFalse(chunk.samples.isEmpty, file: file, line: line)
            XCTAssertFalse(chunk.samples.allSatisfy { $0 == 0 }, "audio is pure silence", file: file, line: line)
            XCTAssertTrue(chunk.samples.allSatisfy { $0.isFinite }, "audio contains NaN/inf", file: file, line: line)
        }
    }

    // MARK: - Soprano

    func testSopranoPrepareAndSynthesize() async throws {
        let engine = try await downloadedEngine(ModelManifest.soprano)
        try await engine.prepare()
        let chunks = try await collectChunks(
            engine: engine,
            text: "Hello from MLXRead. This is the Soprano model speaking."
        )
        assertValidAudio(chunks, expectedRate: 32_000)
        let seconds = chunks.reduce(0.0) { $0 + $1.duration }
        XCTAssertGreaterThan(seconds, 1.0, "expected at least a second of speech")
    }

    func testSopranoRepeatedGenerationReusesModel() async throws {
        let engine = try await downloadedEngine(ModelManifest.soprano)
        let start1 = ContinuousClock.now
        let first = try await collectChunks(engine: engine, text: "First pass.")
        let coldDuration = ContinuousClock.now - start1

        let start2 = ContinuousClock.now
        let second = try await collectChunks(engine: engine, text: "Second pass.")
        let warmDuration = ContinuousClock.now - start2

        assertValidAudio(first, expectedRate: 32_000)
        assertValidAudio(second, expectedRate: 32_000)
        XCTAssertLessThan(warmDuration, coldDuration, "second generation must reuse the loaded model")
    }

    func testSopranoCancellationStopsPromptly() async throws {
        let engine = try await downloadedEngine(ModelManifest.soprano)
        try await engine.prepare()
        let longText = Array(
            repeating: "This is a long passage that keeps the model generating for a while.",
            count: 20
        ).joined(separator: " ")

        let consumer = Task {
            var count = 0
            do {
                for try await _ in engine.generate(text: longText, configuration: SpeechConfiguration()) {
                    count += 1
                }
            } catch {}
            return count
        }
        try await Task.sleep(for: .seconds(1))
        consumer.cancel()
        let interruptedAt = ContinuousClock.now
        let received = await consumer.value
        let drainTime = ContinuousClock.now - interruptedAt

        XCTAssertLessThan(drainTime, .seconds(10), "cancellation must not hang until full completion")
        XCTAssertLessThan(received, 20, "cancelled generation should not deliver every chunk")
    }

    // MARK: - Kokoro

    func testKokoroPrepareAndSynthesize() async throws {
        let engine = try await downloadedEngine(ModelManifest.kokoro)
        try await engine.prepare()
        let chunks = try await collectChunks(
            engine: engine,
            text: "Hello from MLXRead. This is the Kokoro model speaking.",
            configuration: SpeechConfiguration(voice: "af_heart")
        )
        assertValidAudio(chunks, expectedRate: 24_000)
        let seconds = chunks.reduce(0.0) { $0 + $1.duration }
        XCTAssertGreaterThan(seconds, 1.0)
    }

    func testKokoroNativeSpeedChangesDuration() async throws {
        let engine = try await downloadedEngine(ModelManifest.kokoro)
        let passage = VoiceOption(id: "af_heart").sampleText
        let normal = try await collectChunks(engine: engine, text: passage,
                                            configuration: SpeechConfiguration(voice: "af_heart", speed: 1.0))
        let faster = try await collectChunks(engine: engine, text: passage,
                                            configuration: SpeechConfiguration(voice: "af_heart", speed: 1.5))
        let restored = try await collectChunks(engine: engine, text: passage,
                                              configuration: SpeechConfiguration(voice: "af_heart", speed: 1.0))
        assertValidAudio(normal, expectedRate: 24_000)
        assertValidAudio(faster, expectedRate: 24_000)
        assertValidAudio(restored, expectedRate: 24_000)
        let normalDuration = normal.reduce(0) { $0 + $1.duration }
        let fasterDuration = faster.reduce(0) { $0 + $1.duration }
        let restoredDuration = restored.reduce(0) { $0 + $1.duration }
        XCTAssertTrue(engine.handlesSpeechSpeed)
        XCTAssertFalse(NativeMLXSpeechEngine(modelInfo: ModelManifest.soprano).handlesSpeechSpeed)
        XCTAssertLessThan(fasterDuration, normalDuration * 0.85)
        XCTAssertEqual(restoredDuration, normalDuration, accuracy: normalDuration * 0.05)
        print("VOICE_RATE|normal_seconds=\(normalDuration)|faster_seconds=\(fasterDuration)|restored_seconds=\(restoredDuration)")
    }

    func testKokoroChunkOrderingForMultiSentenceText() async throws {
        let engine = try await downloadedEngine(ModelManifest.kokoro)
        try await engine.prepare()
        let text = "First sentence for ordering.\n\nSecond paragraph follows here. And a third sentence to be safe."
        let chunks = try await collectChunks(engine: engine, text: text, configuration: SpeechConfiguration(voice: "af_heart"))
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "paragraphs should synthesize as separate chunks")
        XCTAssertEqual(chunks.map(\.index), Array(0..<chunks.count), "chunk indices must be ordered")
    }

    // MARK: - Model download (network)

    func testChatterboxDownloadAndSynthesize() async throws {
        let engine = try await downloadedEngine(ModelManifest.chatterbox)
        let start = ContinuousClock.now
        let chunks = try await collectChunks(
            engine: engine, text: "A good book invites us to discover new ideas. Take a moment to listen.",
            configuration: SpeechConfiguration(language: "en-US")
        )
        assertValidAudio(chunks, expectedRate: 24_000)
        XCTAssertGreaterThan(chunks.reduce(0) { $0 + $1.duration }, 1)
        print("MODEL_VERIFIED|chatterbox|chunks=\(chunks.count)|elapsed=\(ContinuousClock.now - start)")
    }

    func testEveryDownloadedVoiceProducesPreviewAudio() async throws {
        for model in ModelManifest.all {
            let engine = try await downloadedEngine(model)
            let store = await MainActor.run { ModelStore() }
            let voices = await MainActor.run { store.availableVoices(for: model) }
            for voiceID in model.supportsVoices ? voices : ["default"] {
                let voice = model.voiceOption(voiceID)
                let requested = model.supportsIndependentLanguage && model.canRead(voice: voiceID, language: "en-US")
                    ? "en-US" : voice.languageCode
                let language = model.readingLanguage(voice: voiceID, requested: requested)
                let chunks = try await collectChunks(
                    engine: engine, text: VoiceOption.sampleText(language: language),
                    configuration: SpeechConfiguration(voice: model.supportsVoices ? voiceID : nil, language: language)
                )
                assertValidAudio(chunks, expectedRate: model.nominalSampleRate)
                print("VOICE_PREVIEW_VERIFIED|\(model.id)|\(voiceID)|\(language)|chunks=\(chunks.count)")
            }
            await engine.unload()
        }
    }

    func testQwenDownloadAndSynthesize() async throws {
        let engine = try await downloadedEngine(ModelManifest.qwen)
        let start = ContinuousClock.now
        let chunks = try await collectChunks(
            engine: engine, text: "A good book invites us to discover new ideas. Take a moment to listen.",
            configuration: SpeechConfiguration(voice: "ryan", language: "en-US")
        )
        assertValidAudio(chunks, expectedRate: 24_000)
        XCTAssertGreaterThan(chunks.count, 1, "Qwen must deliver incremental audio")
        XCTAssertGreaterThan(chunks.reduce(0) { $0 + $1.duration }, 1)
        print("MODEL_VERIFIED|qwen|chunks=\(chunks.count)|elapsed=\(ContinuousClock.now - start)")
    }

    func testPocketDownloadAndSynthesize() async throws {
        let engine = try await downloadedEngine(ModelManifest.pocket)
        let start = ContinuousClock.now
        let chunks = try await collectChunks(
            engine: engine, text: "A good book invites us to discover new ideas. Take a moment to listen.",
            configuration: SpeechConfiguration(voice: "alba")
        )
        assertValidAudio(chunks, expectedRate: 24_000)
        XCTAssertGreaterThan(chunks.reduce(0) { $0 + $1.duration }, 1)
        print("MODEL_VERIFIED|pocket|chunks=\(chunks.count)|elapsed=\(ContinuousClock.now - start)")
    }

    func testQwenAndPocketCancellationThenReplay() async throws {
        for model in [ModelManifest.qwen, ModelManifest.pocket] {
            let engine = try await downloadedEngine(model)
            try await engine.prepare()
            let configuration = SpeechConfiguration(voice: model.defaultVoice, language: "en-US")
            let consumer = Task {
                try? await self.collectChunks(engine: engine,
                    text: "This preview is interrupted while its decoder is still working. A later sentence must not run.",
                    configuration: configuration)
            }
            try await Task.sleep(for: .milliseconds(300))
            consumer.cancel()
            let stop = ContinuousClock.now
            await engine.cancel()
            _ = await consumer.value
            let chunks = try await collectChunks(engine: engine, text: "The next preview is ready.",
                                                  configuration: configuration)
            assertValidAudio(chunks, expectedRate: model.nominalSampleRate)
            print("MODEL_REPLAY_VERIFIED|\(model.id)|stop_and_replay=\(ContinuousClock.now - stop)")
            await engine.unload()
        }
    }

    func testDownloadDeleteAndRedownloadInIsolatedLibrary() async throws {
        // Real transport and files, without deleting the user's installed models.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("mlxread-model-cycle-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = await MainActor.run { ModelStore(rootDirectory: root) }
        let model = ModelManifest.pocket
        try await download(model, in: store)
        let firstSize = await MainActor.run { store.diskUsageBytes(for: model) }
        XCTAssertGreaterThan(firstSize, 200_000_000)
        try await store.remove(model)
        let deleted = await MainActor.run {
            store.state(for: model) == .notDownloaded && store.diskUsageBytes(for: model) == 0
                && store.availability(for: model, voice: "alba") == .modelRequired
        }
        XCTAssertTrue(deleted)
        try await download(model, in: store)
        let restored = await MainActor.run {
            store.state(for: model) == .downloaded && store.availability(for: model, voice: "alba") == nil
        }
        XCTAssertTrue(restored)
        print("MODEL_VERIFIED|pocket-download-delete-redownload|deleted_bytes=\(firstSize)")
    }

    func testModelDownloadStateMachine() async throws {
        // Runs against whatever is on disk: if absent this exercises a real
        // download; if present it validates the cached path.
        let store = await MainActor.run { ModelStore() }
        let model = ModelManifest.soprano
        let initial = await MainActor.run { store.state(for: model) }
        if initial != .downloaded {
            await MainActor.run { store.download(model) }
            let deadline = Date().addingTimeInterval(1800)
            while Date() < deadline {
                let state = await MainActor.run { store.state(for: model) }
                if state == .downloaded { break }
                if case .failed(let message) = state {
                    return XCTFail("download failed: \(message)")
                }
                try await Task.sleep(for: .seconds(2))
            }
        }
        let final = await MainActor.run { store.state(for: model) }
        XCTAssertEqual(final, .downloaded)
        let usage = await MainActor.run { store.diskUsageBytes(for: model) }
        XCTAssertGreaterThan(usage, 10_000_000, "a real model should occupy tens of MB")
    }
}
