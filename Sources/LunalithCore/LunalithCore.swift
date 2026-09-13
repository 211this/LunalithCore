import Foundation

/// A provider-neutral coordinator for Lunalith's deterministic state, meaning, memory,
/// and turn-lifecycle algorithms. It performs no networking, sensing, speech, or UI work.
public actor LunalithCore {
    public private(set) var snapshot: LunalithSnapshot
    public private(set) var turnLedger: LunalithTurnLedger

    private let stateEngine: LunalithStateEngine
    private let memoryRetriever: LunalithMemoryRetriever

    public init(
        snapshot: LunalithSnapshot = .init(),
        turnLedger: LunalithTurnLedger = .init(),
        stateConfiguration: LunalithStateConfiguration = .init()
    ) {
        self.snapshot = snapshot
        self.turnLedger = turnLedger
        self.stateEngine = LunalithStateEngine(configuration: stateConfiguration)
        self.memoryRetriever = LunalithMemoryRetriever()
    }

    @discardableResult
    public func submit(_ turn: LunalithTurn) -> Bool {
        turnLedger.submit(turn)
    }

    public func beginNextTurn() -> LunalithTurn? {
        turnLedger.beginNext()
    }

    @discardableResult
    public func completeTurn(_ id: UUID) -> Bool {
        turnLedger.complete(id)
    }

    @discardableResult
    public func failTurn(_ id: UUID) -> LunalithTurn? {
        turnLedger.fail(id)
    }

    @discardableResult
    public func retryFailedTurn() -> LunalithTurn? {
        turnLedger.retryFailed()
    }

    @discardableResult
    public func skipFailedTurn() -> UUID? {
        turnLedger.skipFailed()
    }

    @discardableResult
    public func process(_ input: LunalithInput, at timestamp: Date = Date()) -> LunalithTransition {
        let transition = stateEngine.process(input, from: snapshot.state, at: timestamp)
        snapshot.state = transition.current
        return transition
    }

    public func applyRelationshipDelta(
        _ delta: LunalithRelationshipDelta,
        at timestamp: Date = Date()
    ) {
        snapshot.relationship.apply(delta, at: timestamp)
    }

    @discardableResult
    public func remember(_ memory: LunalithMemory) -> Bool {
        let limits = LunalithSafetyLimits.standard
        guard !memory.content.isEmpty,
              memory.content.count <= limits.maximumTextCharacters,
              memory.tags.count <= limits.maximumRecordsPerCollection,
              memory.tags.allSatisfy({ $0.count <= limits.maximumTextCharacters }),
              snapshot.memories.count < limits.maximumRecordsPerCollection else { return false }
        if let index = snapshot.memories.firstIndex(where: { $0.id == memory.id }) {
            snapshot.memories[index] = memory
            return false
        }
        let normalized = LunalithText.normalized(memory.content)
        guard !snapshot.memories.contains(where: { LunalithText.normalized($0.content) == normalized }) else {
            return false
        }
        snapshot.memories.append(memory)
        return true
    }

    public func relevantMemories(
        for query: String,
        limit: Int = 8,
        excludingCurrentUserMessage currentMessage: String? = nil,
        now: Date = Date()
    ) -> [LunalithMemory] {
        memoryRetriever.retrieve(
            query: query,
            from: snapshot.memories,
            limit: limit,
            excludingCurrentUserMessage: currentMessage,
            now: now
        )
    }

    @discardableResult
    public func deleteMemories(withIDs ids: Set<UUID>) -> Int {
        let originalCount = snapshot.memories.count
        snapshot.memories.removeAll { ids.contains($0.id) }
        return originalCount - snapshot.memories.count
    }

    @discardableResult
    public func deleteMeanings(withIDs ids: Set<UUID>) -> Int {
        snapshot.meaningGraph.deleteMeanings(withIDs: ids)
    }

    public func replaceSnapshot(_ snapshot: LunalithSnapshot) throws {
        try snapshot.validate()
        self.snapshot = snapshot
    }

    public func replaceTurnLedger(_ turnLedger: LunalithTurnLedger) throws {
        try turnLedger.validate()
        self.turnLedger = turnLedger
    }
}
