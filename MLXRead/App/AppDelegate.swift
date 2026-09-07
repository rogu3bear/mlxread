import AppKit
import Darwin
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState: AppState
    private let instanceLock: SingleInstanceLock?
    private var hud: PlaybackHUDController?
    private var onboarding: OnboardingWindowController?

    /// True inside xcodebuild test hosting — services with global side
    /// effects (event tap, prompts, HUD) stay off.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    override init() {
        if Self.isRunningTests {
            instanceLock = nil
        } else {
            do {
                instanceLock = try SingleInstanceLock.acquire(
                    at: Constants.applicationSupportDirectory.appendingPathComponent("instance.lock")
                )
                // The lock handles simultaneous launches. The running-app check
                // also respects an older copy that predates the lock.
                let existing = NSRunningApplication.runningApplications(
                    withBundleIdentifier: Constants.bundleIdentifier
                ).first { $0.processIdentifier != getpid() && $0.isFinishedLaunching && !$0.isTerminated }
                guard instanceLock != nil, existing == nil else {
                    AppLogger.app.notice("Duplicate MLXRead launch refused")
                    if let url = existing?.bundleURL {
                        NSWorkspace.shared.open(url)
                    }
                    exit(EXIT_SUCCESS)
                }
            } catch {
                // Never start a second set of services if exclusivity cannot
                // be established, including a permissions or filesystem error.
                AppLogger.app.fault("MLXRead launch refused: \(error.localizedDescription)")
                exit(EXIT_FAILURE)
            }
        }
        appState = AppState()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !Self.isRunningTests else { return }

        appState.selectionAccess.startMonitoring()

        hud = PlaybackHUDController(appState: appState)

        // No transient windows under XCUITest: the test attaches to the
        // accessibility tree during launch and a window appearing mid-attach
        // races AppKit's snapshot machinery.
        let isUITest = ProcessInfo.processInfo.environment["MLXREAD_UITEST"] == "1"
        if !isUITest, !appState.selectionAccess.isTrusted, !appState.settings.onboardingCompleted {
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

    /// Reopening a menu-bar utility should expose its controls. Dispatch the
    /// standard Settings command so SwiftUI retains ownership of its window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        for menu in sender.mainMenu?.items.compactMap(\.submenu) ?? [] {
            if let index = menu.items.firstIndex(where: {
                $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command)
            }) {
                menu.performActionForItem(at: index)
                return false
            }
        }
        return false
    }

    func showOnboarding() {
        if onboarding == nil {
            onboarding = OnboardingWindowController(
                access: appState.selectionAccess, settings: appState.settings
            )
        }
        onboarding?.show()
    }
}

/// A kernel-owned lock shared by installed and development copies. Retain it
/// for the process lifetime. Never unlink the file: replacing its inode could
/// let another process acquire a different lock while this one is still held.
final class SingleInstanceLock {
    private let descriptor: Int32

    private init(descriptor: Int32) { self.descriptor = descriptor }

    static func acquire(at url: URL) throws -> SingleInstanceLock? {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = Darwin.open(url.path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, mode_t(0o600))
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 {
            return SingleInstanceLock(descriptor: descriptor)
        }
        let code = errno
        Darwin.close(descriptor)
        if code == EWOULDBLOCK { return nil }
        throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }

    deinit { Darwin.close(descriptor) }
}
