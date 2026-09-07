import Foundation

/// Disk/download state of one model, as shown in Settings → Models.
enum ModelDownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(fraction: Double)
    case checking
    case cancelling
    case deleting
    case downloaded
    case incomplete
    case failed(String)

    var isDownloading: Bool {
        switch self {
        case .downloading, .checking, .cancelling: return true
        default: return false
        }
    }

    var isBusy: Bool { isDownloading || self == .deleting }

    var label: String {
        switch self {
        case .notDownloaded: return "Not downloaded"
        case .downloading: return "Downloading"
        case .checking: return "Checking files"
        case .cancelling: return "Cancelling download"
        case .deleting: return "Deleting"
        case .downloaded: return "Downloaded"
        case .incomplete: return "Incomplete download"
        case .failed: return "Download failed"
        }
    }
}
