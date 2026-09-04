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

    @State private var isShowingImporter = false

    // One slot each for the presented sheet and alert. The states are
    // mutually exclusive, and stacking a modifier per case (this view
    // was up to two sheets and three alerts) is how presentation stacks
    // start dropping presentations — see the PR #16 compound.
    @State private var presentedSheet: PresentedSheet?
    @State private var presentedAlert: PresentedAlert?

    var body: some View {
        Section("Data") {
            Menu {
                Button {
                    performExport(format: .json)
                } label: {
                    Label("JSON", systemImage: "curlybraces")
                }
                Button {
                    performExport(format: .csv)
                } label: {
                    Label("CSV", systemImage: "tablecells")
                }
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
        .listRowBackground(Color.kadoBackgroundSecondary)
        .fileImporter(
            isPresented: $isShowingImporter,
            allowedContentTypes: [.json, .commaSeparatedText]
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .share(let url):
                ShareSheet(activityItems: [url])
                    .ignoresSafeArea()
            case .confirmImport(let document, let summary):
                ImportConfirmSheet(
                    summary: summary,
                    onCancel: { presentedSheet = nil },
                    onConfirm: { commitImport(document) }
                )
            }
        }
        .alert(
            presentedAlert?.title ?? "",
            isPresented: Binding(
                get: { presentedAlert != nil },
                set: { if !$0 { presentedAlert = nil } }
            ),
            presenting: presentedAlert
        ) { _ in
            Button("OK", role: .cancel) { presentedAlert = nil }
        } message: { alert in
            alert.message
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

    private func performExport(format: BackupFormat) {
        do {
            let document = try exporter.export(from: modelContext)
            let data: Data
            switch format {
            case .json:
                data = try exporter.encode(document)
            case .csv:
                // The coder is a pure value type with no collaborators,
                // so it's constructed here rather than injected — there
                // is nothing to stub in a preview.
                data = CSVBackupCoder().encode(document)
            }
            let filename = "kado-backup-\(Self.filenameDate(from: .now)).\(format.fileExtension)"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            lastExportAt = Date.now.timeIntervalSince1970
            presentedSheet = .share(url)
        } catch {
            presentedAlert = .exportFailed(error.localizedDescription)
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
            presentedAlert = .importFailed(.readFailed)
        case .success(let url):
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer { if didStartAccess { url.stopAccessingSecurityScopedResource() } }

            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                presentedAlert = .importFailed(.readFailed)
                return
            }

            // The extension is a hint — some file providers rename on
            // export — so fall back to sniffing the contents.
            let format = BackupFormat.detect(pathExtension: url.pathExtension)
                ?? BackupFormat.sniff(data)

            do {
                let document: BackupDocument
                switch format {
                case .json:
                    document = try importer.parse(data: data)
                case .csv:
                    document = try CSVBackupCoder().decode(data)
                }
                let summary = try importer.summary(for: document, in: modelContext)
                presentedSheet = .confirmImport(document: document, summary: summary)
            } catch BackupError.invalidJSON {
                presentedAlert = .importFailed(.invalidJSON)
            } catch BackupError.invalidCSV {
                presentedAlert = .importFailed(.invalidCSV)
            } catch BackupError.malformedRow(let line) {
                presentedAlert = .importFailed(.malformedRow(line: line))
            } catch BackupError.unsupportedVersion {
                presentedAlert = .importFailed(.unsupportedVersion)
            } catch {
                presentedAlert = .importFailed(.readFailed)
            }
        }
    }

    private func commitImport(_ document: BackupDocument) {
        do {
            let summary = try importer.apply(document, to: modelContext)
            presentedSheet = nil
            WidgetReloader.reloadAll(using: modelContext)
            presentedAlert = .importSucceeded(summary)
        } catch {
            presentedSheet = nil
            presentedAlert = .importFailed(.readFailed)
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

// MARK: - Presentation state

/// Every sheet this section can present, in one slot.
private enum PresentedSheet: Identifiable {
    case share(URL)
    case confirmImport(document: BackupDocument, summary: ImportSummary)

    var id: String {
        switch self {
        case .share(let url): return "share-\(url.absoluteString)"
        case .confirmImport: return "confirmImport"
        }
    }
}

/// Every alert this section can present, in one slot.
private enum PresentedAlert: Identifiable {
    case exportFailed(String)
    case importFailed(ImportFailure)
    case importSucceeded(ImportSummary)

    var id: String {
        switch self {
        case .exportFailed: return "exportFailed"
        case .importFailed(let failure): return "importFailed-\(failure.id)"
        case .importSucceeded: return "importSucceeded"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .exportFailed: return "Export failed"
        case .importFailed(let failure): return failure.title
        case .importSucceeded: return "Import complete"
        }
    }

    /// Returns `Text` rather than `LocalizedStringKey` so the dynamic
    /// export-error description reaches the non-localizing initializer
    /// while the fixed strings stay on the localized path.
    var message: Text {
        switch self {
        case .exportFailed(let description):
            return Text(description)
        case .importFailed(let failure):
            return Text(failure.message)
        case .importSucceeded(let summary):
            return Text("Habits: \(summary.totalHabits) (\(summary.newHabits) new, \(summary.updatedHabits) updated)\nCompletions: \(summary.totalCompletions) (\(summary.newCompletions) new, \(summary.updatedCompletions) updated)")
        }
    }
}

/// Why an import couldn't proceed.
private enum ImportFailure {
    case invalidJSON
    case invalidCSV
    case malformedRow(line: Int)
    case unsupportedVersion
    case readFailed

    var id: String {
        switch self {
        case .invalidJSON: return "invalidJSON"
        case .invalidCSV: return "invalidCSV"
        case .malformedRow(let line): return "malformedRow-\(line)"
        case .unsupportedVersion: return "unsupportedVersion"
        case .readFailed: return "readFailed"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .invalidJSON: return "Not a Kadō backup"
        case .invalidCSV: return "Not a Kadō CSV export"
        case .malformedRow: return "Malformed row"
        case .unsupportedVersion: return "Newer Kadō version"
        case .readFailed: return "Couldn't read file"
        }
    }

    var message: LocalizedStringKey {
        switch self {
        case .invalidJSON:
            return "The file couldn't be decoded as a Kadō backup."
        case .invalidCSV:
            return "The file couldn't be read as a Kadō CSV export. Check that its header row is intact."
        case .malformedRow(let line):
            return "Line \(line) doesn't have the expected number of columns."
        case .unsupportedVersion:
            return "This backup was created by a newer Kadō version. Update Kadō to import."
        case .readFailed:
            return "The file couldn't be read. Try a different file."
        }
    }
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

/// The export format picker is a `Menu`, which a preview can't open,
/// and the import alerts are driven by private `@State`. These two
/// previews at least make the new CSV failure copy reviewable without
/// running the app — the tap-driven simulator path is unavailable on
/// this XcodeBuildMCP install (see CLAUDE.md).
#Preview("CSV parse failure alert") {
    Color.clear
        .alert(
            ImportFailure.invalidCSV.title,
            isPresented: .constant(true)
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ImportFailure.invalidCSV.message)
        }
}

#Preview("Malformed row alert") {
    Color.clear
        .alert(
            ImportFailure.malformedRow(line: 42).title,
            isPresented: .constant(true)
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(ImportFailure.malformedRow(line: 42).message)
        }
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
