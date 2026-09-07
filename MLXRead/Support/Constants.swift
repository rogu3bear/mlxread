import Foundation

enum Constants {
    static let appName = "MLXRead"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "me.jkca.mlxread"
    static let logSubsystem = "me.jkca.mlxread"

    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MLXRead", isDirectory: true)
    }

    /// Root directory for model assets:
    /// ~/Library/Application Support/MLXRead/Models
    static var modelsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Models", isDirectory: true)
    }

    enum DefaultsKey {
        static let selectedModelID = "selectedModelID"
        static let selectedVoice = "selectedVoice"
        static let speechSpeed = "speechSpeed"
        static let clipboardFallbackEnabled = "clipboardFallbackEnabled"
        static let showPlaybackHUD = "showPlaybackHUD"
        static let maximumSelectionLength = "maximumSelectionLength"
        static let onboardingCompleted = "onboardingCompleted"
        static let reporterEmail = "reporterEmail"
    }

    enum Defaults {
        static let speechSpeed: Double = 1.0
        static let clipboardFallbackEnabled = true
        static let showPlaybackHUD = false
        static let maximumSelectionLength = 20_000
    }

    /// Hard bounds for the user-configurable maximum selection length.
    static let selectionLengthBounds = 500...100_000

    /// In-app problem reporting. Reports POST a privacy-safe debug bundle to the
    /// delivery worker, which emails it to the maintainer.
    enum Report {
        static let endpoint = URL(string: "https://mlxread-api.sp5qybrsvz.workers.dev/report")!
        // Not a real secret — it ships inside the app binary; a low-friction gate
        // backed by the worker's rate limits and size caps.
        static let token = "mlxr_report_2f8c1a90b7"
    }
}
