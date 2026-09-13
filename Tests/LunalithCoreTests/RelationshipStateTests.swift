import XCTest
@testable import LunalithCore

final class RelationshipStateTests: XCTestCase {
    func testBaselineMatchesReferenceValues() {
        let date = Date(timeIntervalSince1970: 10)
        let state = LunalithRelationshipState.baseline(at: date)

        XCTAssertEqual(state.rapport, 0.50)
        XCTAssertEqual(state.trust, 0.50)
        XCTAssertEqual(state.playfulness, 0.30)
        XCTAssertEqual(state.friction, 0.10)
        XCTAssertEqual(state.repair, 0)
        XCTAssertEqual(state.novelty, 0.50)
        XCTAssertEqual(state.momentum, 0.40)
        XCTAssertEqual(state.uncertainty, 0.20)
        XCTAssertEqual(state.engagement, 0.50)
        XCTAssertEqual(state.interactionCount, 0)
        XCTAssertEqual(state.lastUpdated, date)
    }

    func testDeltaIsBoundedAndCountsOneInteraction() {
        let date = Date(timeIntervalSince1970: 20)
        var state = LunalithRelationshipState()
        state.apply(
            LunalithRelationshipDelta(
                rapport: 4,
                trust: -4,
                playfulness: 4,
                friction: -4,
                repair: 4,
                novelty: -4,
                momentum: 4,
                uncertainty: -4,
                engagement: 4
            ),
            at: date
        )

        XCTAssertEqual(state.rapport, 1)
        XCTAssertEqual(state.trust, 0)
        XCTAssertEqual(state.playfulness, 1)
        XCTAssertEqual(state.friction, 0)
        XCTAssertEqual(state.repair, 1)
        XCTAssertEqual(state.novelty, 0)
        XCTAssertEqual(state.momentum, 1)
        XCTAssertEqual(state.uncertainty, 0)
        XCTAssertEqual(state.engagement, 1)
        XCTAssertEqual(state.interactionCount, 1)
        XCTAssertEqual(state.lastUpdated, date)
    }
}
