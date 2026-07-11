import AppKit
import ApplicationServices

/// Reads the selected text of the focused UI element via the Accessibility
/// API. All AX calls run off the main actor; they can block for the
/// messaging timeout when an app is unresponsive.
final class AXSelectedTextReader: Sendable {
    /// AX messaging timeout in seconds for our requests.
    private static let messagingTimeout: Float = 0.5

    func captureSelection() async -> SelectionCaptureResult {
        await Task.detached(priority: .userInitiated) {
            Self.captureNow()
        }.value
    }

    static func captureNow() -> SelectionCaptureResult {
        guard AXIsProcessTrusted() else { return .permissionDenied }

        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)

        var focusedRef: CFTypeRef?
        let focusedErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        switch focusedErr {
        case .success:
            break
        case .apiDisabled, .notImplemented:
            return .permissionDenied
        case .noValue, .cannotComplete:
            return .applicationUnavailable
        default:
            return .failure(.axError(focusedErr.rawValue))
        }
        guard let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else {
            return .applicationUnavailable
        }
        let focused = focusedRef as! AXUIElement
        AXUIElementSetMessagingTimeout(focused, messagingTimeout)

        // Primary: the element's own selected text.
        if let result = selectedText(of: focused) {
            return result
        }

        // Fallback within AX: selected text range + parameterized string
        // (some WebKit and custom views implement only this pair).
        if let result = selectedTextViaRange(of: focused) {
            return result
        }

        // The element exists but exposes no selection attributes at all.
        var names: CFArray?
        if AXUIElementCopyAttributeNames(focused, &names) == .success,
           let names = names as? [String],
           names.contains(kAXSelectedTextAttribute as String) || names.contains(kAXSelectedTextRangeAttribute as String) {
            // Attributes exist but held no text → genuinely no selection.
            return .noSelection
        }
        return .unsupported
    }

    private static func selectedText(of element: AXUIElement) -> SelectionCaptureResult? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        guard err == .success, let text = value as? String else { return nil }
        return text.isEmpty ? nil : .text(text, source: .accessibility)
    }

    private static func selectedTextViaRange(of element: AXUIElement) -> SelectionCaptureResult? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef,
              CFGetTypeID(rangeRef) == AXValueGetTypeID()
        else { return nil }

        let axValue = rangeRef as! AXValue
        var cfRange = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &cfRange), cfRange.length > 0 else { return nil }

        var stringRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            axValue,
            &stringRef
        ) == .success, let text = stringRef as? String, !text.isEmpty else { return nil }

        return .text(text, source: .accessibility)
    }
}
