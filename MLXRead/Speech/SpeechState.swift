import Foundation

/// Single authoritative state for the whole app. Owned by `SpeechCoordinator`;
/// every UI surface observes this and nothing else infers activity separately.
enum SpeechState: Equatable {
    case unavailable
    case permissionRequired
    case modelRequired
    case idle
    case capturing
    case preparing
    case generating
    case playing
    case stopping
    case failed(UserFacingSpeechError)

    var isBusy: Bool {
        switch self {
        case .capturing, .preparing, .generating, .playing, .stopping:
            return true
        default:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .permissionRequired: return "Allow access in Settings"
        case .modelRequired: return "Download a voice in Settings"
        case .idle: return "Ready to read"
        case .capturing: return "Getting selected text…"
        case .preparing: return "Loading voice…"
        case .generating: return "Preparing speech…"
        case .playing: return "Speaking"
        case .stopping: return "Stopping…"
        case .failed: return "Couldn’t read · open Settings"
        }
    }
}
