import XCTest
@testable import LunalithCore

final class MemoryAndContextTests: XCTestCase {
    func testRetrieverExcludesCurrentUserRecordEmbeddedInCompletedTurn() {
        let current = "Do you remember this?"
        let contaminated = LunalithMemory(
            kind: .conversation,
            content: "Lunalith: \(current)\nBridget: Yes.",
            provenance: .conversation,
            epistemicStatus: .observed
        )
        let eligible = LunalithMemory(
            kind: .relationship,
            content: "Remember that continuity should preserve corrections.",
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )

        let result = LunalithMemoryRetriever().retrieve(
            query: current,
            from: [contaminated, eligible],
            excludingCurrentUserMessage: current
        )

        XCTAssertFalse(result.contains(where: { $0.id == contaminated.id }))
        XCTAssertTrue(result.contains(where: { $0.id == eligible.id }))
    }

    func testRetrieverIgnoresImportantButUnrelatedMemories() {
        let unrelated = LunalithMemory(
            kind: .milestone,
            content: "Shipped first build.",
            importance: 1,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )
        let related = LunalithMemory(
            kind: .preference,
            content: "Prefers warm weather walks.",
            importance: 0.1,
            provenance: .userStatement,
            epistemicStatus: .userConfirmed
        )

        let retriever = LunalithMemoryRetriever()
        let result = retriever.retrieve(query: "How is the weather?", from: [unrelated, related])
        XCTAssertEqual(result.map(\.id), [related.id])

        let legacy = retriever.retrieve(
            query: "How is the weather?",
            from: [unrelated, related],
            requireOverlap: false
        )
        XCTAssertEqual(legacy.count, 2)
    }

    func testBudgetPreservesUserMessageAndNeverSlicesRecords() {
        let userMessage = String(repeating: "u", count: 500)
        let first = LunalithContextRecord(
            label: "UNRESOLVED",
            content: String(repeating: "a", count: 80),
            confidence: 0.2,
            provenance: .systemObservation,
            epistemicStatus: .unresolved
        )
        let second = LunalithContextRecord(
            label: "LOW PRIORITY",
            content: String(repeating: "b", count: 500),
            confidence: 0.5,
            provenance: .conversation,
            epistemicStatus: .inferred
        )

        let result = LunalithContextAssembler().assemble(
            userMessage: userMessage,
            sections: [LunalithContextSection(name: "STATE", records: [first, second])],
            characterBudget: 750
        )

        XCTAssertEqual(result.userMessage, userMessage)
        XCTAssertLessThanOrEqual(result.totalCharacterCount, result.effectiveBudget)
        XCTAssertTrue(result.providerContext.contains(first.rendered))
        XCTAssertFalse(result.providerContext.contains(second.content))
        XCTAssertTrue(result.omittedRecordIDs.contains(second.id))
    }

    func testContextDoesNotEchoCurrentMessageAsMemory() {
        let current = "I need space"
        let record = LunalithContextRecord(
            label: "MEMORY",
            content: "User: \(current)",
            confidence: 1,
            provenance: .conversation,
            epistemicStatus: .observed
        )

        let result = LunalithContextAssembler().assemble(
            userMessage: current,
            sections: [LunalithContextSection(name: "MEMORIES", records: [record])]
        )

        XCTAssertFalse(result.includedRecordIDs.contains(record.id))
        XCTAssertTrue(result.omittedRecordIDs.contains(record.id))
    }
}
