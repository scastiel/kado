import SwiftUI
import KadoCore

/// The layout both of Today's bottom cards share — the tip nudge and
/// the Appearance announcement: a glyph, one short paragraph, and two
/// word-labelled actions, the second of which puts the card away.
///
/// **It draws no background of its own.** The tint and the rounded
/// corners come from `.listRowBackground` at the call site, exactly as
/// `HabitRowView`'s do, so the card is the same width and the same
/// system corner radius as the habit rows above it. Drawing its own
/// `RoundedRectangle` instead made it visibly narrower and squarer —
/// `KadoRadius.card` is 10pt against the list's ~30pt.
struct TodayNoticeCard: View {
    let systemImage: String
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let primaryIdentifier: String
    let onPrimary: () -> Void
    let hideIdentifier: String
    let onHide: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: KadoSpace.s3) {
            Image(systemName: systemImage)
                .font(.subheadline)
                .foregroundStyle(Color.kadoAccent)
                // The glyph repeats what the copy already says; leaving
                // it in the VoiceOver order would only add noise.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KadoSpace.s3) {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.kadoForegroundSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                actions
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KadoSpace.s4)
    }

    /// Both actions read as words rather than symbols. The dismiss used
    /// to be an `×` in the corner, which was worse twice over: a glyph
    /// with no label, in `kadoForegroundTertiary` on this tint, comes to
    /// 2.8:1 — under the 3:1 a non-text control needs, and it was the
    /// only way to put the card away.
    private var actions: some View {
        HStack(spacing: KadoSpace.s5) {
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.kadoAccent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(primaryIdentifier)

            Button(action: onHide) {
                Text("Not now")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.kadoForegroundSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(hideIdentifier)
        }
    }
}

extension View {
    /// The row treatment a ``TodayNoticeCard`` takes inside Today's
    /// `List`: the accent tint and the list's own corners from the row
    /// background, no separator, and zero insets because the card
    /// brings its own padding.
    func todayNoticeCardRow() -> some View {
        listRowBackground(Color.kadoAccentTint)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
    }
}
