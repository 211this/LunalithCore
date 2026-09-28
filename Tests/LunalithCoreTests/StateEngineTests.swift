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

    func testCalmInputLowersArousalInsteadOfHoldingPeak() {
        let engine = LunalithStateEngine()
        let date = Date(timeIntervalSince1970: 1_000)
        let state = LunalithState(arousal: 0.9, lastUpdated: date)

        let result = engine.process(LunalithInput(text: "okay", sentiment: 0), from: state, at: date)

        XCTAssertLessThan(result.current.arousal, 0.9)
    }

    func testArousalSettlesTowardBaselineOverRepeatedCalmTurns() {
        let engine = LunalithStateEngine()
        let date = Date(timeIntervalSince1970: 1_000)
        var state = LunalithState(arousal: 1.0, lastUpdated: date)

        for _ in 0..<40 {
            state = engine.process(LunalithInput(text: "calm", sentiment: 0), from: state, at: date).current
        }

        XCTAssertEqual(state.arousal, engine.configuration.baselineArousal, accuracy: 0.01)
    }

    func testArousalDecaysWithIdleTimeFromTimestamps() {
        let engine = LunalithStateEngine()
        let start = Date(timeIntervalSince1970: 1_000)
        let state = LunalithState(arousal: 1.0, lastUpdated: start)
        let oneHalfLifeLater = start.addingTimeInterval(engine.configuration.arousalHalfLife)

        // Idle decay: 0.4 + (1.0 - 0.4) * 0.5 = 0.7, then blend toward 0.4 at rate 0.25.
        let result = engine.process(
            LunalithInput(text: "back", sentiment: 0),
            from: state,
            at: oneHalfLifeLater
        )

        XCTAssertEqual(result.current.arousal, 0.625, accuracy: 1e-9)
    }

    func testIntenseInputStillRaisesArousal() {
        let engine = LunalithStateEngine()
        let date = Date(timeIntervalSince1970: 1_000)
        let state = LunalithState(arousal: 0.4, lastUpdated: date)

        let result = engine.process(LunalithInput(text: "wow", sentiment: 1), from: state, at: date)

        XCTAssertGreaterThan(result.current.arousal, 0.4)
    }

    func testConfigurationDecodesWithoutHomeostasisFields() throws {
        let legacyJSON = """
        {"valenceLearningRate":0.2,"arousalLearningRate":0.25,"resonanceGain":0.12,
         "resonanceDecay":0.02,"momentumRetention":0.8}
        """
        let config = try JSONDecoder().decode(
            LunalithStateConfiguration.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertEqual(config, LunalithStateConfiguration())
    }
}
