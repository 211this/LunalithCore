import XCTest
@testable import LunalithCore

final class MeaningGraphTests: XCTestCase {
    func testEquivalentMeaningReinforcesInsteadOfDuplicating() {
        var graph = LunalithMeaningGraph()
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        let recorded = graph.record(
            "Humans mean well",
            significance: 0.8,
            confidence: 0.7,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed,
            id: firstID
        )
        let reinforced = graph.record(
            "  humans   mean WELL  ",
            significance: 0.9,
            confidence: 0.8,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed,
            id: duplicateID
        )

        XCTAssertEqual(recorded, firstID)
        XCTAssertEqual(reinforced, firstID)
        XCTAssertEqual(graph.meanings.count, 1)
        XCTAssertEqual(graph.meanings[0].reinforcementCount, 2)
    }

    func testCorrectionSupersedesWithoutErasingHistory() {
        var graph = LunalithMeaningGraph()
        let originalID = graph.record(
            "The light is red",
            significance: 0.8,
            confidence: 0.4,
            provenance: .systemObservation,
            epistemicStatus: .inferred
        )!

        let revisedID = graph.revise(
            originalID,
            to: "The light is orange",
            reason: "User correction"
        )!

        XCTAssertEqual(graph.meanings.first(where: { $0.id == originalID })?.status, .superseded)
        XCTAssertEqual(graph.meanings.first(where: { $0.id == revisedID })?.status, .revised)
        XCTAssertEqual(graph.meanings.first(where: { $0.id == revisedID })?.epistemicStatus, .corrected)
        XCTAssertEqual(graph.revisions.count, 1)
    }

    func testDeletionRemovesMeaningAndDependentGraphRecords() {
        var graph = LunalithMeaningGraph()
        let first = graph.record(
            "first",
            significance: 0.8,
            confidence: 1,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )!
        let second = graph.record(
            "second",
            significance: 0.7,
            confidence: 1,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )!
        _ = graph.connect(first, to: second, relationship: "supports")

        XCTAssertEqual(graph.deleteMeanings(withIDs: [first]), 1)
        XCTAssertFalse(graph.meanings.contains(where: { $0.id == first }))
        XCTAssertTrue(graph.links.isEmpty)
    }

    func testRepeatedInferenceDoesNotRaiseConfidence() {
        var graph = LunalithMeaningGraph()
        let id = graph.record(
            "The user is sad",
            significance: 0.5,
            confidence: 0.3,
            provenance: .conversation,
            epistemicStatus: .inferred
        )!
        for _ in 0..<5 {
            graph.record(
                "The user is sad",
                significance: 0.5,
                confidence: 0.95,
                provenance: .conversation,
                epistemicStatus: .inferred
            )
        }

        let meaning = graph.meanings.first(where: { $0.id == id })!
        XCTAssertEqual(meaning.confidence, 0.3)
        XCTAssertEqual(meaning.reinforcementCount, 6)
        XCTAssertEqual(meaning.epistemicStatus, .inferred)
    }

    func testUserConfirmationCanRaiseConfidence() {
        var graph = LunalithMeaningGraph()
        let id = graph.record(
            "Prefers mornings",
            significance: 0.5,
            confidence: 0.3,
            provenance: .conversation,
            epistemicStatus: .inferred
        )!
        graph.record(
            "Prefers mornings",
            significance: 0.5,
            confidence: 0.9,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )

        let meaning = graph.meanings.first(where: { $0.id == id })!
        XCTAssertEqual(meaning.confidence, 0.9)
        XCTAssertEqual(meaning.epistemicStatus, .userConfirmed)
    }

    func testRevisionKeepsSuppliedProvenance() {
        var graph = LunalithMeaningGraph()
        let originalID = graph.record(
            "The meeting is Monday",
            significance: 0.6,
            confidence: 0.5,
            provenance: .conversation,
            epistemicStatus: .inferred
        )!

        let revisedID = graph.revise(
            originalID,
            to: "The meeting is Tuesday",
            reason: "Model self-correction",
            provenance: .conversation
        )!

        XCTAssertEqual(graph.meanings.first(where: { $0.id == revisedID })?.provenance, .conversation)
    }
}
