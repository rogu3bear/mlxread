import Foundation

enum Constants {
    static let appName = "MLXRead"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "me.jkca.mlxread"
    static let logSubsystem = "me.jkca.mlxread"

    /// Root directory for model assets:
    /// ~/Library/Application Support/MLXRead/Models
    static var modelsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("MLXRead/Models", isDirectory: true)
    }

    enum DefaultsKey {
        static let selectedModelID = "selectedModelID"
        static let selectedVoice = "selectedVoice"
        static let speechSpeed = "speechSpeed"
        static let clipboardFallbackEnabled = "clipboardFallbackEnabled"
        static let showPlaybackHUD = "showPlaybackHUD"
        static let maximumSelectionLength = "maximumSelectionLength"
        static let onboardingCompleted = "onboardingCompleted"
        static let showSelectionPreview = "showSelectionPreview"
    }

    enum Defaults {
        static let speechSpeed: Double = 1.0
        static let clipboardFallbackEnabled = true
        static let showPlaybackHUD = false
        static let maximumSelectionLength = 20_000
        static let showSelectionPreview = false
    }

    /// Hard bounds for the user-configurable maximum selection length.
    static let selectionLengthBounds = 500...100_000
}
