import AppKit

/// Passive clipboard fallback: reads whatever text is already on the
/// pasteboard. Unlike `ClipboardSelectionReader` it sends no keystrokes and
/// never modifies the clipboard; the text may be arbitrarily stale.
final class RawClipboardReader: ClipboardTextReading, Sendable {
    func captureSelection() async -> SelectionCaptureResult {
        let text = await MainActor.run { NSPasteboard.general.string(forType: .string) }
        guard let text, !text.isEmpty else { return .noSelection }
        return .text(text, source: .clipboard)
    }
}
