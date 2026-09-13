import Foundation

public enum LunalithMeaningStatus: String, Codable, Sendable {
    case active
    case unresolved
    case revised
    case superseded
}

public struct LunalithMeaning: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var statement: String
    public var significance: Double
    public var confidence: Double
    public var emotionalValence: Double
    public var status: LunalithMeaningStatus
    public var provenance: LunalithProvenance
    public var epistemicStatus: LunalithEpistemicStatus
    public let firstSeen: Date
    public var lastReinforced: Date
    public var reinforcementCount: Int

    public init(
        id: UUID = UUID(),
        statement: String,
        significance: Double,
        confidence: Double,
        emotionalValence: Double,
        status: LunalithMeaningStatus,
        provenance: LunalithProvenance,
        epistemicStatus: LunalithEpistemicStatus,
        firstSeen: Date = Date(),
        lastReinforced: Date = Date(),
        reinforcementCount: Int = 1
    ) {
        self.id = id
        self.statement = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        self.significance = significance.lunalithClamped01
        self.confidence = confidence.lunalithClamped01
        self.emotionalValence = emotionalValence.lunalithClampedSigned
        self.status = status
        self.provenance = provenance
        self.epistemicStatus = epistemicStatus
        self.firstSeen = firstSeen
        self.lastReinforced = lastReinforced
        self.reinforcementCount = max(1, reinforcementCount)
    }
}

public struct LunalithMeaningLink: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceID: UUID
    public let targetID: UUID
    public var relationship: String
    public var strength: Double
    public let createdAt: Date
    public var lastReinforced: Date

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        targetID: UUID,
        relationship: String,
        strength: Double,
        createdAt: Date = Date(),
        lastReinforced: Date = Date()
    ) {
        self.id = id
        self.sourceID = sourceID
        self.targetID = targetID
        self.relationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        self.strength = strength.lunalithClamped01
        self.createdAt = createdAt
        self.lastReinforced = lastReinforced
    }
}

public struct LunalithMeaningRevision: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let originalMeaningID: UUID
    public let revisedMeaningID: UUID
    public let reason: String
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        originalMeaningID: UUID,
        revisedMeaningID: UUID,
        reason: String,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.originalMeaningID = originalMeaningID
        self.revisedMeaningID = revisedMeaningID
        self.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        self.timestamp = timestamp
    }
}

public struct LunalithOrientation: Codable, Equatable, Sendable {
    public var activeMeanings: [LunalithMeaning]
    public var unresolvedMeanings: [LunalithMeaning]
    public var recentRevisions: [LunalithMeaningRevision]
    public var strongestLinks: [LunalithMeaningLink]
}

public struct LunalithMeaningGraph: Codable, Equatable, Sendable {
    public private(set) var meanings: [LunalithMeaning]
    public private(set) var links: [LunalithMeaningLink]
    public private(set) var revisions: [LunalithMeaningRevision]

    public init(
        meanings: [LunalithMeaning] = [],
        links: [LunalithMeaningLink] = [],
        revisions: [LunalithMeaningRevision] = []
    ) {
        self.meanings = meanings
        self.links = links
        self.revisions = revisions
    }

    @discardableResult
    public mutating func record(
        _ statement: String,
        significance: Double,
        confidence: Double,
        emotionalValence: Double = 0,
        provenance: LunalithProvenance,
        epistemicStatus: LunalithEpistemicStatus,
        status: LunalithMeaningStatus = .active,
        id: UUID = UUID(),
        at timestamp: Date = Date()
    ) -> UUID? {
        let clean = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let normalized = LunalithText.normalized(clean)

        if let index = meanings.firstIndex(where: {
            $0.status != .superseded && LunalithText.normalized($0.statement) == normalized
        }) {
            meanings[index].significance = max(meanings[index].significance, significance.lunalithClamped01)
            meanings[index].confidence = max(meanings[index].confidence, confidence.lunalithClamped01)
            meanings[index].emotionalValence = (
                meanings[index].emotionalValence + emotionalValence.lunalithClampedSigned
            ) / 2
            meanings[index].lastReinforced = timestamp
            meanings[index].reinforcementCount += 1
            if status == .unresolved { meanings[index].status = .unresolved }
            if status == .revised { meanings[index].status = .revised }
            if epistemicRank(epistemicStatus) > epistemicRank(meanings[index].epistemicStatus) {
                meanings[index].epistemicStatus = epistemicStatus
                meanings[index].provenance = provenance
            }
            return meanings[index].id
        }

        meanings.append(
            LunalithMeaning(
                id: id,
                statement: clean,
                significance: significance,
                confidence: confidence,
                emotionalValence: emotionalValence,
                status: status,
                provenance: provenance,
                epistemicStatus: epistemicStatus,
                firstSeen: timestamp,
                lastReinforced: timestamp
            )
        )
        return id
    }

