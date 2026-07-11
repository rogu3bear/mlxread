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
        let engine = NativeMLXSpeechEngine(modelInfo: ModelManifest.soprano)
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
        let engine = NativeMLXSpeechEngine(modelInfo: ModelManifest.soprano)
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
        let engine = NativeMLXSpeechEngine(modelInfo: ModelManifest.soprano)
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
        let engine = NativeMLXSpeechEngine(modelInfo: ModelManifest.kokoro)
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

    func testKokoroChunkOrderingForMultiSentenceText() async throws {
        let engine = NativeMLXSpeechEngine(modelInfo: ModelManifest.kokoro)
        try await engine.prepare()
        let text = "First sentence for ordering.\n\nSecond paragraph follows here. And a third sentence to be safe."
        let chunks = try await collectChunks(engine: engine, text: text, configuration: SpeechConfiguration(voice: "af_heart"))
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "paragraphs should synthesize as separate chunks")
        XCTAssertEqual(chunks.map(\.index), Array(0..<chunks.count), "chunk indices must be ordered")
    }

    // MARK: - Model download (network)

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
