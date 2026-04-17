import Testing
import Foundation
@testable import Kado

@Suite("HabitType Codable")
struct HabitTypeCodingTests {
    @Test("Round-trip every HabitType case")
    func roundTrip() throws {
        let cases: [HabitType] = [
            .binary,
            .counter(target: 8),
            .timer(targetSeconds: 1800),
            .negative,
        ]
        for value in cases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(HabitType.self, from: data)
            #expect(decoded == value, "round-trip failed for \(value)")
        }
    }

    @Test("Canonical JSON shape is stable under sortedKeys")
    func canonicalShapes() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let cases: [(HabitType, String)] = [
            (.binary, #"{"kind":"binary"}"#),
            (.counter(target: 8), #"{"kind":"counter","target":8}"#),
            (.timer(targetSeconds: 1800), #"{"kind":"timer","targetSeconds":1800}"#),
            (.negative, #"{"kind":"negative"}"#),
        ]
        for (value, expected) in cases {
            let data = try encoder.encode(value)
            let actual = String(data: data, encoding: .utf8) ?? ""
            #expect(actual == expected, "case \(value): got \(actual)")
        }
    }

    @Test("Decoder accepts canonical JSON")
    func decodesCanonical() throws {
        let cases: [(String, HabitType)] = [
            (#"{"kind":"binary"}"#, .binary),
            (#"{"kind":"counter","target":8}"#, .counter(target: 8)),
            (#"{"kind":"timer","targetSeconds":1800}"#, .timer(targetSeconds: 1800)),
            (#"{"kind":"negative"}"#, .negative),
        ]
        for (json, expected) in cases {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(HabitType.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test("Decoder rejects unknown kind")
    func unknownKindRejected() {
        let data = #"{"kind":"checklist"}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(HabitType.self, from: data)
        }
    }
}
