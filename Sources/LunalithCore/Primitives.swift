import Foundation

public enum LunalithEpistemicStatus: String, Codable, Sendable, CaseIterable {
    case observed
    case inferred
    case userConfirmed
    case corrected
    case unresolved
}

public enum LunalithProvenance: String, Codable, Sendable, CaseIterable {
    case userStatement
    case conversation
    case consentedTelemetry
    case systemObservation
    case imported
}

enum LunalithText {
    static func normalized(_ content: String) -> String {
        var normalized = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        for prefix in ["lunalith:", "user:"] where normalized.hasPrefix(prefix) {
            normalized = String(normalized.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespaces)
            break
        }
        return normalized
    }

    static func tokens(_ content: String) -> Set<String> {
        Set(words(content))
    }

    static func words(_ content: String) -> [String] {
        normalized(content)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }
    }

    static func containsCurrentUserRecord(_ content: String, currentMessage: String) -> Bool {
        let current = normalized(currentMessage)
        guard !current.isEmpty else { return false }
        if normalized(content) == current { return true }

        return content.split(whereSeparator: { $0.isNewline }).contains { line in
            let value = String(line).trimmingCharacters(in: .whitespaces)
            let lowercased = value.lowercased()
            guard lowercased.hasPrefix("lunalith:") || lowercased.hasPrefix("user:") else {
                return false
            }
            return normalized(value) == current
        }
    }
}

extension Double {
    var lunalithClamped01: Double { min(1, max(0, self)) }
    var lunalithClampedSigned: Double { min(1, max(-1, self)) }
}
