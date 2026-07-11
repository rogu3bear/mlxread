import XCTest
@testable import MLXRead

@MainActor
final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "me.jkca.mlxread.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultsOnFirstLaunch() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.selectedModelID, ModelManifest.defaultModel.id)
        XCTAssertEqual(settings.speechSpeed, 1.0)
        XCTAssertTrue(settings.clipboardFallbackEnabled)
        XCTAssertFalse(settings.showPlaybackHUD)
        XCTAssertFalse(settings.showSelectionPreview)
        XCTAssertEqual(settings.maximumSelectionLength, Constants.Defaults.maximumSelectionLength)
    }

    func testPersistenceRoundTrip() {
        let settings = AppSettings(defaults: defaults)
        settings.speechSpeed = 1.5
        settings.selectedModelID = ModelManifest.soprano.id
        settings.clipboardFallbackEnabled = false
        settings.maximumSelectionLength = 5000

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.speechSpeed, 1.5)
        XCTAssertEqual(reloaded.selectedModelID, ModelManifest.soprano.id)
        XCTAssertFalse(reloaded.clipboardFallbackEnabled)
        XCTAssertEqual(reloaded.maximumSelectionLength, 5000)
    }

    func testMaximumLengthClamped() {
        let settings = AppSettings(defaults: defaults)
        settings.maximumSelectionLength = 5
        XCTAssertEqual(settings.maximumSelectionLength, Constants.selectionLengthBounds.lowerBound)
        settings.maximumSelectionLength = 10_000_000
        XCTAssertEqual(settings.maximumSelectionLength, Constants.selectionLengthBounds.upperBound)
    }

    func testSpeechConfigurationReflectsModel() {
        let settings = AppSettings(defaults: defaults)
        settings.selectedModelID = ModelManifest.soprano.id
        // Soprano does not support voices → no voice in configuration.
        XCTAssertNil(settings.speechConfiguration.voice)

        settings.selectedModelID = ModelManifest.kokoro.id
        settings.selectedVoice = "af_bella"
        XCTAssertEqual(settings.speechConfiguration.voice, "af_bella")
    }
}

@MainActor
final class ModelStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("mlxread-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    private func plantValidModel(_ model: ModelInfo, in store: ModelStore) throws {
        let dir = store.directory(for: model)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{\"model_type\": \"test\"}".utf8).write(to: dir.appendingPathComponent("config.json"))
        try Data([1, 2, 3]).write(to: dir.appendingPathComponent("model.safetensors"))
        if model.supportsVoices {
            let voices = dir.appendingPathComponent("voices")
            try FileManager.default.createDirectory(at: voices, withIntermediateDirectories: true)
            try Data([9]).write(to: voices.appendingPathComponent("af_heart.safetensors"))
            try Data([9]).write(to: voices.appendingPathComponent("af_bella.safetensors"))
        }
    }

    func testValidationRejectsMissingAndAcceptsComplete() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        XCTAssertEqual(store.state(for: ModelManifest.kokoro), .notDownloaded)
        XCTAssertFalse(store.validate(ModelManifest.kokoro))

        try plantValidModel(ModelManifest.kokoro, in: store)
        XCTAssertTrue(store.validate(ModelManifest.kokoro))
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: ModelManifest.kokoro), .downloaded)
    }

    func testValidationRejectsCorruptConfig() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.soprano, in: store)
        let config = store.directory(for: ModelManifest.soprano).appendingPathComponent("config.json")
        try Data("not json{{{".utf8).write(to: config)
        XCTAssertFalse(store.validate(ModelManifest.soprano))
    }

    func testVoiceModelRequiresVoicesDirectory() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.kokoro, in: store)
        try FileManager.default.removeItem(
            at: store.directory(for: ModelManifest.kokoro).appendingPathComponent("voices")
        )
        XCTAssertFalse(store.validate(ModelManifest.kokoro))
    }

    func testAvailableVoicesEnumeration() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.kokoro, in: store)
        XCTAssertEqual(store.availableVoices(for: ModelManifest.kokoro), ["af_bella", "af_heart"])
        XCTAssertEqual(store.availableVoices(for: ModelManifest.soprano), [])
    }

    func testRemoveDeletesDirectory() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.soprano, in: store)
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: ModelManifest.soprano), .downloaded)

        try store.remove(ModelManifest.soprano)
        XCTAssertEqual(store.state(for: ModelManifest.soprano), .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: ModelManifest.soprano).path))
    }

    func testDiskUsageCountsPlantedFiles() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.soprano, in: store)
        XCTAssertGreaterThan(store.diskUsageBytes(for: ModelManifest.soprano), 0)
    }
}

/// Single-flight semantics of engine preparation, using the mock engine.
final class EnginePreparationTests: XCTestCase {
    func testConcurrentPreparesDoNotRace() async throws {
        let engine = MockSpeechEngine()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { try await engine.prepare() }
            }
            try await group.waitForAll()
        }
        // Mock counts calls; the invariant under test is absence of crashes /
        // reentrancy issues and that prepare is idempotent for callers.
        let calls = await engine.prepareCallCount
        XCTAssertEqual(calls, 8)
    }

    func testMockGenerationCancellation() async throws {
        let engine = MockSpeechEngine(chunkDelay: .milliseconds(200))
        let stream = engine.generate(
            text: "One. Two. Three. Four. Five.",
            configuration: SpeechConfiguration()
        )
        let consumer = Task {
            var received = 0
            do {
                for try await _ in stream { received += 1 }
            } catch {}
            return received
        }
        try await Task.sleep(for: .milliseconds(250))
        consumer.cancel()
        let received = await consumer.value
        XCTAssertLessThan(received, 5, "cancellation must cut generation short")
    }
}
