import Foundation
import LunalithHarness
import LunalithCore

/// lunalith-context: runs one Lunalith turn.
///
/// stdin:  {"message": "...", "snapshot": {...} or null, "timestamp": <unix seconds, optional>}
/// stdout: {"snapshot": {...}, "systemContext": "...", "state": {...},
///          "includedRecordCount": n, "omittedRecordCount": n}
/// Dates are unix seconds. The snapshot is opaque to callers: pass it back unchanged.
struct TurnInput: Decodable {
    var message: String
    var snapshot: LunalithSnapshot?
    var timestamp: Double?
}

@main
struct LunalithContextTool {
    static func main() async {
        do {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            let input = try decoder.decode(TurnInput.self, from: data)

            let turn = try await LunalithHarness.runTurn(
                message: input.message,
                snapshot: input.snapshot,
                at: input.timestamp.map { Date(timeIntervalSince1970: $0) } ?? Date()
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            FileHandle.standardOutput.write(try encoder.encode(turn))
        } catch {
            FileHandle.standardError.write(Data("lunalith-context: \(error)\n".utf8))
            exit(1)
        }
    }
}
