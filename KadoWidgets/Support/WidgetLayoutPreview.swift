import KadoCore
import SwiftUI
import WidgetKit

/// Content-size regression fixtures, not a simulation of WidgetKit's
/// render server. In particular, accented mode here cannot prove the
/// result on real Clear/Tinted glass. Sizes include 16pt outer margins.
private struct WidgetLayoutPreview: View {
    var weekly = false
    var habitIDs: [UUID] = []

    var body: some View {
        let snapshot = PreviewSnapshots.fullCapacityToday
        let entry = SelectedSnapshotEntry(date: .now, snapshot: snapshot, habitIDs: habitIDs)
        Group {
            if weekly {
                WeeklyGridLargeView(entry: entry)
            } else {
                TodayProgressMediumView(entry: entry)
            }
        }
        .padding(16)
        .background(Color.kadoBackgroundSecondary)
    }
}

#Preview("iPhone 14 · eight habits", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview()
}

#Preview("Compact phone · seven habits", traits: .fixedLayout(width: 321, height: 148)) {
    WidgetLayoutPreview(habitIDs: PreviewSnapshots.fullCapacityToday.today.prefix(7).map(\.habit.id))
}

#Preview("Medium · one picked habit", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview(habitIDs: Array(PreviewSnapshots.pickedTodayIDs.prefix(1)))
}

#Preview("Medium · two picked habits", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview(habitIDs: PreviewSnapshots.pickedTodayIDs)
}

#Preview("iPhone 14 · picked not due", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview(habitIDs: [PreviewSnapshots.notDueHabit.id]
        + PreviewSnapshots.fullCapacityToday.today.prefix(7).map(\.habit.id))
}

#Preview("Medium · XXXL", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview()
        .dynamicTypeSize(.xxxLarge)
}

#Preview("Medium · AX5 fallback", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview()
        .dynamicTypeSize(.accessibility5)
}

#Preview("Medium · French", traits: .fixedLayout(width: 338, height: 158)) {
    WidgetLayoutPreview()
        .environment(\.locale, Locale(identifier: "fr"))
}

#Preview("Dark · medium", traits: .fixedLayout(width: 364, height: 170)) {
    WidgetLayoutPreview()
        .preferredColorScheme(.dark)
}

#Preview("iPad mini · five habits", traits: .fixedLayout(width: 260, height: 260)) {
    WidgetLayoutPreview(weekly: true)
}

#Preview("iPad mini · accented approximation", traits: .fixedLayout(width: 260, height: 260)) {
    WidgetLayoutPreview(weekly: true)
        .environment(\.widgetRenderingMode, .accented)
}

#Preview("iPad mini · XXXL", traits: .fixedLayout(width: 260, height: 260)) {
    WidgetLayoutPreview(weekly: true)
        .dynamicTypeSize(.xxxLarge)
}

#Preview("iPad mini · AX5 fallback", traits: .fixedLayout(width: 260, height: 260)) {
    WidgetLayoutPreview(weekly: true)
        .dynamicTypeSize(.accessibility5)
}

#Preview("iPad mini · French", traits: .fixedLayout(width: 260, height: 260)) {
    WidgetLayoutPreview(weekly: true)
        .environment(\.locale, Locale(identifier: "fr"))
}

#Preview("Dark · large phone", traits: .fixedLayout(width: 364, height: 382)) {
    WidgetLayoutPreview(weekly: true)
        .preferredColorScheme(.dark)
}
