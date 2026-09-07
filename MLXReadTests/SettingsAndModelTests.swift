import XCTest
@testable import MLXRead

final class SingleInstanceLockTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mlxread-launch-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testOnlyOneOwnerUntilTheLockIsReleased() throws {
        let url = root.appendingPathComponent("instance.lock")
        var owner: SingleInstanceLock? = try XCTUnwrap(SingleInstanceLock.acquire(at: url))
        try withExtendedLifetime(owner) {
            XCTAssertNil(try SingleInstanceLock.acquire(at: url))
        }
        owner = nil
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let replacement = try XCTUnwrap(SingleInstanceLock.acquire(at: url))
        try withExtendedLifetime(replacement) {
            XCTAssertNil(try SingleInstanceLock.acquire(at: url))
        }
    }

    func testExistingFileWithoutALiveLockDoesNotBlockLaunch() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("instance.lock")
        try Data("left over after a prior launch".utf8).write(to: url)
        XCTAssertNotNil(try SingleInstanceLock.acquire(at: url))
    }

    func testFilesystemFailureThrowsInsteadOfAdmittingALaunch() throws {
        try Data().write(to: root)
        XCTAssertThrowsError(try SingleInstanceLock.acquire(at: root.appendingPathComponent("instance.lock")))
    }
}

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
        XCTAssertEqual(settings.speechConfiguration.language, "en-US")
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

    func testEachModelRestoresItsVoiceAndQwenLanguage() {
        let settings = AppSettings(defaults: defaults)
        settings.selectedVoice = "bf_emma"
        settings.selectModel(ModelManifest.qwen)
        settings.selectedVoice = "serena"
        settings.selectedLanguage = "de"
        XCTAssertEqual(settings.speechConfiguration.language, "de")
        settings.selectModel(ModelManifest.pocket)
        settings.selectedVoice = "marius"
        XCTAssertEqual(settings.speechConfiguration.language, "en-US")
        settings.selectModel(ModelManifest.qwen)
        XCTAssertEqual(settings.selectedVoice, "serena")
        XCTAssertEqual(settings.selectedLanguage, "de")
        let restored = AppSettings(defaults: defaults)
        XCTAssertEqual(restored.speechConfiguration.language, "de")
        restored.selectModel(ModelManifest.pocket)
        XCTAssertEqual(restored.selectedVoice, "marius")
        restored.selectModel(ModelManifest.kokoro)
        XCTAssertEqual(restored.selectedVoice, "bf_emma")
    }

    func testEnglishIsIndependentOfQwenVoiceAndDeliveryPersists() {
        let settings = AppSettings(defaults: defaults)
        settings.selectModel(ModelManifest.qwen)
        settings.selectedVoice = "sohee"
        settings.speechDelivery = .narration
        XCTAssertEqual(settings.speechConfiguration.language, "en-US")
        XCTAssertTrue(settings.speechConfiguration.qwenVoicePrompt.hasPrefix("sohee, "))
        XCTAssertTrue(settings.speechConfiguration.qwenVoicePrompt.contains("audiobook narrator"))
        XCTAssertEqual(AppSettings(defaults: defaults).speechDelivery, .narration)
        settings.selectModel(ModelManifest.kokoro)
        settings.selectedVoice = "bf_emma"
        XCTAssertEqual(settings.speechConfiguration.language, "en-GB")
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
        try plantCatalogModel(model, directory: store.directory(for: model))
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

    func testChatterboxRequiresItsCodecAndDeleteRemovesEveryAsset() async throws {
        let model = ModelManifest.chatterbox
        let store = ModelStore(rootDirectory: tempRoot)
        try plantCatalogModel(model, directory: store.directory(for: model))
        XCTAssertFalse(store.validate(model), "The native loader requires a separately distributed codec")
        for asset in model.additionalDownloads {
            let dir = tempRoot.appendingPathComponent(asset.cacheSubdirectory)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: dir.appendingPathComponent("config.json"))
            try Data([1, 2, 3]).write(to: dir.appendingPathComponent("model.safetensors"))
        }
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: model), .downloaded)
        try await store.remove(model)
        XCTAssertEqual(store.state(for: model), .notDownloaded)
        XCTAssertEqual(store.diskUsageBytes(for: model), 0)
        for asset in model.downloads {
            XCTAssertFalse(FileManager.default.fileExists(atPath: tempRoot.appendingPathComponent(asset.cacheSubdirectory).path))
        }
    }

    func testQwenDialectVoicesCannotOverrideEnglishReading() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantCatalogModel(ModelManifest.qwen, directory: store.directory(for: ModelManifest.qwen))
        store.refreshAllStates()
        for voice in ["dylan", "eric"] {
            XCTAssertEqual(store.availability(for: ModelManifest.qwen, voice: voice, language: "en-US"), .voiceRequired)
            XCTAssertNil(store.availability(for: ModelManifest.qwen, voice: voice, language: "zh"))
        }
        XCTAssertNil(store.availability(for: ModelManifest.qwen, voice: "sohee", language: "en-US"))
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
        coordinator.sampleAvailabilityCheck = { configuration in
            store.availability(for: settings.selectedModel, voice: configuration.voice, language: configuration.language)
        }
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

    func testRemoveDeletesDirectory() async throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.soprano, in: store)
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: ModelManifest.soprano), .downloaded)

        try await store.remove(ModelManifest.soprano)
        XCTAssertEqual(store.state(for: ModelManifest.soprano), .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: ModelManifest.soprano).path))
    }

    func testDiskUsageCountsPlantedFiles() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.soprano, in: store)
        XCTAssertGreaterThan(store.diskUsageBytes(for: ModelManifest.soprano), 0)
    }

    func testQwenNeedsSpeechDecoderAndUsesPresetVoices() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        let model = ModelManifest.qwen
        try plantValidModel(model, in: store)
        XCTAssertTrue(store.validate(model))
        XCTAssertTrue(store.availableVoices(for: model).contains("ryan"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: model).appendingPathComponent("voices").path))
        try FileManager.default.removeItem(at: store.directory(for: model).appendingPathComponent("speech_tokenizer/model.safetensors"))
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: model), .incomplete)
        XCTAssertEqual(store.availability(for: model, voice: "ryan"), .modelRequired)
    }

    func testPocketUsesEmbeddingsAndGatesMissingSavedVoice() throws {
        let store = ModelStore(rootDirectory: tempRoot)
        let model = ModelManifest.pocket
        try plantValidModel(model, in: store)
        store.refreshAllStates()
        XCTAssertEqual(store.availableVoices(for: model), ["alba", "marius"])
        XCTAssertEqual(model.voiceOption("alba").languageCode, "en-US")
        XCTAssertNil(store.availability(for: model, voice: "alba"))
        XCTAssertEqual(store.availability(for: model, voice: "cosette"), .voiceRequired)
        try FileManager.default.removeItem(at: store.directory(for: model).appendingPathComponent("tokenizer.json"))
        store.refreshAllStates()
        XCTAssertEqual(store.state(for: model), .incomplete)
    }

    func testDownloadProgressCompletionDeletionAndRetry() async throws {
        let downloader = ControlledModelDownloader()
        let store = ModelStore(rootDirectory: tempRoot, downloader: downloader)
        let model = ModelManifest.pocket
        store.download(model)
        store.download(model)
        try await waitFor { await downloader.starts == 1 }
        await downloader.report(.nan, operation: 0)
        XCTAssertEqual(store.state(for: model), .downloading(fraction: 0))
        await downloader.report(0.42, operation: 0)
        XCTAssertEqual(store.state(for: model), .downloading(fraction: 0.42))
        await downloader.finish(writeFiles: true)
        try await waitFor { await MainActor.run { store.state(for: model) == .downloaded } }
        XCTAssertNil(store.availability(for: model, voice: "alba"))
        XCTAssertEqual(ModelStore(rootDirectory: tempRoot).state(for: model), .downloaded)
        try await store.remove(model)
        XCTAssertEqual(store.state(for: model), .notDownloaded)
        XCTAssertEqual(store.diskUsageBytes(for: model), 0)
        XCTAssertEqual(store.availability(for: model, voice: "alba"), .modelRequired)
        store.download(model)
        try await waitFor { await downloader.starts == 2 }
        await downloader.report(0.9, operation: 0)
        XCTAssertEqual(store.state(for: model), .downloading(fraction: 0), "old progress must not affect a new download")
        await downloader.finish(writeFiles: true)
        try await waitFor { await MainActor.run { store.state(for: model) == .downloaded } }
    }

    func testDeleteWaitsForCancelledWriterBeforeRemovingFiles() async throws {
        let downloader = ControlledModelDownloader()
        let store = ModelStore(rootDirectory: tempRoot, downloader: downloader)
        let model = ModelManifest.pocket
        store.download(model)
        try await waitFor { await downloader.starts == 1 }
        let deletion = Task { try await store.remove(model) }
        try await waitFor { await MainActor.run { store.state(for: model) == .deleting } }
        store.download(model)
        await downloader.report(0.8, operation: 0)
        XCTAssertEqual(store.state(for: model), .deleting)
        // The transport deliberately writes after cancellation to model an
        // already in-flight file completion. Deletion must await and remove it.
        await downloader.finish(writeFiles: true)
        try await deletion.value
        let starts = await downloader.starts
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(store.state(for: model), .notDownloaded)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.directory(for: model).path))
    }

    func testCancellationIsVisibleUntilWriterFinishesAndCanRetry() async throws {
        let downloader = ControlledModelDownloader()
        let store = ModelStore(rootDirectory: tempRoot, downloader: downloader)
        let model = ModelManifest.pocket
        store.download(model)
        try await waitFor { await downloader.starts == 1 }
        store.cancelDownload(model)
        XCTAssertEqual(store.state(for: model), .cancelling)
        await downloader.finish(writeFiles: false)
        try await waitFor { await MainActor.run { store.state(for: model) == .notDownloaded } }
        store.download(model)
        try await waitFor { await downloader.starts == 2 }
        await downloader.finish(writeFiles: true)
        try await waitFor { await MainActor.run { store.state(for: model) == .downloaded } }
    }

    func testModelCacheKeepsOneEngineAndReleasesDeletedModel() async throws {
        let store = ModelStore(rootDirectory: tempRoot)
        try plantValidModel(ModelManifest.pocket, in: store)
        store.refreshAllStates()
        let cache = EngineCache()
        let kokoro = cache.engine(for: ModelManifest.kokoro)
        XCTAssertEqual(kokoro.identifier, ModelManifest.kokoro.id)
        _ = cache.engine(for: ModelManifest.pocket)
        XCTAssertEqual(cache.engine?.identifier, ModelManifest.pocket.id)
        store.onStateChange = { cache.releaseUnavailableModels(in: store) }
        try await store.remove(ModelManifest.pocket)
        XCTAssertNil(cache.engine)
    }
}

