import Foundation

enum SelectionSource: String, Sendable {
    case accessibility
    case clipboard
}

enum SelectionCaptureError: Error, Equatable, Sendable {
    case axError(Int32)
    case clipboardTimeout
    case clipboardEmpty
}

enum SelectionCaptureResult: Sendable {
    case text(String, source: SelectionSource)
    case noSelection
    case unsupported
    case permissionDenied
    case applicationUnavailable
    case failure(SelectionCaptureError)
}

/// Abstraction over selection capture so the coordinator is testable.
protocol SelectionCapturing: Sendable {
    func captureSelection() async -> SelectionCaptureResult
}

/// Production capture pipeline: Accessibility first, clipboard fallback
/// second (when enabled). The fallback is only attempted when AX could not
/// produce text — never to "improve" an AX result.
final class SelectedTextService: SelectionCapturing {
    private let axReader: AXSelectedTextReader
    private let clipboardReader: ClipboardSelectionReader
    private let clipboardFallbackEnabled: @Sendable () -> Bool

    init(
        axReader: AXSelectedTextReader = AXSelectedTextReader(),
        clipboardReader: ClipboardSelectionReader = ClipboardSelectionReader(),
        clipboardFallbackEnabled: @escaping @Sendable () -> Bool
    ) {
        self.axReader = axReader
        self.clipboardReader = clipboardReader
        self.clipboardFallbackEnabled = clipboardFallbackEnabled
    }

    func captureSelection() async -> SelectionCaptureResult {
        let axResult = await axReader.captureSelection()
        switch axResult {
        case .text, .permissionDenied:
            return axResult
        case .noSelection, .unsupported, .applicationUnavailable, .failure:
            guard clipboardFallbackEnabled() else { return axResult }
            AppLogger.selection.info("AX capture unavailable; trying clipboard fallback")
            let clipboardResult = await clipboardReader.captureSelection()
            if case .text = clipboardResult {
                return clipboardResult
            }
            // Prefer the more specific AX diagnosis when both fail,
            // except a clean "no selection" from the fallback.
            if case .noSelection = clipboardResult, case .unsupported = axResult {
                return .noSelection
            }
            return axResult
        }
    }
}
