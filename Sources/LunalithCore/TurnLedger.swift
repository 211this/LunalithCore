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

    @discardableResult
    public mutating func submit(_ turn: LunalithTurn) -> Bool {
        guard !turn.message.isEmpty else { return false }
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
}