private func plantCatalogModel(_ model: ModelInfo, directory: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    for path in ["config.json", "model.safetensors"] + model.requiredFiles {
        let file = directory.appendingPathComponent(path)
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = file.pathExtension == "json" ? Data("{\"model_type\":\"test\"}".utf8) : Data([1, 2, 3])
        try data.write(to: file)
    }
    if let folder = model.voiceCatalog.directory {
        let voices = directory.appendingPathComponent(folder)
        try fm.createDirectory(at: voices, withIntermediateDirectories: true)
        let names = model.id == ModelManifest.pocket.id ? ["alba", "marius"] : ["af_heart", "af_bella"]
        for name in names { try Data([9]).write(to: voices.appendingPathComponent("\(name).safetensors")) }
    }
}

private actor ControlledModelDownloader: ModelDownloading {
    private(set) var starts = 0
    private var completion: CheckedContinuation<Bool, Never>?
    private var progressHandlers: [@MainActor @Sendable (Double) -> Void] = []

    func download(_ model: ModelInfo, to directory: URL,
                  progress: @escaping @MainActor @Sendable (Double) -> Void) async throws {
        starts += 1
        progressHandlers.append(progress)
        let writeFiles = await withCheckedContinuation { completion = $0 }
        if writeFiles { try plantCatalogModel(model, directory: directory) }
        else { throw CancellationError() }
    }

    func report(_ fraction: Double, operation: Int) async { await progressHandlers[operation](fraction) }
    func finish(writeFiles: Bool) { completion?.resume(returning: writeFiles); completion = nil }
}

private func waitFor(_ condition: @escaping () async -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !(await condition()) {
        guard ContinuousClock.now < deadline else { throw NSError(domain: "Model lifecycle test timed out", code: 1) }
        try await Task.sleep(for: .milliseconds(10))
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
