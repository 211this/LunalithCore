import Foundation

public enum LunalithMemoryKind: String, Codable, Sendable {
    case conversation
    case relationship
    case decision
    case preference
    case project
    case correction
    case milestone
}

public struct LunalithMemory: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public var kind: LunalithMemoryKind
    public var content: String
    public var importance: Double
    public var emotionalTone: Double
    public var confidence: Double
    public var provenance: LunalithProvenance
    public var epistemicStatus: LunalithEpistemicStatus
    public var tags: [String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        kind: LunalithMemoryKind,
        content: String,
        importance: Double = 0.5,
        emotionalTone: Double = 0,
        confidence: Double = 1,
        provenance: LunalithProvenance,
        epistemicStatus: LunalithEpistemicStatus,
        tags: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        self.importance = importance.lunalithClamped01
        self.emotionalTone = emotionalTone.lunalithClampedSigned
        self.confidence = confidence.lunalithClamped01
        self.provenance = provenance
        self.epistemicStatus = epistemicStatus
        self.tags = tags
    }
}

public struct LunalithMemoryRetriever: Sendable {
    public init() {}

    public func retrieve(
        query: String,
        from memories: [LunalithMemory],
        limit: Int = 8,
        excludingCurrentUserMessage currentMessage: String? = nil,
        requireOverlap: Bool = true,
        now: Date = Date()
    ) -> [LunalithMemory] {
        let limits = LunalithSafetyLimits.standard
        let boundedQuery = String(query.prefix(limits.maximumTextCharacters))
        let queryTokens = LunalithText.tokens(boundedQuery)
        let eligible = memories.prefix(limits.maximumRecordsPerCollection).filter { memory in
            guard memory.content.count <= limits.maximumTextCharacters else { return false }
            guard let currentMessage else { return true }
            return !LunalithText.containsCurrentUserRecord(memory.content, currentMessage: currentMessage)
        }

        // Importance and recency alone never qualify a record: without shared words,
        // unrelated memories would be injected into every prompt.
        let mustOverlap = requireOverlap && !queryTokens.isEmpty
        return eligible
            .filter { !mustOverlap || overlap($0, queryTokens: queryTokens) > 0 }
            .map { ($0, score($0, queryTokens: queryTokens, now: now)) }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 == $1.1 {
                    if $0.0.createdAt == $1.0.createdAt {
                        return $0.0.id.uuidString < $1.0.id.uuidString
                    }
                    return $0.0.createdAt > $1.0.createdAt
                }
                return $0.1 > $1.1
            }
            .prefix(max(0, limit))
            .map(\.0)
    }

    private func overlap(_ memory: LunalithMemory, queryTokens: Set<String>) -> Int {
        let combined = memory.content + " " + memory.tags.joined(separator: " ")
        let searchable = String(combined.prefix(LunalithSafetyLimits.standard.maximumTextCharacters))
        return queryTokens.intersection(LunalithText.tokens(searchable)).count
    }

    private func score(_ memory: LunalithMemory, queryTokens: Set<String>, now: Date) -> Double {
        let sharedWords = overlap(memory, queryTokens: queryTokens)
        let relationshipBonus: Double
        switch memory.kind {
        case .relationship, .decision, .correction, .milestone:
            relationshipBonus = 0.8
        default:
            relationshipBonus = 0
        }

        return Double(sharedWords)
            + memory.importance * 2
            + memory.confidence * 0.5
            + recencyWeight(memory.createdAt, now: now)
            + relationshipBonus
    }

    private func recencyWeight(_ date: Date, now: Date) -> Double {
        let days = max(0, now.timeIntervalSince(date)) / 86_400
        return 1 / (1 + days / 30)
    }
}

public protocol LunalithSnapshotStore: Sendable {
    func load() async throws -> LunalithSnapshot
    func save(_ snapshot: LunalithSnapshot) async throws
}

public struct LunalithSnapshot: Codable, Equatable, Sendable {
    public var state: LunalithState
    public var relationship: LunalithRelationshipState
    public var meaningGraph: LunalithMeaningGraph
    public var memories: [LunalithMemory]

    public init(
        state: LunalithState = .init(),
        relationship: LunalithRelationshipState = .init(),
        meaningGraph: LunalithMeaningGraph = .init(),
        memories: [LunalithMemory] = []
    ) {
        self.state = state
        self.relationship = relationship
        self.meaningGraph = meaningGraph
        self.memories = memories
    }

