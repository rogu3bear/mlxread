import AppKit
import ApplicationServices
import Observation

/// Tracks, requests, and continuously monitors Accessibility trust.
///
/// macOS emits no reliable notification when Accessibility trust changes, so
/// this service polls `AXIsProcessTrusted()` (a cheap local call) on a steady
/// heartbeat for the app's lifetime. That means **revocation** is detected
/// while the app runs — not just the initial grant — which lets the app tear
/// down its event tap the moment the user removes trust. The cadence is
/// faster for a short window after the user is sent to System Settings so the
/// UI reacts promptly, then relaxes.
///
/// The service never modifies system settings; it only prompts once, opens
/// the correct pane, and observes.
@MainActor
@Observable
final class AccessibilityPermissionService {
    private(set) var isTrusted: Bool
    /// The one system prompt has been shown this run (avoids re-prompt spam).
    private(set) var hasPrompted = false

    /// Fired on every transition, with the new trust value. Both directions:
    /// true = granted (install tap), false = revoked (tear tap down).
    var onChange: ((Bool) -> Void)?

    private var monitorTask: Task<Void, Never>?
    /// Until this time, poll at the fast cadence (user is acting on Settings).
    private var expediteUntil: Date = .distantPast

    private let slowInterval: Duration = .seconds(2)
    private let fastInterval: Duration = .milliseconds(600)

    init() {
        isTrusted = AXIsProcessTrusted()
    }

    /// Begins lifetime monitoring. Idempotent. Also refreshes when the app
    /// regains focus (common right after the user flips the Settings toggle).
    func startMonitoring() {
        guard monitorTask == nil else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let interval = Date() < self.expediteUntil ? self.fastInterval : self.slowInterval
                try? await Task.sleep(for: interval)
                self.refresh()
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        NotificationCenter.default.removeObserver(self)
    }

    /// Re-reads trust and fires `onChange` on a transition (either direction).
    func refresh() {
        let now = AXIsProcessTrusted()
        guard now != isTrusted else { return }
        isTrusted = now
        AppLogger.permissions.notice("Accessibility trust changed → \(now ? "granted" : "revoked", privacy: .public)")
        onChange?(now)
    }

    /// Shows the one system prompt (first time only per run), otherwise
    /// deep-links to the Accessibility pane. Expedites polling either way.
    func requestAccess() {
        if !hasPrompted {
            hasPrompted = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        } else {
            openSystemSettings()
        }
        expeditePolling()
    }

    func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        expeditePolling()
    }

    /// Poll at the fast cadence for a window (the user is in Settings now).
    func expeditePolling(for duration: TimeInterval = 90) {
        expediteUntil = Date().addingTimeInterval(duration)
        startMonitoring()
    }

    @objc private func appDidBecomeActive() {
        refresh()
    }
}
