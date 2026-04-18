import SwiftUI
import UIKit

/// Shows the current CloudKit account status inside the Settings
/// `Form`. No in-app toggle — control lives in iOS Settings → Apple ID
/// → iCloud → Kado. This view only *reflects* state. Cases that
/// require user action expose an "Open Settings" button that jumps
/// to the app's pane in iOS Settings via `UIApplication.openSettingsURLString`.
struct SyncStatusSection: View {
    @Environment(\.cloudAccountStatus) private var observer
    @Environment(\.openURL) private var openURL
    @AppStorage(DevModeDefaults.key, store: DevModeDefaults.sharedDefaults) private var isDevMode = false

    var body: some View {
        Section("iCloud") {
            if isDevMode {
                devModePausedRow
            } else {
                row(for: observer.status)
                if showsSettingsLink(for: observer.status) {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    private var devModePausedRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sync paused while dev mode is on")
                    .font(.body)
                    .foregroundStyle(.primary)
                Text("Your real habits are safe in iCloud. Turn dev mode off to resume syncing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func row(for status: CloudAccountStatus) -> some View {
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
        .accessibilityLabel("\(title(for: status)). \(subtitle(for: status))")
    }

    private func icon(for status: CloudAccountStatus) -> String {
        switch status {
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "person.crop.circle.badge.exclamationmark"
        case .restricted: return "lock.icloud.fill"
        case .temporarilyUnavailable: return "exclamationmark.icloud.fill"
        case .couldNotDetermine: return "icloud"
        }
    }

    private func iconTint(for status: CloudAccountStatus) -> Color {
        switch status {
        case .available: return .green
        case .noAccount, .restricted, .temporarilyUnavailable: return .orange
        case .couldNotDetermine: return .secondary
        }
    }

    private func title(for status: CloudAccountStatus) -> String {
        switch status {
        case .available:
            return String(localized: "Syncing with iCloud")
        case .noAccount:
            return String(localized: "Not signed in to iCloud")
        case .restricted:
            return String(localized: "iCloud is restricted on this device")
        case .temporarilyUnavailable:
            return String(localized: "iCloud is temporarily unavailable")
        case .couldNotDetermine:
            return String(localized: "Checking iCloud…")
        }
    }

    private func subtitle(for status: CloudAccountStatus) -> String {
        switch status {
        case .available:
            return String(localized: "Your habits stay in sync across every device signed into the same Apple ID.")
        case .noAccount:
            return String(localized: "Sign in to iCloud from iOS Settings to sync your habits across devices.")
        case .restricted:
            return String(localized: "Screen Time, a device management profile, or parental controls are preventing iCloud access.")
        case .temporarilyUnavailable:
            return String(localized: "Your account is signed in but iCloud can’t be reached right now. Try again in a few minutes.")
        case .couldNotDetermine:
            return String(localized: "Kadō is checking your iCloud status.")
        }
    }

    private func showsSettingsLink(for status: CloudAccountStatus) -> Bool {
        switch status {
        case .noAccount, .restricted: return true
        case .available, .temporarilyUnavailable, .couldNotDetermine: return false
        }
    }
}

#Preview("Available") {
    SyncStatusPreview(status: .available)
}

#Preview("Not signed in") {
    SyncStatusPreview(status: .noAccount)
}

#Preview("Restricted") {
    SyncStatusPreview(status: .restricted)
}

#Preview("Temporarily unavailable") {
    SyncStatusPreview(status: .temporarilyUnavailable)
}

#Preview("Checking") {
    SyncStatusPreview(status: .couldNotDetermine)
}

private struct SyncStatusPreview: View {
    let status: CloudAccountStatus

    var body: some View {
        NavigationStack {
            Form {
                SyncStatusSection()
            }
            .navigationTitle("Settings")
        }
        .environment(\.cloudAccountStatus, MockCloudAccountStatusObserver(status: status))
    }
}
