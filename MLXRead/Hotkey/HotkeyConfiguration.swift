import CoreGraphics

/// The global shortcut definition. Shipped default: Option–Escape.
/// Kept as a value type so it can become user-configurable without touching
/// the tap service.
struct HotkeyConfiguration: Equatable, Sendable {
    /// Virtual key code (kVK_Escape = 53).
    var keyCode: Int64
    /// Required modifier flags (exact match on these device-independent bits).
    var requiredFlags: CGEventFlags
    /// Modifiers that must NOT be present.
    var disallowedFlags: CGEventFlags

    static let optionEscape = HotkeyConfiguration(
        keyCode: 53,
        requiredFlags: .maskAlternate,
        disallowedFlags: [.maskCommand, .maskControl, .maskShift]
    )

    var displayString: String { "⌥⎋" }

    /// Exact-match test against an event's flags: Option held, none of the
    /// disallowed modifiers. Caps Lock, Fn, and device-dependent bits are
    /// deliberately ignored.
    func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard keyCode == self.keyCode else { return false }
        guard flags.contains(requiredFlags) else { return false }
        return flags.isDisjoint(with: disallowedFlags)
    }
}

extension CGEventFlags {
    func isDisjoint(with other: CGEventFlags) -> Bool {
        rawValue & other.rawValue == 0
    }
}
