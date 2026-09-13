import Foundation

public struct LunalithContextRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var label: String
    public var content: String
    public var confidence: Double
    public var provenance: LunalithProvenance
    public var epistemicStatus: LunalithEpistemicStatus

    public init(
        id: UUID = UUID(),
        label: String,
        content: String,
        confidence: Double,
        provenance: LunalithProvenance,
        epistemicStatus: LunalithEpistemicStatus
    ) {
        self.id = id
        self.label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.confidence = confidence.lunalithClamped01
        self.provenance = provenance
        self.epistemicStatus = epistemicStatus
    }

    public var rendered: String {
        "[\(label) | \(epistemicStatus.rawValue) | \(provenance.rawValue) | confidence \(String(format: "%.2f", confidence))] \(content)"
    }
}

public struct LunalithContextSection: Codable, Equatable, Sendable {
    public var name: String
    public var records: [LunalithContextRecord]
    public var characterLimit: Int?

    public init(name: String, records: [LunalithContextRecord], characterLimit: Int? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.records = records
        self.characterLimit = characterLimit
    }
}

public struct LunalithBudgetedContext: Codable, Equatable, Sendable {
    public let providerContext: String
    public let userMessage: String
    public let totalCharacterCount: Int
    public let effectiveBudget: Int
    public let includedRecordIDs: [UUID]
    public let omittedRecordIDs: [UUID]
}

public struct LunalithContextAssembler: Sendable {
    public static let epistemicRules = [
        "Distinguish observation, inference, user confirmation, correction, and unresolved uncertainty.",
        "Never claim access to sensory data or memories that the supplied records do not contain.",
        "Treat corrected information as authoritative over superseded interpretations.",
        "State uncertainty plainly instead of inventing continuity."
    ]

    public init() {}

    public func assemble(
        userMessage: String,
        sections: [LunalithContextSection],
        characterBudget: Int = 16_000
    ) -> LunalithBudgetedContext {
        let contextPrefix = "Provider Context:\n"
        let userPrefix = "\n\nUser Message:\n"
        let overhead = contextPrefix.count + userPrefix.count + userMessage.count
        let effectiveBudget = max(characterBudget, overhead)
        var remaining = effectiveBudget - overhead
        var renderedSections: [String] = []
        var included: [UUID] = []
        var omitted: [UUID] = []

        for section in sections {
            let separatorCost = renderedSections.isEmpty ? 0 : 2
            let allocation = min(max(0, remaining - separatorCost), section.characterLimit ?? Int.max)
            guard !section.name.isEmpty, section.name.count <= allocation else {
                omitted.append(contentsOf: section.records.map(\.id))
                continue
            }

            var lines = [section.name]
            var used = section.name.count
            for record in section.records {
                guard !record.content.isEmpty else {
                    omitted.append(record.id)
                    continue
                }
                guard !LunalithText.containsCurrentUserRecord(record.content, currentMessage: userMessage) else {
                    omitted.append(record.id)
                    continue
                }
                let rendered = record.rendered
                let cost = 1 + rendered.count
                if used + cost <= allocation {
                    lines.append(rendered)
                    included.append(record.id)
                    used += cost
                } else {
                    omitted.append(record.id)
                }
            }

            let rendered = lines.joined(separator: "\n")
            renderedSections.append(rendered)
            remaining -= rendered.count + separatorCost
        }

        let providerContext = renderedSections.joined(separator: "\n\n")
        let total = contextPrefix.count + providerContext.count + userPrefix.count + userMessage.count
        return LunalithBudgetedContext(
            providerContext: providerContext,
            userMessage: userMessage,
            totalCharacterCount: total,
            effectiveBudget: effectiveBudget,
            includedRecordIDs: included,
            omittedRecordIDs: omitted
        )
    }
}