    @discardableResult
    public mutating func markUnresolved(
        _ statement: String,
        significance: Double = 0.8,
        id: UUID = UUID(),
        at timestamp: Date = Date()
    ) -> UUID? {
        record(
            statement,
            significance: significance,
            confidence: 0.25,
            provenance: .systemObservation,
            epistemicStatus: .unresolved,
            status: .unresolved,
            id: id,
            at: timestamp
        )
    }

    @discardableResult
    public mutating func connect(
        _ sourceID: UUID,
        to targetID: UUID,
        relationship: String,
        strength: Double = 0.5,
        id: UUID = UUID(),
        at timestamp: Date = Date()
    ) -> UUID? {
        let clean = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sourceID != targetID,
              !clean.isEmpty,
              meanings.contains(where: { $0.id == sourceID }),
              meanings.contains(where: { $0.id == targetID }) else { return nil }

        if let index = links.firstIndex(where: {
            $0.sourceID == sourceID
                && $0.targetID == targetID
                && $0.relationship.caseInsensitiveCompare(clean) == .orderedSame
        }) {
            links[index].strength = (links[index].strength + max(0, strength) * 0.15).lunalithClamped01
            links[index].lastReinforced = timestamp
            return links[index].id
        }

        links.append(
            LunalithMeaningLink(
                id: id,
                sourceID: sourceID,
                targetID: targetID,
                relationship: clean,
                strength: strength,
                createdAt: timestamp,
                lastReinforced: timestamp
            )
        )
        return id
    }

    @discardableResult
    public mutating func revise(
        _ originalID: UUID,
        to revisedStatement: String,
        reason: String,
        confidence: Double = 1,
        revisedID: UUID = UUID(),
        revisionID: UUID = UUID(),
        at timestamp: Date = Date()
    ) -> UUID? {
        guard let index = meanings.firstIndex(where: { $0.id == originalID }) else { return nil }
        let original = meanings[index]
        let oldStatus = meanings[index].status
        meanings[index].status = .superseded
        meanings[index].lastReinforced = timestamp

        guard let newID = record(
            revisedStatement,
            significance: original.significance,
            confidence: confidence,
            emotionalValence: original.emotionalValence,
            provenance: .userStatement,
            epistemicStatus: .corrected,
            status: .revised,
            id: revisedID,
            at: timestamp
        ) else {
            meanings[index].status = oldStatus
            return nil
        }

        revisions.append(
            LunalithMeaningRevision(
                id: revisionID,
                originalMeaningID: originalID,
                revisedMeaningID: newID,
                reason: reason,
                timestamp: timestamp
            )
        )

        let inherited = links.compactMap { link -> LunalithMeaningLink? in
            if link.sourceID == originalID {
                return LunalithMeaningLink(
                    sourceID: newID,
                    targetID: link.targetID,
                    relationship: link.relationship,
                    strength: link.strength,
                    createdAt: timestamp,
                    lastReinforced: timestamp
                )
            }
            if link.targetID == originalID {
                return LunalithMeaningLink(
                    sourceID: link.sourceID,
                    targetID: newID,
                    relationship: link.relationship,
                    strength: link.strength,
                    createdAt: timestamp,
                    lastReinforced: timestamp
                )
            }
            return nil
        }
        links.append(contentsOf: inherited)
        return newID
    }

    public func orientation(maxActive: Int = 12) -> LunalithOrientation {
        let active = meanings
            .filter { $0.status == .active || $0.status == .revised }
            .sorted { score($0) > score($1) }

        return LunalithOrientation(
            activeMeanings: Array(active.prefix(max(0, maxActive))),
            unresolvedMeanings: Array(
                meanings.filter { $0.status == .unresolved }
                    .sorted { $0.significance > $1.significance }
                    .prefix(6)
            ),
            recentRevisions: Array(revisions.sorted { $0.timestamp > $1.timestamp }.prefix(6)),
            strongestLinks: Array(links.sorted { $0.strength > $1.strength }.prefix(12))
        )
    }

    @discardableResult
    public mutating func deleteMeanings(withIDs ids: Set<UUID>) -> Int {
        let originalCount = meanings.count
        meanings.removeAll { ids.contains($0.id) }
        links.removeAll { ids.contains($0.sourceID) || ids.contains($0.targetID) }
        revisions.removeAll {
            ids.contains($0.originalMeaningID) || ids.contains($0.revisedMeaningID)
        }
        return originalCount - meanings.count
    }

    private func score(_ meaning: LunalithMeaning) -> Double {
        meaning.significance * meaning.confidence
            + min(0.25, Double(meaning.reinforcementCount) * 0.01)
    }

    private func epistemicRank(_ status: LunalithEpistemicStatus) -> Int {
        switch status {
        case .unresolved: return 0
        case .inferred: return 1
        case .observed: return 2
        case .userConfirmed: return 3
        case .corrected: return 4
        }
    }
}
