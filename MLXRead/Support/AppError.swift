import Foundation

/// User-facing errors. Every case must map to an actionable message.
/// None of these ever embed selected text.
enum UserFacingSpeechError: Error, Equatable, LocalizedError {
    case accessibilityPermissionMissing
    case noSelectionFound
    case selectionNotExposed
    case clipboardFallbackFailed
    case modelDownloadFailed(String)
    case modelFilesIncomplete
    case modelLoadFailed(String)
    case audioDeviceUnavailable
    case synthesisCancelled
    case synthesisFailed(String)
    case hotkeyInstallFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionMissing:
            return "Accessibility permission is missing. Grant access in System Settings → Privacy & Security → Accessibility."
        case .noSelectionFound:
            return "No selected text was found in the frontmost application."
        case .selectionNotExposed:
            return "The frontmost application does not expose its selection. Enable the clipboard fallback in Settings, or copy the text manually."
        case .clipboardFallbackFailed:
            return "The clipboard copy fallback failed to capture a selection."
        case .modelDownloadFailed(let detail):
            return "Model download failed: \(detail)"
        case .modelFilesIncomplete:
            return "Model files are incomplete. Remove and re-download the model in Settings → Models."
        case .modelLoadFailed(let detail):
            return "The speech model failed to load: \(detail)"
        case .audioDeviceUnavailable:
            return "No audio output device is available."
        case .synthesisCancelled:
            return "Speech was cancelled."
        case .synthesisFailed(let detail):
            return "Speech synthesis failed: \(detail)"
        case .hotkeyInstallFailed:
            return "The global shortcut could not be installed. This usually means Accessibility permission is missing."
        }
    }
}
