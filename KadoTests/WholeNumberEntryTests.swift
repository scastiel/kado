import Foundation
import Testing
@testable import Kado

/// What the log sheets' number field accepts (issue #100). The
/// sheets disable Save on `nil`, so every case that reads back as a
/// number is one that will be written to the store, and every case
/// that doesn't is one the user has to fix.
@Suite("Whole-number entry")
struct WholeNumberEntryTests {

    private let en = WholeNumberEntry(locale: Locale(identifier: "en_US"))

    @Test("Digits read as the number they spell", arguments: [
        ("25", 25), ("0", 0), ("007", 7), (" 25 ", 25), ("999999", 999_999),
    ])
    func digitsParse(text: String, expected: Int) {
        #expect(en.value(from: text) == expected)
    }

    /// The reason for the strict pass in front of `Int(_:format:)`,
    /// which on its own reads `25abc` as 25 and `12.7` as 12.
    @Test("Anything that is not only digits reads as no number", arguments: [
        "", "   ", "abc", "25abc", "12.7", "1e3", "-5", "1,000", "2 5",
    ])
    func junkDoesNotParse(text: String) {
        #expect(en.value(from: text) == nil)
    }

    @Test("A number too large to hold reads as no number, not as garbage")
    func overflowDoesNotParse() {
        #expect(en.value(from: "99999999999999999999999") == nil)
    }

    /// The Arabic keyboard's number pad types these; `Int("٢٥")` alone
    /// would refuse them and leave Save disabled with a valid number in
    /// the field.
    @Test("Eastern Arabic digits parse")
    func easternArabicDigitsParse() {
        let ar = WholeNumberEntry(locale: Locale(identifier: "ar_EG"))
        #expect(ar.value(from: "٢٥") == 25)
        #expect(en.value(from: "٢٥") == 25)
    }

    @Test("The prefilled text is ungrouped, so it can be edited digit by digit")
    func prefillIsUngrouped() {
        #expect(en.text(for: 1_000) == "1000")
        let fr = WholeNumberEntry(locale: Locale(identifier: "fr_FR"))
        #expect(fr.text(for: 1_000) == "1000")
    }

    @Test("Formatting then parsing is the identity, in every locale the field can show")
    func roundTrip() {
        for identifier in ["en_US", "fr_FR", "ar_EG", "hi_IN", "de_DE"] {
            let entry = WholeNumberEntry(locale: Locale(identifier: identifier))
            for value in [0, 1, 25, 150, 1_440, 999_999] {
                #expect(entry.value(from: entry.text(for: value)) == value, "\(identifier) \(value)")
            }
        }
    }
}
