import XCTest
@testable import LunalithCore

final class TurnLedgerTests: XCTestCase {
    func testFIFOAndSingleActiveTurn() {
        var ledger = LunalithTurnLedger()
        let first = LunalithTurn(id: UUID(), message: "first")
        let second = LunalithTurn(id: UUID(), message: "second")

        XCTAssertTrue(ledger.submit(first))
        XCTAssertTrue(ledger.submit(second))
        XCTAssertEqual(ledger.beginNext()?.id, first.id)
        XCTAssertNil(ledger.beginNext())
        XCTAssertTrue(ledger.complete(first.id))
        XCTAssertEqual(ledger.beginNext()?.id, second.id)
    }

    func testFailurePausesQueueAndRetryDisablesRepeatedSideEffects() {
        var ledger = LunalithTurnLedger()
        let first = LunalithTurn(id: UUID(), message: "first")
        let second = LunalithTurn(id: UUID(), message: "second")
        ledger.submit(first)
        ledger.submit(second)
        _ = ledger.beginNext()

        let retry = ledger.fail(first.id)
        XCTAssertEqual(retry?.id, first.id)
        XCTAssertFalse(retry?.shouldProcessState ?? true)
        XCTAssertFalse(retry?.shouldJournalUserRecord ?? true)
        XCTAssertFalse(retry?.shouldRouteNaturalFeedback ?? true)
        XCTAssertNil(ledger.beginNext())

        XCTAssertEqual(ledger.retryFailed()?.id, first.id)
        XCTAssertEqual(ledger.beginNext()?.id, first.id)
    }
}
