import Foundation

/// Result of normalizing captured selection text.
struct NormalizedText: Equatable, Sendable {
    let text: String
    let wasTruncated: Bool
    let originalLength: Int

    var isEmpty: Bool { text.isEmpty }
}

/// Deterministic text cleanup applied before chunking and synthesis.
enum TextNormalizer {

    /// Normalizes line endings, strips control characters, collapses
    /// pathological whitespace while preserving paragraph boundaries, and
    /// enforces a maximum character count (reporting truncation).
    static func normalize(_ raw: String, maximumLength: Int) -> NormalizedText {
        let originalLength = raw.count

        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            // Unicode separators that break sentence tokenization.
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ") // no-break space

        // Remove invisible control and formatting characters, keeping \n and \t.
        text = String(text.unicodeScalars.filter { scalar in
            if scalar == "\n" || scalar == "\t" { return true }
            if CharacterSet.controlCharacters.contains(scalar) { return false }
            // Zero-width and directional formatting characters.
            if CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{200E}\u{200F}\u{FEFF}\u{2060}").contains(scalar) {
                return false
            }
            return true
        })

        text = text.replacingOccurrences(of: "\t", with: " ")

        // Collapse horizontal whitespace runs; preserve newlines.
        text = text.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        // Trim spaces around line breaks.
        text = text.replacingOccurrences(of: " ?\n ?", with: "\n", options: .regularExpression)
        // Collapse 3+ newlines to a single paragraph boundary.
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        var truncated = false
        if text.count > maximumLength {
            truncated = true
            let hardEnd = text.index(text.startIndex, offsetBy: maximumLength)
            var cut = String(text[..<hardEnd])
            // Prefer ending on a word boundary so the last audible words are whole.
            if let lastSpace = cut.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards),
               cut.distance(from: cut.startIndex, to: lastSpace.lowerBound) > maximumLength / 2 {
                cut = String(cut[..<lastSpace.lowerBound])
            }
            text = cut.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return NormalizedText(text: text, wasTruncated: truncated, originalLength: originalLength)
    }
}
