import Foundation
import Observation
import Sparkle

/// Thin wrapper around Sparkle's updater for a menu-bar (no main-menu) app.
///
/// Security model: updates are delivered as an EdDSA-signed appcast fetched
/// over HTTPS. Sparkle verifies the `sparkle:edSignature` of every downloaded
/// archive against `SUPublicEDKey` (Info.plist) before installing, so a
/// compromised feed host or a TLS MITM cannot ship a malicious update without
/// the maintainer's Ed25519 private key. This is the mitigation for TM-002
/// (distribution/update integrity).
///
/// The feed URL and public key live in Info.plist. Until a maintainer sets
/// real values (see docs/updates.md), this service stays **inactive**: the
/// updater is not started and no update UI is shown. That keeps source/dev
/// builds from pointing at a placeholder feed. Nothing here embeds a secret.
@MainActor
@Observable
final class UpdateService {
    private let controller: SPUStandardUpdaterController

    /// Mirrors the updater's `canCheckForUpdates` so SwiftUI can disable the
    /// menu item while a check is already in flight.
    private(set) var canCheckForUpdates = false

    /// True only when Info.plist carries real (non-placeholder) update config.
    /// The UI hides update controls when false.
    let isConfigured: Bool

    private var observation: NSKeyValueObservation?

    init() {
        // startingUpdater: false — start only after confirming real config,
        // so a placeholder feed/key never triggers Sparkle's misconfiguration
        // alert in source or development builds.
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        isConfigured = Self.looksConfigured(feed: feed, publicKey: key)

        guard isConfigured else {
            AppLogger.app.info("Update service inactive: no release update config (placeholder feed/key)")
            return
        }

        controller.startUpdater()
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
        AppLogger.app.info("Update service active (feed configured)")
    }

    /// User-initiated check ("Check for Updates…"). Shows Sparkle's UI for
    /// progress, release notes, and install.
    func checkForUpdates() {
        guard isConfigured else { return }
        controller.updater.checkForUpdates()
    }

    /// Whether Sparkle performs automatic background checks. Bound to the
    /// General settings toggle; persisted by Sparkle in its own defaults.
    var automaticallyChecksForUpdates: Bool {
        get { isConfigured && controller.updater.automaticallyChecksForUpdates }
        set { if isConfigured { controller.updater.automaticallyChecksForUpdates = newValue } }
    }

    /// A build is "configured" only when neither the feed URL nor the public
    /// key is still a template placeholder and the feed is HTTPS.
    private static func looksConfigured(feed: String, publicKey: String) -> Bool {
        guard !feed.isEmpty, !publicKey.isEmpty else { return false }
        guard feed.hasPrefix("https://") else { return false }
        let placeholders = ["OWNER", "REPLACE", "example.com"]
        for token in placeholders where feed.contains(token) || publicKey.contains(token) {
            return false
        }
        return true
    }
}
