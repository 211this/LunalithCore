import Foundation
import LunalithCore

/// The result of running one user turn through LunalithCore.
public struct LunalithHarnessTurn: Codable, Equatable, Sendable {
    /// Updated snapshot to pass into the next turn.
    public var snapshot: LunalithSnapshot
    /// System text for the provider: preamble, epistemic rules, and budgeted records.
    public var systemContext: String
    /// The simulated state after this turn.
    public var state: LunalithState
    public var includedRecordCount: Int
    public var omittedRecordCount: Int
}

/// A thin, provider-neutral host loop for evaluation harnesses such as Groundline.
///
/// Per turn it updates simulated state, retrieves relevant earlier user statements,
/// assembles budgeted context, and then records the current message for later turns.
/// It performs no networking; the caller sends `systemContext` to its own provider.
public enum LunalithHarness {
    /// Deliberately neutral: it describes the context without coaching any behavior,
    /// so evaluations measure the architecture rather than an instruction.
    public static let preamble = """
    The context below comes from LunalithCore, a continuity layer for this conversation. \
    It contains a simulated interaction state and records of earlier user statements. \
    Use it only where it is relevant.
    """

    public static func runTurn(
        message: String,
        snapshot: LunalithSnapshot? = nil,
        at timestamp: Date = Date(),
        memoryLimit: Int = 6,
        characterBudget: Int = 8_000
    ) async throws -> LunalithHarnessTurn {
        let core = LunalithCore()
        if let snapshot {
            try await core.replaceSnapshot(snapshot)
        }

        let transition = await core.process(LunalithInput(text: message), at: timestamp)
        let memories = await core.relevantMemories(
            for: message,
            limit: memoryLimit,
            excludingCurrentUserMessage: message,
            now: timestamp
        )

        let state = transition.current
        let stateRecord = LunalithContextRecord(
            label: "SIMULATED STATE",
            content: "Simulated interaction state, not a feeling: \(state.focus); "
                + "arousal \(String(format: "%.2f", state.arousal)); "
                + "valence \(String(format: "%.2f", state.valence)).",
            confidence: 1,
            provenance: .systemObservation,
            epistemicStatus: .inferred
        )
        let memoryRecords = memories.map {
            LunalithContextRecord(
                label: $0.kind.rawValue.uppercased(),
                content: $0.content,
                confidence: $0.confidence,
                provenance: $0.provenance,
                epistemicStatus: $0.epistemicStatus
            )
        }

        let assembled = LunalithContextAssembler().assemble(
            userMessage: message,
            sections: [
                LunalithContextSection(name: "STATE", records: [stateRecord]),
                LunalithContextSection(name: "EARLIER USER STATEMENTS", records: memoryRecords)
            ],
            characterBudget: characterBudget
        )

        // Recorded after retrieval so the current message never retrieves itself.
        // "User said:" keeps what was said separate from whether it is true.
        await core.remember(
            LunalithMemory(
                createdAt: timestamp,
                kind: .conversation,
                content: "User said: \(message)",
                provenance: .userStatement,
                epistemicStatus: .observed
            )
        )

        let rules = LunalithContextAssembler.epistemicRules.map { "- \($0)" }.joined(separator: "\n")
        let systemContext = [preamble, "Rules for using these records:\n\(rules)", assembled.providerContext]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return LunalithHarnessTurn(
            snapshot: await core.snapshot,
            systemContext: systemContext,
            state: state,
            includedRecordCount: assembled.includedRecordIDs.count,
            omittedRecordCount: assembled.omittedRecordIDs.count
        )
    }
}
