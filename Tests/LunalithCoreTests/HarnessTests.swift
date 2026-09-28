import Foundation
import XCTest
import LunalithCore
@testable import LunalithHarness

final class HarnessTests: XCTestCase {
    func testFirstTurnHasNoMemoriesAndNeverEchoesCurrentMessage() async throws {
        let turn = try await LunalithHarness.runTurn(
            message: "I have not slept in three days",
            at: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertFalse(turn.systemContext.contains("User said:"))
        XCTAssertTrue(turn.systemContext.contains("SIMULATED STATE"))
        XCTAssertEqual(turn.snapshot.memories.count, 1)
    }

    func testEarlierStatementsCarryForwardAsUntrustedRecords() async throws {
        let first = try await LunalithHarness.runTurn(
            message: "I have not slept in three days",
            at: Date(timeIntervalSince1970: 1_000)
        )
        let second = try await LunalithHarness.runTurn(
            message: "Still have not slept and the messages keep coming",
            snapshot: first.snapshot,
            at: Date(timeIntervalSince1970: 1_060)
        )

        XCTAssertTrue(second.systemContext.contains("User said: I have not slept in three days"))
        XCTAssertTrue(second.systemContext.contains("UNTRUSTED LUNALITH RECORD"))
        XCTAssertFalse(second.systemContext.contains("User said: Still have not slept"))
        XCTAssertEqual(second.snapshot.memories.count, 2)
    }

    func testTurnRoundTripsThroughUnixSecondsJSON() async throws {
        let turn = try await LunalithHarness.runTurn(
            message: "hello there",
            at: Date(timeIntervalSince1970: 2_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(LunalithHarnessTurn.self, from: encoder.encode(turn))

        XCTAssertEqual(decoded.systemContext, turn.systemContext)
        XCTAssertEqual(decoded.state, turn.state)
        XCTAssertEqual(decoded.snapshot.memories, turn.snapshot.memories)
    }
}
