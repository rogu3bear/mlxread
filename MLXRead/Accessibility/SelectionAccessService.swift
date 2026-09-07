import AppKit
import ApplicationServices
import Observation

/// Owns Accessibility trust and the shortcut's recovery lifecycle.
/// Polling observes permission changes and actual tap health; it never prompts.
@MainActor
@Observable
final class SelectionAccessService {
    private(set) var isTrusted: Bool
    private(set) var shortcutActive = false
    private var attemptsRemaining = 3
    private var hasPrompted = false

    /// Permission transitions only. Shortcut recovery must not interrupt speech.
    var onChange: ((Bool) -> Void)?

    private let hotkey: any GlobalHotkeyControlling
    private let checkTrust: () -> Bool
    private var monitorTask: Task<Void, Never>?

    init(
        hotkey: any GlobalHotkeyControlling,
        checkTrust: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.hotkey = hotkey
        self.checkTrust = checkTrust
        isTrusted = checkTrust()
    }

    var shortcutNeedsRetry: Bool {
        isTrusted && !shortcutActive && attemptsRemaining == 0
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        retryShortcut()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.refresh()
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        NotificationCenter.default.removeObserver(self)
        hotkey.stop()
        shortcutActive = false
    }

    func refresh() {
        let trusted = checkTrust()
        let trustChanged = trusted != isTrusted
        isTrusted = trusted
        if trustChanged { attemptsRemaining = 3 }

        if !trusted {
            hotkey.stop()
        } else if !hotkey.isRunning, attemptsRemaining > 0 {
            attemptsRemaining -= 1
            do {
                try hotkey.start()
            } catch {
                if attemptsRemaining == 0 {
                    AppLogger.hotkey.error("Shortcut unavailable after three attempts")
                }
            }
        }
        shortcutActive = trusted && hotkey.isRunning
        if shortcutActive { attemptsRemaining = 3 }

        if trustChanged {
            AppLogger.permissions.notice("Accessibility trust changed → \(trusted ? "granted" : "revoked", privacy: .public)")
            onChange?(trusted)
        }
    }

    /// A fresh attempt after the user returns or explicitly retries.
    func retryShortcut() {
        attemptsRemaining = 3
        refresh()
    }

    func requestAccess() {
        if !hasPrompted {
            hasPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            openSystemSettings()
        }
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func appDidBecomeActive() {
        retryShortcut()
    }
}
