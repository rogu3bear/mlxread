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
        appState.permissions.startMonitoring()
        appState.installHotkeyIfPossible()
        appState.coordinator.refreshAvailability()

        hud = PlaybackHUDController(appState: appState)

        // No transient windows under XCUITest: the test attaches to the
        // accessibility tree during launch and a window appearing mid-attach
        // races AppKit's snapshot machinery.
        let isUITest = ProcessInfo.processInfo.environment["MLXREAD_UITEST"] == "1"
        if !isUITest, !appState.permissions.isTrusted, !appState.settings.onboardingCompleted {
            // Deferred: presenting a window inside the launch transaction
            // collides with MenuBarExtra scene setup — AppKit throws
            // "_postWindowNeedsUpdateConstraints during display cycle"
            // and the app aborts. One settled run-loop turn avoids it.
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                self?.showOnboarding()
            }
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
