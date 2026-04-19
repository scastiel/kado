import SwiftUI
import UIKit
import UserNotifications
import KadoCore

/// Reflects the current notification-authorization status inside the
/// Settings `Form`. No in-app request button — the first prompt comes
/// organically when the user saves a reminders-on habit (see
/// `NewHabitFormView`). This view only mirrors state and lets the
/// user jump to iOS Settings when things need to be fixed.
struct NotificationsSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var status: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Section("Notifications") {
            row(for: status)
            if status == .denied {
                Button {
                    openNotificationSettings()
                } label: {
                    Label("Open Settings", systemImage: "arrow.up.right.square")
                }
            }
        }
        .listRowBackground(Color.kadoBackgroundSecondary)
        .task { await refreshStatus() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await refreshStatus() }
            }
        }
    }

    @ViewBuilder
    private func row(for status: UNAuthorizationStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: status))
                .font(.title3)
                .foregroundStyle(iconTint(for: status))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: status))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle(for: status))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func icon(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        case .notDetermined: return "bell"
        @unknown default: return "bell"
        }
    }

    private func iconTint(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .accentColor
        case .denied: return .red
        case .notDetermined: return .secondary
        @unknown default: return .secondary
        }
    }

    private func title(for status: UNAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Notifications on"
        case .denied: return "Notifications off"
        case .notDetermined: return "Notifications not yet requested"
        @unknown default: return "Notifications not yet requested"
        }
    }

    private func subtitle(for status: UNAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Reminders are delivered at the time you set on each habit."
        case .denied:
            return "Reminders won't fire until you re-enable notifications in Settings."
        case .notDetermined:
            return "You'll be asked the first time you save a habit with a reminder."
        @unknown default:
            return "You'll be asked the first time you save a habit with a reminder."
        }
    }

    private func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        status = settings.authorizationStatus
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Previews

/// Preview-only variant that bypasses the async fetch and accepts a
/// seed status directly. Lets each preview render a deterministic
/// state without hitting the real notification center.
private struct NotificationsSectionPreview: View {
    let seeded: UNAuthorizationStatus

    @State private var status: UNAuthorizationStatus

    init(seeded: UNAuthorizationStatus) {
        self.seeded = seeded
        self._status = State(initialValue: seeded)
    }

    var body: some View {
        Form {
            Section("Notifications") {
                HStack(spacing: 12) {
                    Image(systemName: icon(for: status))
                        .font(.title3)
                        .foregroundStyle(iconTint(for: status))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title(for: status))
                            .font(.body)
                        Text(subtitle(for: status))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
                if status == .denied {
                    Button {} label: {
                        Label("Open Settings", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    private func icon(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "bell.badge.fill"
        case .denied: return "bell.slash.fill"
        default: return "bell"
        }
    }

    private func iconTint(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .accentColor
        case .denied: return .red
        default: return .secondary
        }
    }

    private func title(for status: UNAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized, .provisional, .ephemeral: return "Notifications on"
        case .denied: return "Notifications off"
        default: return "Notifications not yet requested"
        }
    }

    private func subtitle(for status: UNAuthorizationStatus) -> LocalizedStringKey {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Reminders are delivered at the time you set on each habit."
        case .denied:
            return "Reminders won't fire until you re-enable notifications in Settings."
        default:
            return "You'll be asked the first time you save a habit with a reminder."
        }
    }
}

#Preview("Authorized") { NotificationsSectionPreview(seeded: .authorized) }
#Preview("Denied") { NotificationsSectionPreview(seeded: .denied) }
#Preview("Not determined") { NotificationsSectionPreview(seeded: .notDetermined) }
#Preview("Dark") {
    NotificationsSectionPreview(seeded: .denied)
        .preferredColorScheme(.dark)
}
