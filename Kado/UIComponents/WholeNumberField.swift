import SwiftUI
import KadoCore

/// A text field for typing one whole number — the primary control of
/// the log sheets (issue #100).
///
/// Number pad, focused on appear so the keyboard is already up when
/// the sheet lands, and **the prefilled value is selected the moment
/// focus arrives**, so typing replaces it rather than appending to it
/// (`3` → `25`, not `325`). The selection goes through iOS 18's
/// `TextSelection` binding; there is no SwiftUI seam for "select all"
/// short of it.
///
/// The field owns only the text. The sheet keeps the `String` state,
/// prefills it in `.onAppear` (so the env calendar, not `.current`,
/// drives the lookup — see `TimerLogSheet`) and reads a number back
/// through `WholeNumberEntry`, which is where "what counts as a
/// number" lives, so it can be unit-tested away from the view.
struct WholeNumberField: View {
    /// What VoiceOver calls the field, and what it shows while empty.
    /// Deliberately not a `prompt` of `"0"`: an empty field is not
    /// zero — Save is disabled on it, while a typed 0 clears the day —
    /// so a `0` placeholder would show the one value the field can't
    /// currently save.
    let title: LocalizedStringKey
    @Binding var text: String

    @FocusState private var isFocused: Bool
    @State private var selection: TextSelection?
    /// Whether the prefill has already been selected. The selection is
    /// a one-time courtesy, not a rule about focus.
    @State private var hasSelectedPrefill = false

    var body: some View {
        TextField(title, text: $text, selection: $selection)
            .keyboardType(.numberPad)
            .focused($isFocused)
            .submitLabel(.done)
            // **Honoured on iOS 27, ignored on 26.5**, where the field
            // renders its prefill but never becomes first responder, so
            // the sheet lands with no keyboard and the user taps the
            // field before typing. Measured, not guessed: a probe read
            // `keyboards=0 hasKeyboardFocus=false` there. It is not a
            // timing problem — moving this to a `.task` behind a 50ms
            // and then a 400ms sleep changed nothing, and retrying
            // until `@FocusState` read back true wedged the app. Left
            // as the simplest form that works where it works; the
            // degraded path is still usable, and `hasSelectedPrefill`
            // below means the user's own first tap gets the select-all.
            .onAppear { isFocused = true }
            // On focus, not on appear: the selection only takes once the
            // field is first responder, and the text is prefilled by the
            // sheet's own `.onAppear`, which has run by the time focus
            // actually lands.
            //
            // **First focus only.** Selecting on every focus gain means
            // a user who dismissed the keyboard and tapped back in to
            // fix one digit has their caret replaced by a full
            // selection, and the next keystroke wipes what they typed.
            .onChange(of: isFocused) { _, focused in
                guard focused, !hasSelectedPrefill else { return }
                hasSelectedPrefill = true
                selectAll()
            }
    }

    private func selectAll() {
        selection = TextSelection(range: text.startIndex..<text.endIndex)
    }
}

/// Turns what was typed into a `WholeNumberField` into a number, and
/// back.
///
/// Stricter than `Int(_:format:)` on its own, which is lenient enough
/// to read `25abc` as 25, `12.7` as 12 and `1e3` as 1000: only whole-
/// number characters are accepted, so a field either holds a number
/// or it doesn't, and Save can be disabled on the latter. Still
/// locale-aware — the Arabic keyboard's number pad types Eastern
/// Arabic digits, which `Int("٢٥")` alone would refuse.
nonisolated struct WholeNumberEntry {
    var locale: Locale = .current

    /// The number `text` spells, or nil when it spells none: empty,
    /// non-digit characters, or too large to hold.
    func value(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isWholeNumber) else { return nil }
        return try? Int(trimmed, format: format)
    }

    /// `value` as the field should show it: the locale's digits, no
    /// grouping — `1,000` is not something to edit digit by digit.
    func text(for value: Int) -> String {
        value.formatted(format)
    }

    private var format: IntegerFormatStyle<Int> {
        IntegerFormatStyle<Int>().locale(locale).grouping(.never)
    }
}

#Preview {
    @Previewable @State var text = "25"
    Form {
        Section("Today's value") {
            HStack(alignment: .firstTextBaseline) {
                WholeNumberField(title: "Today's value", text: $text)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(verbatim: "of 8")
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
    .scrollContentBackground(.hidden)
    .background(Color.kadoBackground.ignoresSafeArea())
}

#Preview("Dark") {
    @Previewable @State var text = "150"
    Form {
        Section("Session length") {
            HStack(alignment: .firstTextBaseline) {
                WholeNumberField(title: "Session length", text: $text)
                    .font(.title2.weight(.semibold).monospacedDigit())
                Text(verbatim: "min")
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
    }
    .scrollContentBackground(.hidden)
    .background(Color.kadoBackground.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
