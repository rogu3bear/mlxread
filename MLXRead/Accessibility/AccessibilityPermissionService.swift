import AppKit
import ApplicationServices
import Observation

/// Tracks and requests Accessibility trust. Never modifies system settings;
/// only opens the correct pane and re-checks.
@MainActor
@Observable
final class AccessibilityPermissionService {
    private(set) var isTrusted: Bool
    /// Set once we have shown the system prompt this run, to avoid spamming.
    private var hasPrompted = false
    private var pollTask: Task<Void, Never>?

    var onChange: ((Bool) -> Void)?

    init() {
        isTrusted = AXIsProcessTrusted()
    }

    func refresh() {
        let now = AXIsProcessTrusted()
        if now != isTrusted {
            isTrusted = now
            AppLogger.permissions.info("Accessibility trust changed: \(now)")
            onChange?(now)
        }
    }

    /// Shows the one system prompt (first time only per run), otherwise
    /// deep-links to the Accessibility pane.
    func requestAccess() {
        if !hasPrompted {
            hasPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            openSystemSettings()
        }
        startPollingWhileUntrusted()
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        startPollingWhileUntrusted()
    }

    /// Polls trust for a bounded window after the user was sent to System
    /// Settings, so the UI updates as soon as the checkbox is flipped.
    func startPollingWhileUntrusted(timeout: TimeInterval = 120) {
        guard pollTask == nil, !isTrusted else { return }
        pollTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(timeout)
            while !Task.isCancelled, Date() < deadline {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.refresh()
                if self.isTrusted { break }
            }
            self?.pollTask = nil
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }
}
