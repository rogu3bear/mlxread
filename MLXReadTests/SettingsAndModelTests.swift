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

    func testSwitchingModelsRestoresChosenVoice() {
        let settings = AppSettings(defaults: defaults)
        settings.selectedVoice = "bf_emma"
        settings.selectModel(ModelManifest.soprano)
        XCTAssertNil(settings.speechConfiguration.voice)
        settings.selectModel(ModelManifest.kokoro)
        XCTAssertEqual(settings.selectedVoice, "bf_emma")
        settings.selectModel(ModelManifest.soprano)
        let reloaded = AppSettings(defaults: defaults)
        reloaded.selectModel(ModelManifest.kokoro)
        XCTAssertEqual(reloaded.selectedVoice, "bf_emma")
    }

    func testSpeedStaysWithinSupportedRange() {
        let settings = AppSettings(defaults: defaults)
        settings.speechSpeed = 20
        XCTAssertEqual(settings.speechSpeed, 2)
        settings.speechSpeed = -1
        XCTAssertEqual(settings.speechSpeed, 0.5)
        settings.speechSpeed = .nan
        XCTAssertEqual(settings.speechSpeed, 1)
        defaults.set(4.0, forKey: Constants.DefaultsKey.speechSpeed)
        XCTAssertEqual(AppSettings(defaults: defaults).speechSpeed, 2)
    }


}

final class VoiceOptionTests: XCTestCase {
    func testVoiceLabelsAndLanguageSamples() {
        XCTAssertEqual(VoiceOption(id: "af_heart").name, "Heart")
        XCTAssertEqual(VoiceOption(id: "bf_emma").languageName, "English (UK)")
        XCTAssertEqual(VoiceOption(id: "pf_dora").menuLabel, "Dora · Portuguese (Brazil)")
        XCTAssertNotEqual(VoiceOption(id: "ff_siwis").sampleText, VoiceOption(id: "af_heart").sampleText)
        XCTAssertEqual(VoiceOption(id: "af_bella").sampleText, VoiceOption(id: "af_heart").sampleText)
        XCTAssertEqual(VoiceOption(id: "custom_voice").name, "custom_voice")
        XCTAssertEqual(VoiceOption(id: "custom_voice").languageCode, "other")
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

    func testPartialCatalogPreservesVoiceAndGatesReadingAcrossRefreshAndRestart() async throws {
        let suite = "me.jkca.mlxread.catalog-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.selectModel(ModelManifest.kokoro)
        settings.selectedVoice = "bf_emma"
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.kokoro, in: store)

        let engine = GatedEngine(chunkCount: 1, chunkDelay: .zero)
        let coordinator = SpeechCoordinator(
            selection: FakeSelectionReader(), player: FakeAudioPlayer(),
            engineProvider: { engine }, configurationProvider: { settings.speechConfiguration }
        )
        coordinator.availabilityCheck = {
            store.availability(for: settings.selectedModel, voice: settings.speechConfiguration.voice)
        }
        coordinator.sampleAvailabilityCheck = coordinator.availabilityCheck
        store.onStateChange = { coordinator.refreshAvailability() }

        // Config, weights and two other voices satisfy the legacy model check.
        // The real refresh producer must still gate the absent saved voice.
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: ModelManifest.kokoro), .downloaded)
        XCTAssertEqual(coordinator.state, .voiceRequired)
        coordinator.beginReadingSelection()
        coordinator.speakSample("Do not silently substitute a different voice.")
        let blockedPrepareCount = await engine.prepareCount
        XCTAssertEqual(blockedPrepareCount, 0)
        XCTAssertEqual(AppSettings(defaults: defaults).selectedVoice, "bf_emma")

        let reopened = ModelStore(rootDirectory: tempRoot)
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(reopened.availability(for: restored.selectedModel, voice: restored.speechConfiguration.voice), .voiceRequired)
        XCTAssertEqual(restored.selectedVoice, "bf_emma")

        // When the missing file arrives, the same refresh releases the gate.
        let voiceFile = store.directory(for: ModelManifest.kokoro)
            .appendingPathComponent("voices/bf_emma.safetensors")
        try Data([9]).write(to: voiceFile)
        store.refreshAllStates()
        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(settings.selectedVoice, "bf_emma")
        coordinator.speakSample("The chosen voice is now available.")
        let deadline = Date().addingTimeInterval(5)
        while coordinator.state.isBusy && Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(coordinator.state, .idle)
        let prepared = await engine.prepareCount
        XCTAssertEqual(prepared, 1)
    }

    func testExplicitVoiceChoiceRecoversFromPartialCatalog() throws {
        let suite = "me.jkca.mlxread.catalog-tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.selectModel(ModelManifest.kokoro)
        settings.selectedVoice = "bf_emma"
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.kokoro, in: store)
        store.refreshAllStates()
        XCTAssertEqual(store.availability(for: settings.selectedModel, voice: settings.speechConfiguration.voice), .voiceRequired)

        settings.selectedVoice = "af_bella"
        store.refreshAllStates()
        XCTAssertNil(store.availability(for: settings.selectedModel, voice: settings.speechConfiguration.voice))
        XCTAssertEqual(AppSettings(defaults: defaults).selectedVoice, "af_bella")
    }

    func testEmptyVoiceFileIsUnavailable() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.kokoro, in: store)
        let voiceFile = store.directory(for: ModelManifest.kokoro)
            .appendingPathComponent("voices/bf_emma.safetensors")
        try Data().write(to: voiceFile)
        store.refreshAllStates()
        XCTAssertFalse(store.availableVoices(for: ModelManifest.kokoro).contains("bf_emma"))
        XCTAssertEqual(store.availability(for: ModelManifest.kokoro, voice: "bf_emma"), .voiceRequired)

        // Cache layouts may expose completed files through symbolic links.
        try FileManager.default.removeItem(at: voiceFile)
        try FileManager.default.createSymbolicLink(
            at: voiceFile, withDestinationURL: voiceFile.deletingLastPathComponent().appendingPathComponent("af_heart.safetensors")
        )
        XCTAssertTrue(store.availableVoices(for: ModelManifest.kokoro).contains("bf_emma"))
        XCTAssertNil(store.availability(for: ModelManifest.kokoro, voice: "bf_emma"))
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
