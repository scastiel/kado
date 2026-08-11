import SwiftUI
import KadoCore

/// One quiet line at the top of Today, shown only in the window
/// between midnight and the user's rollover hour.
///
/// Without it, the app looks like it simply failed to advance: the
/// clock says Monday, Today says Sunday's habits, and nothing accounts
/// for the gap. With it, the state is stated plainly and disappears
/// the moment it stops being true.
///
/// Deliberately not a banner, not dismissible, and not encouraging —
/// it reports a fact, in keeping with Kadō's voice.
struct TodayDayCaption: View {
    let boundary: DayBoundary
    /// Injected rather than read from the clock so previews and any
    /// future snapshot test can place themselves inside the window.
    var now: Date = .now

    /// Only meaningful while the logical day trails the wall-clock day,
    /// which can only happen when the user has moved the hour off
    /// midnight. At `startHour == 0` this is never true, so users who
    /// never touch the setting never see the row.
    ///
    /// Exposed so `TodayView` can omit the list row entirely rather
    /// than inserting one that renders an empty view.
    static func isBeforeRollover(_ boundary: DayBoundary, now: Date = .now) -> Bool {
        boundary.startOfDay(for: now) != boundary.calendar.startOfDay(for: now)
    }

    var body: some View {
        if Self.isBeforeRollover(boundary, now: now) {
            Label {
                Text("Still \(weekday) · rolls over at \(rolloverTime)")
            } icon: {
                Image(systemName: "moon.stars")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }

    /// Via `Weekday.localizedFull` rather than a date format template:
    /// `setLocalizedDateFormatFromTemplate("EEEE")` negotiates down to
    /// the abbreviated form ("Sun"), and the project's convention is to
    /// take weekday names from the calendar's standalone symbols.
    private var weekday: String {
        let index = boundary.calendar.component(.weekday, from: boundary.startOfDay(for: now))
        return Weekday(rawValue: index)?.localizedFull ?? ""
    }

    /// The hour the user picked, formatted exactly as Settings shows
    /// it — deriving it from `nextRollover` instead would re-render the
    /// instant in the device's time zone.
    private var rolloverTime: String {
        DayStartHourLabel.text(for: boundary.startHour, calendar: boundary.calendar)
    }
}

// MARK: - Previews

private func previewBoundary(hour: Int) -> DayBoundary {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return DayBoundary(calendar: calendar, startHour: hour)
}

/// 2026-08-11 02:00 UTC — a Tuesday, so a 4 AM boundary puts the
/// logical day on Monday.
private let previewNow: Date = {
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 11
    components.hour = 2
    components.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: components)!
}()

#Preview("Inside the window") {
    TodayDayCaption(boundary: previewBoundary(hour: 4), now: previewNow)
        .padding()
}

#Preview("After the rollover — renders nothing") {
    TodayDayCaption(
        boundary: previewBoundary(hour: 4),
        now: previewNow.addingTimeInterval(8 * 3600)
    )
    .padding()
}

#Preview("Midnight default — renders nothing") {
    TodayDayCaption(boundary: previewBoundary(hour: 0), now: previewNow)
        .padding()
}

#Preview("Dark") {
    TodayDayCaption(boundary: previewBoundary(hour: 4), now: previewNow)
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Dynamic Type XXXL") {
    TodayDayCaption(boundary: previewBoundary(hour: 4), now: previewNow)
        .padding()
        .environment(\.dynamicTypeSize, .accessibility3)
}
