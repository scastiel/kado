import SwiftData
import SwiftUI
import KadoCore

/// Plays the day-complete celebration over whatever is on screen.
///
/// Watches `DayCompletionCelebration.celebrationCount` — which moves
/// the moment the last habit scheduled for today is completed, from
/// any surface — and answers with a burst of confetti and a short
/// caption. Under Reduce Motion the particles are dropped and the
/// caption simply fades. Either way VoiceOver hears an announcement,
/// because the row's own "done" label says nothing about the day.
///
/// Applied at the top of the tab view rather than on Today: a
/// completion from Detail, from the Overview popover, or from a Siri
/// intent should celebrate on the screen the user is actually looking
/// at.
struct DayCompletionCelebrationModifier: ViewModifier {
    @Environment(\.dayCompletionCelebration) private var celebration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The run in progress, keyed by the celebration that started it,
    /// so a second edge mid-run restarts the effect instead of being
    /// swallowed.
    @State private var run: Run?

    private struct Run: Equatable {
        let id: Int
        let startedAt: Date
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if let run {
                    // No transition here: one on the whole overlay
                    // would slide the confetti canvas in along with
                    // the caption, and a burst that is translating
                    // while it pops reads as wrong before anything
                    // else does. Each part brings its own, below.
                    CelebrationOverlay(
                        startedAt: run.startedAt,
                        reduceMotion: reduceMotion
                    )
                    .id(run.id)
                }
            }
            .onChange(of: celebration.celebrationCount) { _, count in
                guard count > 0 else { return }
                withAnimation(reduceMotion ? nil : KadoMotion.slow) {
                    run = Run(id: count, startedAt: .now)
                }
                AccessibilityNotification.Announcement(
                    String(localized: "All done for today")
                ).post()
            }
            .task(id: run?.id) {
                guard run != nil else { return }
                guard (try? await Task.sleep(for: .seconds(ConfettiView.duration))) != nil else {
                    return
                }
                withAnimation(reduceMotion ? nil : KadoMotion.slow) {
                    run = nil
                }
            }
    }
}

/// The confetti canvas, edge to edge, with the caption pinned under
/// the top safe area. Neither takes touches.
private struct CelebrationOverlay: View {
    let startedAt: Date
    let reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .top) {
            if !reduceMotion {
                // The canvas draws nothing until its own clock starts,
                // so it only needs to be there, not to arrive: a plain
                // fade on removal, and no movement of its own.
                ConfettiView(startedAt: startedAt)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            caption
                .padding(.top, KadoSpace.s3)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .move(edge: .top).combined(with: .opacity)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var caption: some View {
        Label("All done for today", systemImage: "checkmark.seal.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.kadoForeground)
            .padding(.vertical, KadoSpace.s2)
            .padding(.horizontal, KadoSpace.s4)
            .background(Color.kadoAccentTint, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.kadoHairline))
            // One element, so the identifier lands on a leaf and
            // VoiceOver reads icon and text as a single phrase.
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(AccessibilityID.Celebration.caption)
    }
}

extension View {
    func dayCompletionCelebration() -> some View {
        modifier(DayCompletionCelebrationModifier())
    }
}

#Preview("Caption over Today") {
    ContentView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.dayCompletionCelebration, PreviewCelebration.firing())
}

#Preview("Dark") {
    ContentView()
        .modelContainer(PreviewContainer.shared)
        .environment(\.dayCompletionCelebration, PreviewCelebration.firing())
        .preferredColorScheme(.dark)
}

/// A celebration that fires once, shortly after the preview appears,
/// so the overlay's entrance can be watched.
@MainActor
private enum PreviewCelebration {
    static func firing() -> DayCompletionCelebration {
        let celebration = DayCompletionCelebration()
        let day = Date.now
        celebration.observe(DayProgress(completed: 2, total: 3), on: day)
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            celebration.observe(DayProgress(completed: 3, total: 3), on: day)
        }
        return celebration
    }
}
