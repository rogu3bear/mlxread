import XCTest
@testable import MLXRead

// MARK: - Test doubles

final class FakeSelectionReader: SelectionCapturing, @unchecked Sendable {
    var result: SelectionCaptureResult = .text("Hello world.", source: .accessibility)
    var delay: Duration = .zero

    func captureSelection() async -> SelectionCaptureResult {
        if delay > .zero {
            try? await Task.sleep(for: delay)
        }
        return result
    }
}

/// Records the player calls and enforces session identity like the real one.
actor FakeAudioPlayer: AudioPlaying {
    private(set) var startedSessions: [UUID] = []
    private(set) var enqueuedChunks: [(UUID, Int)] = []
    private(set) var finishedSessions: [UUID] = []
    private(set) var stopCount = 0
    private(set) var playbackSpeeds: [Double] = []
    private var activeSession: UUID?

    func startSession(_ id: UUID, speed: Double) async throws {
        activeSession = id
        startedSessions.append(id)
        playbackSpeeds.append(speed)
    }

    func enqueue(_ chunk: SpeechAudioChunk, session: UUID) async throws {
        guard session == activeSession else { return }
        enqueuedChunks.append((session, chunk.index))
    }

    func finishSession(_ id: UUID) async {
        guard id == activeSession else { return }
        finishedSessions.append(id)
        activeSession = nil
    }

    func stopImmediately() async {
        stopCount += 1
        activeSession = nil
    }
}

