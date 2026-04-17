import Foundation

/// Detects the content type of clipboard text using heuristics
enum ContentTypeDetector {
    /// Code indicator keywords
    private static let codeIndicators = [
        "fn ", "func ", "def ", "class ", "import ", "from ", "#include",
        "const ", "let ", "var ", "function ", "return ", "if (", "for (",
        "while (", "pub fn", "async ", "await ", "=>", "->", "::", "println!",
        "console.log", "System.out", "<?php", "package ", "struct ",
    ]

    /// Detect the type of the given text
    static func detect(_ text: String) -> ClipType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // URL detection
        if (trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("ftp://"))
            && !trimmed.contains("\n") {
            return .url
        }

        // Code detection heuristics
        let lineCount = trimmed.components(separatedBy: .newlines).count
        let hasBraces = trimmed.contains("{") && trimmed.contains("}")
        let indicatorCount = codeIndicators.filter { trimmed.contains($0) }.count

        if (indicatorCount >= 2 && lineCount >= 3) ||
           (hasBraces && indicatorCount >= 1 && lineCount >= 5) {
            return .code
        }

        return .text
    }
}
