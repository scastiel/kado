import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import KadoCore

/// Settings section that wires the JSON round-trip: export the full
/// store as a `.json` file via the share sheet, import one via the
/// system file picker. Attaches as a regular `Form` section between
/// Notifications and Dev Mode.
struct BackupSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.backupExporter) private var exporter
    @Environment(\.backupImporter) private var importer

    @AppStorage("lastExportAt") private var lastExportAt: Double = 0

    @State private var shareItem: ShareItem?
    @State private var exportError: String?

    @State private var isShowingImporter = false
    @State private var pendingImport: PendingImport?
    @State private var importAlert: ImportAlert?
    @State private var importSuccessSummary: ImportSummary?

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

            Button {
                isShowingImporter = true
            } label: {
                Label("Import Data", systemImage: "square.and.arrow.down")
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
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json]
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $pendingImport) { pending in
            ImportConfirmSheet(
                summary: pending.summary,
                onCancel: { pendingImport = nil },
                onConfirm: { commitImport(pending.document) }
            )
        }
        .alert(
            importAlert?.title ?? "",
            isPresented: Binding(
                get: { importAlert != nil },
                set: { if !$0 { importAlert = nil } }
            ),
            presenting: importAlert
        ) { _ in
            Button("OK", role: .cancel) { importAlert = nil }
        } message: { alert in
            Text(alert.message)
        }
        .alert(
            "Import complete",
            isPresented: Binding(
                get: { importSuccessSummary != nil },
                set: { if !$0 { importSuccessSummary = nil } }
            ),
            presenting: importSuccessSummary
        ) { _ in
            Button("OK", role: .cancel) { importSuccessSummary = nil }
        } message: { summary in
            Text("Habits: \(summary.totalHabits) (\(summary.newHabits) new, \(summary.updatedHabits) updated)\nCompletions: \(summary.totalCompletions) (\(summary.newCompletions) new, \(summary.updatedCompletions) updated)")
        }
    }

    // MARK: - Export

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

    // MARK: - Import

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importAlert = .readFailed
        case .success(let url):
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                importAlert = .readFailed
                return
            }

            do {
                let document = try importer.parse(data: data)
                let summary = try importer.summary(for: document, in: modelContext)
                pendingImport = PendingImport(document: document, summary: summary)
            } catch BackupError.invalidJSON {
                importAlert = .invalidJSON
            } catch BackupError.unsupportedVersion {
                importAlert = .unsupportedVersion
            } catch {
                importAlert = .readFailed
            }
        }
    }

    private func commitImport(_ document: BackupDocument) {
        do {
            let summary = try importer.apply(document, to: modelContext)
            pendingImport = nil
            WidgetReloader.reloadAll(using: modelContext)
            importSuccessSummary = summary
        } catch {
            pendingImport = nil
            importAlert = .readFailed
        }
    }
}

// MARK: - Confirmation sheet

private struct ImportConfirmSheet: View {
    let summary: ImportSummary
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    labelRow(
                        title: "Habits",
                        total: summary.totalHabits,
                        new: summary.newHabits,
                        updated: summary.updatedHabits
                    )
                    labelRow(
                        title: "Completions",
                        total: summary.totalCompletions,
                        new: summary.newCompletions,
                        updated: summary.updatedCompletions
                    )
                } footer: {
                    Text("Imported habits and completions will merge with your current data by matching IDs. Nothing will be deleted.")
                }
            }
            .navigationTitle("Import Kadō backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onConfirm)
                }
            }
        }
    }

    @ViewBuilder
    private func labelRow(title: LocalizedStringKey, total: Int, new: Int, updated: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(total) (\(new) new, \(updated) updated)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Alert

private enum ImportAlert: Identifiable {
    case invalidJSON
    case unsupportedVersion
    case readFailed

    var id: Int {
        switch self {
        case .invalidJSON: return 0
        case .unsupportedVersion: return 1
        case .readFailed: return 2
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .invalidJSON: return "Not a Kadō backup"
        case .unsupportedVersion: return "Newer Kadō version"
        case .readFailed: return "Couldn't read file"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .invalidJSON:
            return "The file couldn't be decoded as a Kadō backup."
        case .unsupportedVersion:
            return "This backup was created by a newer Kadō version. Update Kadō to import."
        case .readFailed:
            return "The file couldn't be read. Try a different file."
        }
    }
}

// MARK: - Pending import

private struct PendingImport: Identifiable {
    let id = UUID()
    let document: BackupDocument
    let summary: ImportSummary
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

#Preview("Confirmation sheet") {
    Color.clear.sheet(isPresented: .constant(true)) {
        ImportConfirmSheet(
            summary: ImportSummary(
                totalHabits: 12,
                newHabits: 3,
                updatedHabits: 9,
                totalCompletions: 147,
                newCompletions: 12,
                updatedCompletions: 135
            ),
            onCancel: {},
            onConfirm: {}
        )
    }
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
