import Foundation

/// Disk/download state of one model, as shown in Settings → Models.
enum ModelDownloadState: Equatable, Sendable {
    case notDownloaded
    case downloading(fraction: Double)
    case downloaded
    case failed(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}
