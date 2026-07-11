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
        case .permissionRequired: return "Permission required"
        case .modelRequired: return "Model required"
        case .idle: return "Idle"
        case .capturing: return "Capturing selection…"
        case .preparing: return "Preparing model…"
        case .generating: return "Generating…"
        case .playing: return "Speaking"
        case .stopping: return "Stopping…"
        case .failed(let error): return error.errorDescription ?? "Error"
        }
    }
}
