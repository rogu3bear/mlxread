import Foundation
import Observation
import ServiceManagement

/// User preferences persisted in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var selectedModelID: String { didSet { defaults.set(selectedModelID, forKey: Constants.DefaultsKey.selectedModelID) } }
    var selectedVoice: String { didSet { defaults.set(selectedVoice, forKey: Constants.DefaultsKey.selectedVoice) } }
    var selectedLanguage: String { didSet { defaults.set(selectedLanguage, forKey: "language.\(selectedModelID)") } }
    var speechDelivery: SpeechDelivery { didSet { defaults.set(speechDelivery.rawValue, forKey: "speechDelivery") } }
    var speechSpeed: Double {
        didSet {
            let bounded = speechSpeed.isFinite ? min(max(speechSpeed, 0.5), 2.0) : 1.0
            if !speechSpeed.isFinite || speechSpeed != bounded {
                speechSpeed = bounded
                return
            }
            defaults.set(speechSpeed, forKey: Constants.DefaultsKey.speechSpeed)
        }
    }
    var clipboardFallbackEnabled: Bool { didSet { defaults.set(clipboardFallbackEnabled, forKey: Constants.DefaultsKey.clipboardFallbackEnabled) } }
    var showPlaybackHUD: Bool { didSet { defaults.set(showPlaybackHUD, forKey: Constants.DefaultsKey.showPlaybackHUD) } }
    var maximumSelectionLength: Int {
        didSet {
            // Guarded self-assignment: with @Observable, didSet re-fires on
            // assignment, so only reassign when the clamp actually changes
            // the value (recursion then terminates immediately).
            let clamped = maximumSelectionLength.clamped(to: Constants.selectionLengthBounds)
            if clamped != maximumSelectionLength {
                maximumSelectionLength = clamped
                return
            }
            defaults.set(maximumSelectionLength, forKey: Constants.DefaultsKey.maximumSelectionLength)
        }
    }
    var onboardingCompleted: Bool { didSet { defaults.set(onboardingCompleted, forKey: Constants.DefaultsKey.onboardingCompleted) } }
    var reporterEmail: String { didSet { defaults.set(reporterEmail, forKey: Constants.DefaultsKey.reporterEmail) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let initialModelID = defaults.string(forKey: Constants.DefaultsKey.selectedModelID) ?? ModelManifest.defaultModel.id
        selectedModelID = initialModelID
        selectedVoice = defaults.string(forKey: Constants.DefaultsKey.selectedVoice) ?? (ModelManifest.defaultModel.defaultVoice ?? "")
        selectedLanguage = defaults.string(forKey: "language.\(initialModelID)") ?? "en-US"
        speechDelivery = SpeechDelivery(rawValue: defaults.string(forKey: "speechDelivery") ?? "") ?? .natural
        let speed = defaults.double(forKey: Constants.DefaultsKey.speechSpeed)
        speechSpeed = speed == 0 || !speed.isFinite ? Constants.Defaults.speechSpeed : min(max(speed, 0.5), 2.0)
        clipboardFallbackEnabled = defaults.object(forKey: Constants.DefaultsKey.clipboardFallbackEnabled) as? Bool ?? Constants.Defaults.clipboardFallbackEnabled
        showPlaybackHUD = defaults.object(forKey: Constants.DefaultsKey.showPlaybackHUD) as? Bool ?? Constants.Defaults.showPlaybackHUD
        let storedMax = defaults.integer(forKey: Constants.DefaultsKey.maximumSelectionLength)
        maximumSelectionLength = storedMax == 0 ? Constants.Defaults.maximumSelectionLength : storedMax.clamped(to: Constants.selectionLengthBounds)
        onboardingCompleted = defaults.bool(forKey: Constants.DefaultsKey.onboardingCompleted)
        reporterEmail = defaults.string(forKey: Constants.DefaultsKey.reporterEmail) ?? ""
    }

    var selectedModel: ModelInfo {
        ModelManifest.model(withID: selectedModelID) ?? ModelManifest.defaultModel
    }

    func selectModel(_ model: ModelInfo) {
        guard selectedModelID != model.id else { return }
        defaults.set(selectedVoice, forKey: "voice.\(selectedModelID)")
        selectedModelID = model.id
        selectedVoice = defaults.string(forKey: "voice.\(model.id)") ?? model.defaultVoice ?? ""
        selectedLanguage = defaults.string(forKey: "language.\(model.id)") ?? model.languages.first ?? "en-US"
    }

    var speechConfiguration: SpeechConfiguration {
        let model = selectedModel
        return SpeechConfiguration(
            voice: model.supportsVoices && !selectedVoice.isEmpty ? selectedVoice : model.defaultVoice,
            speed: speechSpeed,
            language: model.readingLanguage(voice: selectedVoice, requested: selectedLanguage),
            delivery: speechDelivery
        )
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Keeps the most recently used model warm without retaining every download in RAM.
@MainActor
final class EngineCache {
    private(set) var engine: (any SpeechEngine)?

    func engine(for model: ModelInfo) -> any SpeechEngine {
        if let engine, engine.identifier == model.id { return engine }
        let next = NativeMLXSpeechEngine(modelInfo: model)
        engine = next
        return next
    }

    func releaseUnavailableModels(in store: ModelStore) {
        guard let engine, let info = ModelManifest.model(withID: engine.identifier) else { return }
        guard !store.state(for: info).isBusy else { return }
        if store.state(for: info) != .downloaded { self.engine = nil }
    }

    func prepareForRemoval(_ model: ModelInfo) async {
        guard let current = engine, current.identifier == model.id else { return }
        await current.cancel()
        if let native = current as? NativeMLXSpeechEngine { await native.unload() }
        if engine?.identifier == model.id { engine = nil }
    }
}

/// Composition root: builds and owns every service, exposes them to SwiftUI.
@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    let selectionAccess: SelectionAccessService
    let modelStore: ModelStore
    let coordinator: SpeechCoordinator
    let updates: UpdateService
    private let engineCache = EngineCache()
    private var memoryPressureSource: (any DispatchSourceMemoryPressure)?

    /// True when launched with MLXREAD_ENGINE=mock (interaction proofs, UI tests).
    let usesMockEngine: Bool

    init() {
        ModelStore.bootstrapEnvironment()
        let settings = AppSettings()
        self.settings = settings
        modelStore = ModelStore()
        updates = UpdateService()
        usesMockEngine = ProcessInfo.processInfo.environment["MLXREAD_ENGINE"] == "mock"

        let selectionService = SelectedTextService(
            clipboardFallbackEnabled: { @Sendable in
                // UserDefaults is thread-safe; read the persisted flag directly.
                UserDefaults.standard.object(forKey: Constants.DefaultsKey.clipboardFallbackEnabled) as? Bool
                    ?? Constants.Defaults.clipboardFallbackEnabled
            }
        )
        let player = StreamingAudioPlayer()

        let engineCache = self.engineCache
        let mock = usesMockEngine ? MockSpeechEngine() : nil

        coordinator = SpeechCoordinator(
            selection: selectionService,
            player: player,
            engineProvider: {
                if let mock { return mock }
                let model = ModelManifest.model(withID: settings.selectedModelID) ?? ModelManifest.defaultModel
                return engineCache.engine(for: model)
            },
            configurationProvider: { settings.speechConfiguration },
            maximumLengthProvider: { settings.maximumSelectionLength }
        )

        let speech = coordinator
        selectionAccess = SelectionAccessService(hotkey: GlobalHotkeyService {
            speech.toggle()
        })

        wireAvailability()
        installMemoryPressureHandler()
    }

    // MARK: - Availability gates

    private func wireAvailability() {
        coordinator.availabilityCheck = { [weak self] in
            guard let self else { return SpeechState.unavailable }
            if !self.selectionAccess.isTrusted { return .permissionRequired }
            if !self.usesMockEngine {
                return self.modelStore.availability(
                    for: self.settings.selectedModel, voice: self.settings.speechConfiguration.voice,
                    language: self.settings.speechConfiguration.language
                )
            }
            return nil
        }
        // A built-in preview needs model assets, but reads no other app's text.
        coordinator.sampleAvailabilityCheck = { [weak self] configuration in
            guard let self else { return .unavailable }
            return self.usesMockEngine ? nil : self.modelStore.availability(
                for: self.settings.selectedModel, voice: configuration.voice, language: configuration.language
            )
        }
        modelStore.onStateChange = { [weak self] in
            guard let self else { return }
            self.engineCache.releaseUnavailableModels(in: self.modelStore)
            self.coordinator.refreshAvailability()
        }
        modelStore.prepareForRemoval = { [weak self] model in
            await self?.engineCache.prepareForRemoval(model)
        }
        selectionAccess.onChange = { [weak self] trusted in
            guard let self else { return }
            if !trusted, self.coordinator.state.isBusy {
                self.coordinator.stop()
            }
            self.coordinator.refreshAvailability()
        }
        coordinator.refreshAvailability()
    }

    func shutdown() {
        selectionAccess.stopMonitoring()
    }

    // MARK: - Memory pressure

    private func installMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, !self.coordinator.state.isBusy else { return }
            AppLogger.app.notice("Critical memory pressure: releasing model resources")
            if let native = self.engineCache.engine as? NativeMLXSpeechEngine {
                Task { await native.unload() }
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    // MARK: - Launch at login

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLogger.app.error("Launch-at-login change failed: \(error.localizedDescription)")
        }
    }
}
