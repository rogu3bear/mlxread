import Foundation
import OSLog

/// Privacy-safe diagnostic bundle for an in-app problem report. It contains
/// ONLY safe metadata and recent log lines — which, by the logging invariant in
/// AppLogger, never include selected or spoken text. The selection is never
/// read here. Construct it on the main actor (it reads AppState); the zip is
/// built off-actor from the captured value fields.
struct DebugBundle: Sendable {
    let appVersion: String
    let build: String
    let osVersion: String
    let hardware: String
    let model: String
    let voice: String
    let speed: String
    let modelState: String
    let accessibilityTrusted: Bool
    let hotkeyInstalled: Bool
    let launchAtLogin: Bool

    @MainActor
    init(appState: AppState) {
        let info = Bundle.main.infoDictionary
        appVersion = (info?["CFBundleShortVersionString"] as? String) ?? "?"
        build = (info?["CFBundleVersion"] as? String) ?? "?"
        osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        hardware = DebugBundle.hardwareModel()
        let settings = appState.settings
        model = settings.selectedModelID
        voice = settings.selectedVoice.isEmpty ? "(model default)" : settings.selectedVoice
        speed = String(format: "%.2f×", settings.speechSpeed)
        modelState = String(describing: appState.modelStore.state(for: settings.selectedModel))
        accessibilityTrusted = appState.permissions.isTrusted
        hotkeyInstalled = appState.hotkeyInstalled
        launchAtLogin = appState.launchAtLoginEnabled
    }

    /// Shown in the UI so the user sees exactly what will be sent before they
    /// send it. Same facts as report.json (minus the log lines).
    var summary: String {
        """
        App             \(Constants.appName) \(appVersion) (build \(build))
        macOS           \(osVersion)
        Hardware        \(hardware)
        Model           \(model) · \(modelState)
        Voice / speed   \(voice) · \(speed)
        Accessibility   \(accessibilityTrusted ? "granted" : "not granted")
        ⌥⎋ shortcut     \(hotkeyInstalled ? "installed" : "not installed")
        Launch at login \(launchAtLogin ? "on" : "off")

        Plus up to ~10 minutes of recent app logs — timings, counts, and error
        messages only. Never any selected or spoken text.
        """
    }

    /// Build a real .zip (report.json + log.txt) with no extra dependency, using
    /// NSFileCoordinator's `.forUploading` option, which zips a directory.
    func makeZip() throws -> Data {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("mlxread-report-\(UUID().uuidString)", isDirectory: true)
        let payload = root.appendingPathComponent("mlxread-debug", isDirectory: true)
        try fm.createDirectory(at: payload, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try reportJSON().write(to: payload.appendingPathComponent("report.json"))
        try Data(recentLogText().utf8).write(to: payload.appendingPathComponent("log.txt"))

        var coordError: NSError?
        var readError: Error?
        var zipData: Data?
        NSFileCoordinator().coordinate(readingItemAt: payload, options: [.forUploading], error: &coordError) { zipped in
            do { zipData = try Data(contentsOf: zipped) } catch { readError = error }
        }
        if let coordError { throw coordError }
        if let readError { throw readError }
        guard let zipData else { throw ReportError.bundleFailed }
        return zipData
    }

    private func reportJSON() -> Data {
        let obj: [String: Any] = [
            "app_version": appVersion,
            "build": build,
            "os_version": osVersion,
            "hardware": hardware,
            "model": model,
            "voice": voice,
            "speed": speed,
            "model_state": modelState,
            "accessibility_trusted": accessibilityTrusted,
            "hotkey_installed": hotkeyInstalled,
            "launch_at_login": launchAtLogin,
            "generated_at": ISO8601DateFormatter().string(from: Date()),
        ]
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])) ?? Data()
    }

    /// Recent log lines from this process. Safe by the AppLogger invariant;
    /// returns an explanatory note instead of throwing on failure.
    private func recentLogText() -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(date: Date().addingTimeInterval(-600))
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm:ss.SSS"
            var lines: [String] = []
            for entry in try store.getEntries(at: since) {
                guard let log = entry as? OSLogEntryLog,
                      log.subsystem == Constants.logSubsystem else { continue }
                lines.append("[\(fmt.string(from: log.date))] [\(log.category)] \(log.composedMessage)")
            }
            return lines.isEmpty
                ? "(no MLXRead log entries in the last 10 minutes)"
                : lines.joined(separator: "\n")
        } catch {
            return "(could not read logs: \(error.localizedDescription))"
        }
    }

    private static func hardwareModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }
}

enum ReportError: LocalizedError {
    case bundleFailed
    case network(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .bundleFailed: return "Could not assemble the debug bundle."
        case .network(let message): return message
        case .server(let message): return message
        }
    }
}
