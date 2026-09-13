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
        now: Date = Date()
    ) -> [LunalithMemory] {
        let queryTokens = LunalithText.tokens(query)
        let eligible = memories.filter { memory in
            guard let currentMessage else { return true }
            return !LunalithText.containsCurrentUserRecord(memory.content, currentMessage: currentMessage)
        }

        return eligible
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

    private func score(_ memory: LunalithMemory, queryTokens: Set<String>, now: Date) -> Double {
        let searchable = memory.content + " " + memory.tags.joined(separator: " ")
        let overlap = queryTokens.intersection(LunalithText.tokens(searchable)).count
        let relationshipBonus: Double
        switch memory.kind {
        case .relationship, .decision, .correction, .milestone:
            relationshipBonus = 0.8
        default:
            relationshipBonus = 0
        }

        return Double(overlap)
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
}