    private enum CodingKeys: String, CodingKey {
        case state
        case relationship
        case meaningGraph
        case memories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            state: try container.decode(LunalithState.self, forKey: .state),
            relationship: try container.decodeIfPresent(
                LunalithRelationshipState.self,
                forKey: .relationship
            ) ?? .init(),
            meaningGraph: try container.decode(LunalithMeaningGraph.self, forKey: .meaningGraph),
            memories: try container.decode([LunalithMemory].self, forKey: .memories)
        )
        try validate()
    }

    public func validate(limits: LunalithSafetyLimits = .standard) throws {
        guard memories.count <= limits.maximumRecordsPerCollection else {
            throw LunalithValidationError.tooManyRecords("memories")
        }
        guard meaningGraph.meanings.count <= limits.maximumRecordsPerCollection,
              meaningGraph.links.count <= limits.maximumRecordsPerCollection,
              meaningGraph.revisions.count <= limits.maximumRecordsPerCollection else {
            throw LunalithValidationError.tooManyRecords("meaningGraph")
        }

        try validateState()
        try validateRelationship()
        try validateMemories(limits: limits)
        try validateMeaningGraph(limits: limits)
    }

    private func validateState() throws {
        let values = [state.valence, state.arousal, state.resonance, state.velocity, state.momentum]
        guard values.allSatisfy({ $0.isFinite }) else {
            throw LunalithValidationError.nonFiniteValue("state")
        }
        guard (-1...1).contains(state.valence),
              (0...1).contains(state.arousal),
              (0...1).contains(state.resonance),
              (0.2...2).contains(state.velocity),
              (0...1).contains(state.momentum),
              state.interactionCount >= 0 else {
            throw LunalithValidationError.valueOutOfRange("state")
        }
    }

    private func validateRelationship() throws {
        let values = [
            relationship.rapport, relationship.trust, relationship.playfulness,
            relationship.friction, relationship.repair, relationship.novelty,
            relationship.momentum, relationship.uncertainty, relationship.engagement
        ]
        guard values.allSatisfy({ $0.isFinite }) else {
            throw LunalithValidationError.nonFiniteValue("relationship")
        }
        guard values.allSatisfy({ (0...1).contains($0) }), relationship.interactionCount >= 0 else {
            throw LunalithValidationError.valueOutOfRange("relationship")
        }
    }

    private func validateMemories(limits: LunalithSafetyLimits) throws {
        var ids = Set<UUID>()
        for memory in memories {
            guard !memory.content.isEmpty else {
                throw LunalithValidationError.emptyText("memory")
            }
            guard memory.content.count <= limits.maximumTextCharacters else {
                throw LunalithValidationError.textTooLong("memory")
            }
            guard memory.tags.count <= limits.maximumRecordsPerCollection,
                  memory.tags.allSatisfy({ $0.count <= limits.maximumTextCharacters }) else {
                throw LunalithValidationError.textTooLong("memoryTags")
            }
            guard ids.insert(memory.id).inserted else {
                throw LunalithValidationError.duplicateIdentifier("memory")
            }
            let values = [memory.importance, memory.emotionalTone, memory.confidence]
            guard values.allSatisfy({ $0.isFinite }) else {
                throw LunalithValidationError.nonFiniteValue("memory")
            }
            guard (0...1).contains(memory.importance),
                  (-1...1).contains(memory.emotionalTone),
                  (0...1).contains(memory.confidence) else {
                throw LunalithValidationError.valueOutOfRange("memory")
            }
        }
    }

    private func validateMeaningGraph(limits: LunalithSafetyLimits) throws {
        var meaningIDs = Set<UUID>()
        for meaning in meaningGraph.meanings {
            guard !meaning.statement.isEmpty else {
                throw LunalithValidationError.emptyText("meaning")
            }
            guard meaning.statement.count <= limits.maximumTextCharacters else {
                throw LunalithValidationError.textTooLong("meaning")
            }
            guard meaningIDs.insert(meaning.id).inserted else {
                throw LunalithValidationError.duplicateIdentifier("meaning")
            }
            let values = [meaning.significance, meaning.confidence, meaning.emotionalValence]
            guard values.allSatisfy({ $0.isFinite }) else {
                throw LunalithValidationError.nonFiniteValue("meaning")
            }
            guard (0...1).contains(meaning.significance),
                  (0...1).contains(meaning.confidence),
                  (-1...1).contains(meaning.emotionalValence),
                  meaning.reinforcementCount >= 1 else {
                throw LunalithValidationError.valueOutOfRange("meaning")
            }
        }
        for link in meaningGraph.links {
            guard meaningIDs.contains(link.sourceID), meaningIDs.contains(link.targetID) else {
                throw LunalithValidationError.danglingReference("meaningLink")
            }
            guard link.strength.isFinite, (0...1).contains(link.strength) else {
                throw LunalithValidationError.valueOutOfRange("meaningLink")
            }
        }
        for revision in meaningGraph.revisions {
            guard meaningIDs.contains(revision.originalMeaningID),
                  meaningIDs.contains(revision.revisedMeaningID) else {
                throw LunalithValidationError.danglingReference("meaningRevision")
            }
        }
    }
}
