import AppKit
import Carbon.HIToolbox

/// Clipboard-copy fallback for applications that do not expose their
/// selection through Accessibility.
///
/// Sequence: snapshot pasteboard → synthesize ⌘C → wait (bounded) for a new
/// pasteboard change → accept only fresh textual content → restore the
/// snapshot when nothing else has touched the pasteboard since.
final class ClipboardSelectionReader: Sendable {
    /// How long to wait for the frontmost app to service ⌘C.
    private let copyTimeout: TimeInterval
    /// Poll interval for changeCount.
    private let pollInterval: TimeInterval

    init(copyTimeout: TimeInterval = 0.6, pollInterval: TimeInterval = 0.02) {
        self.copyTimeout = copyTimeout
        self.pollInterval = pollInterval
    }

    func captureSelection() async -> SelectionCaptureResult {
        let pasteboard = NSPasteboard.general

        let snapshot = await MainActor.run { PasteboardSnapshot.capture(from: pasteboard) }
        let baseline = snapshot.changeCount

        guard synthesizeCopyKeystroke() else {
            return .failure(.clipboardTimeout)
        }

        // Bounded wait for the app to write the pasteboard.
        let deadline = Date().addingTimeInterval(copyTimeout)
        var observedChange = false
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(pollInterval))
            let current = await MainActor.run { pasteboard.changeCount }
            if current != baseline {
                observedChange = true
                break
            }
        }

        guard observedChange else {
            // Nothing was copied: most likely there is no selection.
            return .noSelection
        }

        // Give the writing app a beat to finish declaring all types.
        try? await Task.sleep(for: .seconds(0.03))

        return await MainActor.run {
            let copiedChangeCount = pasteboard.changeCount
            let copied = pasteboard.string(forType: .string)

            defer {
                // Restore only if nothing wrote after the copy we caused.
                snapshot.restore(to: pasteboard, ifChangeCountEquals: copiedChangeCount)
            }

            guard let copied, !copied.isEmpty else {
                // A change occurred but no plain text (e.g. image selection).
                return .failure(.clipboardEmpty)
            }
            return .text(copied, source: .clipboard)
        }
    }

    /// Posts ⌘C key-down/key-up at the HID level. Requires Accessibility
    /// trust; returns false when the events could not be created.
    private func synthesizeCopyKeystroke() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return false }
        // Suppress local keystate merging so a physically held Option key
        // (from the hotkey) does not contaminate the synthetic ⌘C.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyCode = CGKeyCode(kVK_ANSI_C)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
