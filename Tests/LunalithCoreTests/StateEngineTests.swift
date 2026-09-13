import XCTest
@testable import LunalithCore

final class StateEngineTests: XCTestCase {
    func testStateTransitionIsDeterministicAndBounded() {
        let engine = LunalithStateEngine()
        let state = LunalithState(valence: 0.9, arousal: 0.8, resonance: 0.95)
        let date = Date(timeIntervalSince1970: 1_000)
        let input = LunalithInput(text: "A difficult but meaningful correction", sentiment: -0.7)

        let first = engine.process(input, from: state, at: date)
        let second = engine.process(input, from: state, at: date)

        XCTAssertEqual(first, second)
        XCTAssertTrue((-1...1).contains(first.current.valence))
        XCTAssertTrue((0...1).contains(first.current.arousal))
        XCTAssertTrue((0...1).contains(first.current.resonance))
        XCTAssertTrue((0.2...2).contains(first.current.velocity))
        XCTAssertTrue((0...1).contains(first.current.momentum))
    }

    func testTelemetryRequiresExplicitConsent() {
        let engine = LunalithStateEngine()
        let state = LunalithState(arousal: 0.2)
        let denied = LunalithInput(
            text: "hello",
            telemetry: LunalithTelemetry(normalizedArousal: 1, consentGranted: false)
        )
        let granted = LunalithInput(
            text: "hello",
            telemetry: LunalithTelemetry(normalizedArousal: 1, consentGranted: true)
        )

        let deniedResult = engine.process(denied, from: state)
        let grantedResult = engine.process(granted, from: state)

        XCTAssertFalse(deniedResult.telemetryApplied)
        XCTAssertTrue(grantedResult.telemetryApplied)
        XCTAssertGreaterThan(grantedResult.current.arousal, deniedResult.current.arousal)
    }
}
