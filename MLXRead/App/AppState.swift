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
    var speechSpeed: Double { didSet { defaults.set(speechSpeed, forKey: Constants.DefaultsKey.speechSpeed) } }
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
    var showSelectionPreview: Bool { didSet { defaults.set(showSelectionPreview, forKey: Constants.DefaultsKey.showSelectionPreview) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selectedModelID = defaults.string(forKey: Constants.DefaultsKey.selectedModelID) ?? ModelManifest.defaultModel.id
        selectedVoice = defaults.string(forKey: Constants.DefaultsKey.selectedVoice) ?? (ModelManifest.defaultModel.defaultVoice ?? "")
        let speed = defaults.double(forKey: Constants.DefaultsKey.speechSpeed)
        speechSpeed = speed == 0 ? Constants.Defaults.speechSpeed : speed
        clipboardFallbackEnabled = defaults.object(forKey: Constants.DefaultsKey.clipboardFallbackEnabled) as? Bool ?? Constants.Defaults.clipboardFallbackEnabled
        showPlaybackHUD = defaults.object(forKey: Constants.DefaultsKey.showPlaybackHUD) as? Bool ?? Constants.Defaults.showPlaybackHUD
        let storedMax = defaults.integer(forKey: Constants.DefaultsKey.maximumSelectionLength)
        maximumSelectionLength = storedMax == 0 ? Constants.Defaults.maximumSelectionLength : storedMax.clamped(to: Constants.selectionLengthBounds)
        onboardingCompleted = defaults.bool(forKey: Constants.DefaultsKey.onboardingCompleted)
        showSelectionPreview = defaults.object(forKey: Constants.DefaultsKey.showSelectionPreview) as? Bool ?? Constants.Defaults.showSelectionPreview
    }

    var selectedModel: ModelInfo {
        ModelManifest.model(withID: selectedModelID) ?? ModelManifest.defaultModel
    }

    var speechConfiguration: SpeechConfiguration {
        let model = selectedModel
        return SpeechConfiguration(
            voice: model.supportsVoices && !selectedVoice.isEmpty ? selectedVoice : model.defaultVoice,
            speed: speechSpeed,
            language: nil
        )
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

/// Keeps one live engine per model so the loaded model survives between reads.
@MainActor
final class EngineCache {
    var engines: [String: any SpeechEngine] = [:]
}

/// Composition root: builds and owns every service, exposes them to SwiftUI.
@MainActor
@Observable
final class AppState {
    let settings: AppSettings
    let permissions: AccessibilityPermissionService
    let modelStore: ModelStore
    let coordinator: SpeechCoordinator
    private(set) var hotkeyInstalled = false

    private var hotkey: GlobalHotkeyService?
    private let engineCache = EngineCache()
    private var memoryPressureSource: (any DispatchSourceMemoryPressure)?

    /// True when launched with MLXREAD_ENGINE=mock (interaction proofs, UI tests).
    let usesMockEngine: Bool

    init() {
        ModelStore.bootstrapEnvironment()
        let settings = AppSettings()
        self.settings = settings
        permissions = AccessibilityPermissionService()
        modelStore = ModelStore()
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
                if let cached = engineCache.engines[model.id] { return cached }
                let engine = NativeMLXSpeechEngine(modelInfo: model)
                engineCache.engines[model.id] = engine
                return engine
            },
            configurationProvider: { settings.speechConfiguration },
            maximumLengthProvider: { settings.maximumSelectionLength }
        )

        wireAvailability()
        installMemoryPressureHandler()
    }

    // MARK: - Availability gates

    private func wireAvailability() {
        coordinator.availabilityCheck = { [weak self] in
            guard let self else { return SpeechState.unavailable }
            if !self.permissions.isTrusted { return .permissionRequired }
            if !self.usesMockEngine {
                let model = self.settings.selectedModel
                if self.modelStore.state(for: model) != .downloaded { return .modelRequired }
            }
            return nil
        }
        permissions.onChange = { [weak self] trusted in
            guard let self else { return }
            if trusted { self.installHotkeyIfPossible() }
            self.coordinator.refreshAvailability()
        }
        coordinator.refreshAvailability()
    }

    // MARK: - Hotkey lifecycle

    func installHotkeyIfPossible() {
        guard hotkey == nil, permissions.isTrusted else { return }
        let coordinator = self.coordinator
        let service = GlobalHotkeyService {
            coordinator.toggle()
        }
        do {
            try service.start()
            hotkey = service
            hotkeyInstalled = true
        } catch {
            hotkeyInstalled = false
            AppLogger.hotkey.error("Hotkey install failed despite trust; will retry on permission change")
        }
    }

    func shutdown() {
        hotkey?.stop()
        hotkey = nil
    }

    // MARK: - Memory pressure

    private func installMemoryPressureHandler() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.critical], queue: .main)
        source.setEventHandler { [weak self] in
            guard let self, !self.coordinator.state.isBusy else { return }
            AppLogger.app.notice("Critical memory pressure: releasing model resources")
            for engine in self.engineCache.engines.values {
                if let native = engine as? NativeMLXSpeechEngine {
                    Task { await native.unload() }
                }
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
