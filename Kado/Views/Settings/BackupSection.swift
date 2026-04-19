import SwiftUI
import SwiftData
import KadoCore

/// Settings section that wires the JSON round-trip: export the full
/// store as a `.json` file via the share sheet, import one via the
/// system file picker (Task 5). Attaches as a regular `Form` section
/// between Notifications and Dev Mode.
struct BackupSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backupExporter) private var exporter

    @AppStorage("lastExportAt") private var lastExportAt: Double = 0

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    var body: some View {
        Section("Data") {
            Button {
                performExport()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }

            if lastExportAt > 0 {
                Text("Last export: \(lastExportDisplay)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
                .ignoresSafeArea()
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            if let exportError {
                Text(exportError)
            }
        }
    }

    private var lastExportDisplay: String {
        let date = Date(timeIntervalSince1970: lastExportAt)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func performExport() {
        do {
            let data = try exporter.exportData(from: modelContext)
            let filename = "kado-backup-\(Self.filenameDate(from: .now)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            lastExportAt = Date.now.timeIntervalSince1970
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// `en_US_POSIX` so the filename stays `YYYY-MM-DD` across every
    /// user locale (e.g. a device set to `fr_FR` would otherwise emit
    /// `18/04/2026`, which breaks as a filename on some targets).
    static func filenameDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

// MARK: - Share item

/// Wraps a temp file URL in an `Identifiable` so SwiftUI's
/// `.sheet(item:)` can present it as a one-shot share sheet.
private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - UIActivityViewController bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Never exported") {
    Form { BackupSection() }
}

#Preview("Previously exported") {
    Form { BackupSection() }
        .defaultAppStorage(.preview(lastExportAt: Date.now.timeIntervalSince1970 - 86_400))
}

#Preview("Dark") {
    Form { BackupSection() }
        .defaultAppStorage(.preview(lastExportAt: Date.now.timeIntervalSince1970 - 3600))
        .preferredColorScheme(.dark)
}

private extension UserDefaults {
    /// Isolated `UserDefaults` instance for previews so the `@AppStorage`
    /// value doesn't bleed into the running app or between previews.
    static func preview(lastExportAt: Double) -> UserDefaults {
        let suite = UserDefaults(suiteName: "backup-section-preview-\(UUID().uuidString)") ?? .standard
        suite.set(lastExportAt, forKey: "lastExportAt")
        return suite
    }
}
