import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState: AppState
    private var hud: PlaybackHUDController?
    private var onboarding: OnboardingWindowController?
    private var stateObservationTask: Task<Void, Never>?

    /// True inside xcodebuild test hosting — services with global side
    /// effects (event tap, prompts, HUD) stay off.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    override init() {
        appState = AppState()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        appState.permissions.refresh()
        appState.installHotkeyIfPossible()
        appState.coordinator.refreshAvailability()

        hud = PlaybackHUDController(appState: appState)

        if !appState.permissions.isTrusted, !appState.settings.onboardingCompleted {
            showOnboarding()
        }
        AppLogger.app.info("MLXRead launched (mock engine: \(self.appState.usesMockEngine))")
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdown()
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController(appState: appState)
        }
        onboarding?.show()
    }
}
