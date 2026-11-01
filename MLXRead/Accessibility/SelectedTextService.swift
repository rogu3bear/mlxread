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

enum SelectionCaptureResult: Sendable, Equatable {
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

protocol AXSelectionReading: Sendable {
    func captureSelection() async -> SelectionCaptureResult
}

/// Reads existing pasteboard text without modifying it.
protocol ClipboardTextReading: Sendable {
    func captureSelection() async -> SelectionCaptureResult
}

/// Production capture pipeline: Accessibility first, clipboard fallback
/// second (when enabled). The fallback is only attempted when AX could not
/// produce text — never to "improve" an AX result. Two fallback modes exist
/// and are mutually exclusive: synthesizing ⌘C (`ClipboardSelectionReader`)
/// or passively reading the existing clipboard (`RawClipboardReader`). When
/// both flags are somehow on, the ⌘C mode wins.
final class SelectedTextService: SelectionCapturing {
    private let axReader: any AXSelectionReading
    private let clipboardReader: any ClipboardTextReading
    private let rawClipboardReader: any ClipboardTextReading
    private let clipboardFallbackEnabled: @Sendable () -> Bool
    private let rawClipboardFallbackEnabled: @Sendable () -> Bool

    init(
        axReader: any AXSelectionReading = AXSelectedTextReader(),
        clipboardReader: any ClipboardTextReading = ClipboardSelectionReader(),
        rawClipboardReader: any ClipboardTextReading = RawClipboardReader(),
        clipboardFallbackEnabled: @escaping @Sendable () -> Bool,
        rawClipboardFallbackEnabled: @escaping @Sendable () -> Bool = { false }
    ) {
        self.axReader = axReader
        self.clipboardReader = clipboardReader
        self.rawClipboardReader = rawClipboardReader
        self.clipboardFallbackEnabled = clipboardFallbackEnabled
        self.rawClipboardFallbackEnabled = rawClipboardFallbackEnabled
    }

    func captureSelection() async -> SelectionCaptureResult {
        let axResult = await axReader.captureSelection()
        switch axResult {
        case .text, .permissionDenied:
            return axResult
        case .noSelection, .unsupported, .applicationUnavailable, .failure:
            if clipboardFallbackEnabled() {
                return await clipboardFallbackResult(for: axResult)
            }
            if rawClipboardFallbackEnabled() {
                AppLogger.selection.info("AX capture unavailable; trying raw clipboard fallback")
                let rawResult = await rawClipboardReader.captureSelection()
                // An empty or non-text clipboard says nothing new about the
                // selection — keep the more specific AX diagnosis.
                if case .text = rawResult { return rawResult }
                return axResult
            }
            return axResult
        }
    }

    private func clipboardFallbackResult(for axResult: SelectionCaptureResult) async -> SelectionCaptureResult {
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
