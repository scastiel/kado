import Foundation

/// The one card the bottom of Today has room for.
///
/// Two cards want the slot — the Appearance announcement and the tip
/// nudge — and they never share it: two asks stacked under the habits
/// read as an app that wants things. Each service still decides whether
/// its own card is due; this only decides between them.
nonisolated enum TodayCard: Equatable {
    case appearanceAnnouncement
    case tipNudge

    /// - The announcement wins while it is due. It is time-bound (it
    ///   announces a release); the tip nudge keeps.
    /// - The tip nudge waits until the calendar day after the
    ///   announcement was put away, so dismissing one card never
    ///   uncovers the other on the spot.
    static func resolve(
        announcementRetiredAt: Date?,
        tipNudgeDue: Bool,
        now: Date,
        calendar: Calendar
    ) -> TodayCard? {
        guard let retiredAt = announcementRetiredAt else { return .appearanceAnnouncement }
        guard tipNudgeDue else { return nil }
        // Through `Calendar`, so a day is the calendar's day — never a
        // 24-hour block, and never assuming the day starts at midnight.
        return calendar.isDate(retiredAt, inSameDayAs: now) ? nil : .tipNudge
    }
}
