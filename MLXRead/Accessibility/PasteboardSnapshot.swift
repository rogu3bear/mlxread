import AppKit

/// Immutable capture of an `NSPasteboard`'s items, restorable later.
///
/// Restoration is refused when the pasteboard's `changeCount` no longer
/// matches the expected value — that means the user or another app wrote to
/// the pasteboard after our capture, and their data must win.
struct PasteboardSnapshot: Sendable {
    /// One dictionary of type → data per pasteboard item, in order.
    let items: [[String: Data]]
    /// The pasteboard's changeCount at capture time.
    let changeCount: Int

    @MainActor
    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items: [[String: Data]] = (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type.rawValue] = data
                }
            }
            return entry
        }
        return PasteboardSnapshot(items: items, changeCount: pasteboard.changeCount)
    }

    /// Restores the snapshot onto `pasteboard` only when its current
    /// `changeCount` equals `expectedChangeCount`. Returns true when the
    /// restore was performed.
    @MainActor
    @discardableResult
    func restore(to pasteboard: NSPasteboard, ifChangeCountEquals expectedChangeCount: Int) -> Bool {
        guard pasteboard.changeCount == expectedChangeCount else {
            AppLogger.selection.info("Skipping pasteboard restore: changeCount moved (external write)")
            return false
        }
        pasteboard.clearContents()
        guard !items.isEmpty else { return true } // pasteboard was empty; leave it cleared
        let restored: [NSPasteboardItem] = items.map { entry in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            return item
        }
        pasteboard.writeObjects(restored)
        return true
    }
}