/// Engine whose generation can be held open until told to proceed.
actor GatedEngine: SpeechEngine {
    nonisolated let identifier = "gated"
    nonisolated let displayName = "Gated"
    nonisolated let sampleRate: Double = 24_000
    nonisolated let handlesSpeechSpeed: Bool

    private(set) var prepareCount = 0
    private(set) var cancelCount = 0
    private(set) var receivedConfigurations: [SpeechConfiguration] = []
    let chunkCount: Int
    let chunkDelay: Duration

    init(chunkCount: Int = 3, chunkDelay: Duration = .milliseconds(20), handlesSpeechSpeed: Bool = false) {
        self.chunkCount = chunkCount
        self.chunkDelay = chunkDelay
        self.handlesSpeechSpeed = handlesSpeechSpeed
    }

    func prepare() async throws {
        prepareCount += 1
    }

    nonisolated func generate(
        text: String,
        configuration: SpeechConfiguration
    ) -> AsyncThrowingStream<SpeechAudioChunk, Error> {
        let count = chunkCount
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                await self.record(configuration)
                for i in 0..<count {
                    do {
                        try await Task.sleep(for: delay)
                        try Task.checkCancellation()
                    } catch {
                        continuation.finish(throwing: CancellationError())
                        return
                    }
                    continuation.yield(SpeechAudioChunk(samples: [0.1, 0.2], sampleRate: 24_000, index: i))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func cancel() async {
        cancelCount += 1
    }

    private func record(_ configuration: SpeechConfiguration) { receivedConfigurations.append(configuration) }
}

// MARK: - Tests

@MainActor
final class SpeechCoordinatorTests: XCTestCase {

    private func makeCoordinator(
        selection: FakeSelectionReader = FakeSelectionReader(),
        player: FakeAudioPlayer = FakeAudioPlayer(),
        engine: any SpeechEngine
    ) -> SpeechCoordinator {
        SpeechCoordinator(
            selection: selection,
            player: player,
            engineProvider: { engine },
            configurationProvider: { SpeechConfiguration() },
            maximumLengthProvider: { 1000 }
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func testHappyPathTransitionsAndPlaysAllChunks() async throws {
        let player = FakeAudioPlayer()
        let engine = GatedEngine(chunkCount: 3)
        let coordinator = makeCoordinator(player: player, engine: engine)

        XCTAssertEqual(coordinator.state, .idle)
        coordinator.beginReadingSelection()
        XCTAssertTrue(coordinator.state.isBusy)

        try await waitUntil { coordinator.state == .idle }
        let chunks = await player.enqueuedChunks
        let finished = await player.finishedSessions
        XCTAssertEqual(chunks.count, 3)
        XCTAssertEqual(chunks.map(\.1), [0, 1, 2], "chunks must play in order")
        XCTAssertEqual(finished.count, 1)
    }

    func testSampleRequiresModelButNotSelectionPermission() async throws {
        let engine = GatedEngine(chunkCount: 1)
        let coordinator = makeCoordinator(engine: engine)
        coordinator.availabilityCheck = { .permissionRequired }
        coordinator.sampleAvailabilityCheck = { _ in .modelRequired }
        coordinator.speakSample("A local preview.")
        XCTAssertEqual(coordinator.state, .modelRequired)
        let prepareCount = await engine.prepareCount
        XCTAssertEqual(prepareCount, 0)

        coordinator.sampleAvailabilityCheck = { _ in nil }
        coordinator.speakSample("A local preview.")
        XCTAssertEqual(coordinator.state, .preparing)
        try await waitUntil { !coordinator.state.isBusy }
        let prepared = await engine.prepareCount
        XCTAssertEqual(prepared, 1)
        XCTAssertEqual(coordinator.state, .permissionRequired)
    }

    func testEmptyPreviewDoesNotStartAnEngine() async throws {
        let engine = GatedEngine()
        let coordinator = makeCoordinator(engine: engine)
        coordinator.speakSample(" \n ")
        XCTAssertEqual(coordinator.state, .idle)
        let prepareCount = await engine.prepareCount
        XCTAssertEqual(prepareCount, 0)
    }

    func testPreviewUsesItsOwnVoiceThenReadingKeepsTheSavedVoice() async throws {
        let engine = GatedEngine(chunkCount: 1)
        let saved = SpeechConfiguration(voice: "ryan", language: "en-US", delivery: .natural)
        let preview = SpeechConfiguration(voice: "aiden", language: "en-US", delivery: .narration)
        let coordinator = SpeechCoordinator(
            selection: FakeSelectionReader(), player: FakeAudioPlayer(),
            engineProvider: { engine }, configurationProvider: { saved }
        )
        var checkedVoice: String?
        coordinator.sampleAvailabilityCheck = { configuration in
            checkedVoice = configuration.voice
            return nil
        }
        coordinator.speakSample("Compare this voice.", configuration: preview)
        XCTAssertEqual(checkedVoice, "aiden")
        XCTAssertEqual(coordinator.activeConfiguration, preview)
        try await waitUntil { !coordinator.state.isBusy }
        coordinator.beginReadingSelection()
        XCTAssertEqual(coordinator.activeConfiguration, saved)
        try await waitUntil { !coordinator.state.isBusy }
        let received = await engine.receivedConfigurations
        XCTAssertEqual(received, [preview, saved])
    }

    func testNativeSpeedIsNotAppliedTwiceAndConfigurationIsFrozen() async throws {
        for nativeSpeed in [true, false] {
            let player = FakeAudioPlayer()
            let engine = GatedEngine(chunkCount: 1, handlesSpeechSpeed: nativeSpeed)
            var chosenSpeed = 1.5
            let coordinator = SpeechCoordinator(
                selection: FakeSelectionReader(), player: player,
                engineProvider: { engine },
                configurationProvider: { SpeechConfiguration(speed: chosenSpeed) }
            )
            coordinator.speakSample("A stable preview.")
            chosenSpeed = 0.8
            XCTAssertEqual(coordinator.activeConfiguration?.speed, 1.5)
            try await waitUntil { coordinator.state == .idle }
            let speeds = await player.playbackSpeeds
            XCTAssertEqual(speeds, [nativeSpeed ? 1.0 : 1.5])
            XCTAssertNil(coordinator.activeConfiguration)
        }
    }

    func testStopCancelsTheEngineThatStartedTheRead() async throws {
        let original = GatedEngine(chunkCount: 50, chunkDelay: .milliseconds(50))
        let replacement = GatedEngine()
        var selected: any SpeechEngine = original
        let coordinator = SpeechCoordinator(
            selection: FakeSelectionReader(), player: FakeAudioPlayer(),
            engineProvider: { selected }, configurationProvider: { SpeechConfiguration() }
        )
        coordinator.speakSample("Keep the original reading cancellable.")
        try await waitUntil { coordinator.state == .playing }
        selected = replacement
        coordinator.stop()
        try await waitUntil { coordinator.state == .idle }
        let originalCancellations = await original.cancelCount
        let replacementCancellations = await replacement.cancelCount
        XCTAssertEqual(originalCancellations, 1)
        XCTAssertEqual(replacementCancellations, 0)
    }

    func testStopDuringGenerationCancelsAndReturnsToIdle() async throws {
        let player = FakeAudioPlayer()
        let engine = GatedEngine(chunkCount: 50, chunkDelay: .milliseconds(30))
        let coordinator = makeCoordinator(player: player, engine: engine)

        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .playing || coordinator.state == .generating }

        coordinator.toggle() // second Option–Escape
        try await waitUntil { coordinator.state == .idle }

        let stops = await player.stopCount
        let cancels = await engine.cancelCount
        XCTAssertGreaterThanOrEqual(stops, 1)
        XCTAssertGreaterThanOrEqual(cancels, 1)
        let enqueued = await player.enqueuedChunks
        XCTAssertLessThan(enqueued.count, 50, "generation should have been cut short")
    }

    func testToggleStartsWhenIdleAndStopsWhenBusy() async throws {
        let engine = GatedEngine(chunkCount: 100, chunkDelay: .milliseconds(20))
        let coordinator = makeCoordinator(engine: engine)

        coordinator.toggle()
        XCTAssertTrue(coordinator.state.isBusy)
        try await waitUntil { coordinator.state == .playing || coordinator.state == .generating }
        coordinator.toggle()
        try await waitUntil { coordinator.state == .idle }
    }

    func testStaleGenerationChunksNeverReachNewSession() async throws {
        let player = FakeAudioPlayer()
        let engine = GatedEngine(chunkCount: 30, chunkDelay: .milliseconds(15))
        let coordinator = makeCoordinator(player: player, engine: engine)

        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .playing || coordinator.state == .generating }
        let firstSession = await player.startedSessions.first

        coordinator.stop()
        try await waitUntil { coordinator.state == .idle }

        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .idle }

        let sessions = await player.startedSessions
        XCTAssertEqual(sessions.count, 2)
        let chunks = await player.enqueuedChunks
        let secondSession = sessions[1]
        // After the second session started, no chunk tagged with the first
        // session may appear later in the enqueue log.
        if let lastFirstIdx = chunks.lastIndex(where: { $0.0 == firstSession }),
           let firstSecondIdx = chunks.firstIndex(where: { $0.0 == secondSession }) {
            XCTAssertLessThan(lastFirstIdx, firstSecondIdx, "stale chunk leaked into newer session")
        }
    }

    func testNoSelectionProducesFailedState() async throws {
        let selection = FakeSelectionReader()
        selection.result = .noSelection
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine())

        coordinator.beginReadingSelection()
        try await waitUntil {
            if case .failed(let err) = coordinator.state { return err == .noSelectionFound }
            return false
        }
    }

    func testPermissionDeniedMapsToPermissionError() async throws {
        let selection = FakeSelectionReader()
        selection.result = .permissionDenied
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine())

        coordinator.beginReadingSelection()
        try await waitUntil {
            if case .failed(let err) = coordinator.state { return err == .accessibilityPermissionMissing }
            return false
        }
    }

    func testEmptyNormalizedTextFails() async throws {
        let selection = FakeSelectionReader()
        selection.result = .text("   \n\u{200B}  ", source: .accessibility)
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine())

        coordinator.beginReadingSelection()
        try await waitUntil {
            if case .failed(let err) = coordinator.state { return err == .noSelectionFound }
            return false
        }
    }

    func testAvailabilityGatePermission() {
        let coordinator = makeCoordinator(engine: GatedEngine())
        coordinator.availabilityCheck = { .permissionRequired }
        coordinator.refreshAvailability()
        XCTAssertEqual(coordinator.state, .permissionRequired)
        // beginReading must refuse to start.
        coordinator.beginReadingSelection()
        XCTAssertEqual(coordinator.state, .permissionRequired)
    }

    func testUnchangedAvailabilityPreservesReadingErrorUntilRetry() async throws {
        let selection = FakeSelectionReader()
        selection.result = .noSelection
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine(chunkCount: 1))
        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .failed(.noSelectionFound) }

        // Model download progress invokes this same refresh without changing readiness.
        for _ in 0..<3 {
            coordinator.refreshAvailability()
            XCTAssertEqual(coordinator.state, .failed(.noSelectionFound))
        }

        selection.result = .text("Try reading again.", source: .accessibility)
        coordinator.beginReadingSelection()
        XCTAssertTrue(coordinator.state.isBusy)
        try await waitUntil { coordinator.state == .idle }
    }

    func testAvailabilityChangeReplacesReadingError() async throws {
        let selection = FakeSelectionReader()
        selection.result = .noSelection
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine())
        var gate: SpeechState?
        coordinator.availabilityCheck = { gate }
        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .failed(.noSelectionFound) }

        gate = .modelRequired
        coordinator.refreshAvailability()
        XCTAssertEqual(coordinator.state, .modelRequired)
        gate = nil
        coordinator.refreshAvailability()
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testExplicitModelSelectionCanClearReadingError() async throws {
        let selection = FakeSelectionReader()
        selection.result = .noSelection
        let coordinator = makeCoordinator(selection: selection, engine: GatedEngine())
        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .failed(.noSelectionFound) }
        coordinator.refreshAvailability(clearFailure: true)
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testPreviewErrorSurvivesUnchangedSelectionPermission() async throws {
        let coordinator = makeCoordinator(engine: GatedEngine(chunkCount: 0))
        coordinator.availabilityCheck = { .permissionRequired }
        coordinator.speakSample("The model produces no audio for this preview.")
        let expected = SpeechState.failed(.synthesisFailed("the model produced no audio"))
        try await waitUntil { coordinator.state == expected }
        coordinator.refreshAvailability()
        XCTAssertEqual(coordinator.state, expected)
    }

    func testEnginePrepareReusedAcrossReads() async throws {
        let engine = GatedEngine(chunkCount: 1, chunkDelay: .zero)
        let coordinator = makeCoordinator(engine: engine)

        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .idle && !coordinator.state.isBusy }
        coordinator.beginReadingSelection()
        try await waitUntil { coordinator.state == .idle }

        let prepares = await engine.prepareCount
        XCTAssertEqual(prepares, 2, "prepare called per read; engine itself deduplicates real work")
    }
}
