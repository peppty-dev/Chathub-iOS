import Foundation

extension String {
    /// Returns a user-facing formatted version of an interest phrase.
    /// - Applies localized title casing per word
    /// - Handles hyphenated and slash-separated words
    /// - Preserves common acronyms and platform names (AI, iOS, USA, etc.)
    var interestDisplayFormatted: String {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return self }

        let specialMappings: [String: String] = [
            "ios": "iOS",
            "iphone": "iPhone",
            "ipad": "iPad",
            "macos": "macOS",
            "macbook": "MacBook",
            "ai": "AI",
            "ml": "ML",
            "ar": "AR",
            "vr": "VR",
            "ui": "UI",
            "ux": "UX",
            "cpu": "CPU",
            "gpu": "GPU",
            "usa": "USA",
            "uk": "UK",
            "eu": "EU",
            "nba": "NBA",
            "nfl": "NFL",
            "fifa": "FIFA",
            "ufc": "UFC"
        ]

        let locale = Locale.current

        func formatToken(_ token: String) -> String {
            let lower = token.lowercased()
            if let mapped = specialMappings[lower] { return mapped }

            // Hyphenated or slash-separated segments
            if token.contains("-") {
                return token.split(separator: "-").map { formatToken(String($0)) }.joined(separator: "-")
            }
            if token.contains("/") {
                return token.split(separator: "/").map { formatToken(String($0)) }.joined(separator: "/")
            }

            // Apostrophes (e.g., john's, rock'n'roll)
            if token.contains("'") {
                return token.split(separator: "'").enumerated().map { idx, part in
                    let piece = String(part)
                    if idx == 0 { return piece.capitalized(with: locale) }
                    if piece.count == 1 && piece.lowercased() == "s" { return "s" }
                    return piece.capitalized(with: locale)
                }.joined(separator: "'")
            }

            return token.capitalized(with: locale)
        }

        let parts = trimmed.split(separator: " ")
        let formatted = parts.map { formatToken(String($0)) }.joined(separator: " ")
        return formatted
    }
}


