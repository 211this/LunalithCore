import Foundation

public struct LunalithTurn: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let message: String
    public let shouldProcessState: Bool
    public let shouldJournalUserRecord: Bool
    public let shouldRouteNaturalFeedback: Bool

    public init(
        id: UUID = UUID(),
        message: String,
        shouldProcessState: Bool = true,
        shouldJournalUserRecord: Bool = true,
        shouldRouteNaturalFeedback: Bool = true
    ) {
        self.id = id
        self.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.shouldProcessState = shouldProcessState
        self.shouldJournalUserRecord = shouldJournalUserRecord
        self.shouldRouteNaturalFeedback = shouldRouteNaturalFeedback
    }
}

public struct LunalithTurnLedger: Codable, Equatable, Sendable {
    public private(set) var queued: [LunalithTurn]
    public private(set) var active: LunalithTurn?
    public private(set) var failed: LunalithTurn?

    public init(
        queued: [LunalithTurn] = [],
        active: LunalithTurn? = nil,
        failed: LunalithTurn? = nil
    ) {
        self.queued = queued
        self.active = active
        self.failed = failed
    }

    private enum CodingKeys: String, CodingKey {
        case queued
        case active
        case failed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            queued: try container.decodeIfPresent([LunalithTurn].self, forKey: .queued) ?? [],
            active: try container.decodeIfPresent(LunalithTurn.self, forKey: .active),
            failed: try container.decodeIfPresent(LunalithTurn.self, forKey: .failed)
        )
        try validate()
    }

    @discardableResult
    public mutating func submit(_ turn: LunalithTurn) -> Bool {
        let limits = LunalithSafetyLimits.standard
        guard !turn.message.isEmpty,
              turn.message.count <= limits.maximumTextCharacters,
              queued.count < limits.maximumRecordsPerCollection else { return false }
        queued.append(turn)
        return true
    }

    public mutating func beginNext() -> LunalithTurn? {
        guard active == nil, failed == nil, !queued.isEmpty else { return nil }
        let turn = queued.removeFirst()
        active = turn
        return turn
    }

    @discardableResult
    public mutating func complete(_ id: UUID) -> Bool {
        guard active?.id == id else { return false }
        active = nil
        return true
    }

    @discardableResult
    public mutating func fail(_ id: UUID) -> LunalithTurn? {
        guard failed == nil, let turn = active, turn.id == id else { return nil }
        active = nil
        let retry = LunalithTurn(
            id: turn.id,
            message: turn.message,
            shouldProcessState: false,
            shouldJournalUserRecord: false,
            shouldRouteNaturalFeedback: false
        )
        failed = retry
        return retry
    }

    @discardableResult
    public mutating func retryFailed() -> LunalithTurn? {
        guard let failed else { return nil }
        self.failed = nil
        queued.insert(failed, at: 0)
        return failed
    }

    @discardableResult
    public mutating func skipFailed() -> UUID? {
        let id = failed?.id
        failed = nil
        return id
    }

    public func validate(limits: LunalithSafetyLimits = .standard) throws {
        guard !(active != nil && failed != nil) else {
            throw LunalithValidationError.invalidTurnLedger("active and failed turns coexist")
        }
        let turns = queued + [active, failed].compactMap { $0 }
        guard turns.count <= limits.maximumRecordsPerCollection else {
            throw LunalithValidationError.tooManyRecords("turns")
        }
        guard turns.allSatisfy({ !$0.message.isEmpty }) else {
            throw LunalithValidationError.emptyText("turn")
        }
        guard turns.allSatisfy({ $0.message.count <= limits.maximumTextCharacters }) else {
            throw LunalithValidationError.textTooLong("turn")
        }
        guard Set(turns.map(\.id)).count == turns.count else {
            throw LunalithValidationError.duplicateIdentifier("turn")
        }
        if let failed {
            guard !failed.shouldProcessState,
                  !failed.shouldJournalUserRecord,
                  !failed.shouldRouteNaturalFeedback else {
                throw LunalithValidationError.invalidTurnLedger("failed turn can repeat side effects")
            }
        }
    }
}
