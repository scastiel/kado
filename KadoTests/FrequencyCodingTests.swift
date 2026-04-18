import Testing
import Foundation
@testable import Kado
import KadoCore

@Suite("Frequency Codable")
struct FrequencyCodingTests {
    @Test("Round-trip every Frequency case")
    func roundTrip() throws {
        let cases: [Frequency] = [
            .daily,
            .daysPerWeek(3),
            .specificDays([.monday, .wednesday, .friday]),
            .everyNDays(7),
        ]
        for value in cases {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(Frequency.self, from: data)
            #expect(decoded == value, "round-trip failed for \(value)")
        }
    }

    @Test("Canonical JSON shape is stable under sortedKeys")
    func canonicalShapes() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        let cases: [(Frequency, String)] = [
            (.daily, #"{"kind":"daily"}"#),
            (.daysPerWeek(3), #"{"count":3,"kind":"daysPerWeek"}"#),
            (.specificDays([.monday, .friday]), #"{"days":[2,6],"kind":"specificDays"}"#),
            (.everyNDays(7), #"{"interval":7,"kind":"everyNDays"}"#),
        ]
        for (value, expected) in cases {
            let data = try encoder.encode(value)
            let actual = String(data: data, encoding: .utf8) ?? ""
            #expect(actual == expected, "case \(value): got \(actual)")
        }
    }

    @Test("Decoder accepts canonical JSON")
    func decodesCanonical() throws {
        let cases: [(String, Frequency)] = [
            (#"{"kind":"daily"}"#, .daily),
            (#"{"kind":"daysPerWeek","count":3}"#, .daysPerWeek(3)),
            (#"{"kind":"specificDays","days":[2,6]}"#, .specificDays([.monday, .friday])),
            (#"{"kind":"everyNDays","interval":7}"#, .everyNDays(7)),
        ]
        for (json, expected) in cases {
            let data = json.data(using: .utf8)!
            let decoded = try JSONDecoder().decode(Frequency.self, from: data)
            #expect(decoded == expected)
        }
    }

    @Test("Decoder rejects unknown kind")
    func unknownKindRejected() {
        let data = #"{"kind":"weekly"}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Frequency.self, from: data)
        }
    }

    @Test("Decoder accepts specificDays in any input order")
    func specificDaysOrderInsensitive() throws {
        let json1 = #"{"kind":"specificDays","days":[2,4,6]}"#.data(using: .utf8)!
        let json2 = #"{"kind":"specificDays","days":[6,2,4]}"#.data(using: .utf8)!
        let decoded1 = try JSONDecoder().decode(Frequency.self, from: json1)
        let decoded2 = try JSONDecoder().decode(Frequency.self, from: json2)
        #expect(decoded1 == decoded2)
        #expect(decoded1 == .specificDays([.monday, .wednesday, .friday]))
    }
}
