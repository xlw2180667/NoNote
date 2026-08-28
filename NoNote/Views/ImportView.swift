import SwiftUI
import UniformTypeIdentifiers

/// Bring a diary over from another app: pick a source, see an honest preview, then confirm.
///
/// Nothing is written until the user taps import, and days that already hold text are never
/// overwritten — so running this twice, or on the wrong file, cannot lose anything.
struct ImportView: View {
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.dismiss) private var dismiss

    @State private var source: DiaryImportService.Source = .dayOne
    @State private var showPicker = false
    @State private var preview: ImportPreview?
    @State private var errorMessage: String?
    @State private var isImporting = false
    @State private var progress: (done: Int, total: Int) = (0, 0)
    @State private var summary: CloudKitService.ImportSummary?

    private var contentTypes: [UTType] {
        switch source {
        case .dayOne: return [.json]
        case .textFolder: return [.folder]
        case .csv: return [.commaSeparatedText, .plainText]
        case .noDiary: return [.plainText]
        }
    }

    #if DEBUG
    /// Drives the whole flow from launch arguments so it can be exercised without tapping:
    ///   -DemoImportSource dayOne|textFolder|csv|noDiary
    ///   -DemoImportFile <absolute path>
    ///   -DemoImportRun          also performs the import, not just the preview
    private func runDebugLaunchArguments() {
        let defaults = UserDefaults.standard
        guard let path = defaults.string(forKey: "DemoImportFile") else { return }
        if let raw = defaults.string(forKey: "DemoImportSource"),
           let picked = DiaryImportService.Source(rawValue: raw) {
            source = picked
        }
        do {
            let parsed = try DiaryImportService.parse(url: URL(fileURLWithPath: path), as: source)
            preview = parsed
            if ProcessInfo.processInfo.arguments.contains("-DemoImportRun") {
                runImport(parsed)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    #endif

    var body: some View {
        List {
            if let summary {
                resultSection(summary)
            } else if let preview {
                previewSection(preview)
            } else {
                sourceSection
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.surface.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .navigationTitle(String(localized: "#importDiary"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            #if DEBUG
            runDebugLaunchArguments()
            #endif
        }
        .fileImporter(isPresented: $showPicker,
                      allowedContentTypes: contentTypes,
                      allowsMultipleSelection: false) { result in
            handlePick(result)
        }
        .alert(String(localized: "#oops"), isPresented: .constant(errorMessage != nil)) {
            Button(String(localized: "#ok")) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Pick a source

    private var sourceSection: some View {
        Group {
            Section {
                ForEach(DiaryImportService.Source.allCases) { option in
                    Button {
                        source = option
                        showPicker = true
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(option.title)
                                .font(.custom(AppFonts.medium, size: 16))
                                .foregroundColor(.textPrimary)
                            Text(option.detail)
                                .font(.custom(AppFonts.regular, size: 13))
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                Text(String(localized: "#importPickSource"))
                    .font(.custom(AppFonts.medium, size: 13))
            } footer: {
                Text(String(localized: "#importFooter"))
                    .font(.custom(AppFonts.regular, size: 12))
            }
        }
    }

    // MARK: - Preview before writing

    private func previewSection(_ preview: ImportPreview) -> some View {
        Group {
            Section {
                row(String(localized: "#importFoundEntries"),
                    "\(preview.entries.count)")
                if let earliest = preview.earliest, let latest = preview.latest {
                    row(String(localized: "#importDateRange"), span(earliest, latest))
                }
                if preview.mergedCount > 0 {
                    row(String(localized: "#importMerged"), "\(preview.mergedCount)")
                }
                if preview.skippedCount > 0 {
                    row(String(localized: "#importUnreadableRows"), "\(preview.skippedCount)")
                }
            } header: {
                Text(preview.source.title)
                    .font(.custom(AppFonts.medium, size: 13))
            } footer: {
                Text(String(localized: "#importPreviewFooter"))
                    .font(.custom(AppFonts.regular, size: 12))
            }

            Section {
                ForEach(preview.entries.prefix(3)) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(longDate(entry.date))
                            .font(.custom(AppFonts.medium, size: 14))
                            .foregroundColor(.textPrimary)
                        Text(entry.text)
                            .font(.custom(AppFonts.regular, size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                }
            } header: {
                Text(String(localized: "#importSamplePreview"))
                    .font(.custom(AppFonts.medium, size: 13))
            }

            Section {
                if isImporting {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: progress.total == 0 ? 0
                                     : Double(progress.done) / Double(progress.total))
                        Text(String(format: String(localized: "#importProgress%lld%lld"),
                                    progress.done, progress.total))
                            .font(.custom(AppFonts.regular, size: 12))
                            .foregroundColor(.textSecondary)
                    }
                } else {
                    Button {
                        runImport(preview)
                    } label: {
                        Text(String(localized: "#importStart"))
                            .font(.custom(AppFonts.medium, size: 16))
                            .foregroundColor(.accent)
                    }
                    Button {
                        self.preview = nil
                    } label: {
                        Text(String(localized: "#cancel"))
                            .font(.custom(AppFonts.regular, size: 16))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Result

    private func resultSection(_ summary: CloudKitService.ImportSummary) -> some View {
        Group {
            Section {
                row(String(localized: "#importAdded"), "\(summary.imported)")
                if summary.skippedExisting > 0 {
                    row(String(localized: "#importSkippedExisting"), "\(summary.skippedExisting)")
                }
                if summary.failedUpload > 0 {
                    row(String(localized: "#importPendingUpload"), "\(summary.failedUpload)")
                }
            } header: {
                Text(String(localized: "#importDone"))
                    .font(.custom(AppFonts.medium, size: 13))
            } footer: {
                Text(summary.failedUpload > 0
                     ? String(localized: "#importDoneFooterPending")
                     : String(localized: "#importDoneFooter"))
                    .font(.custom(AppFonts.regular, size: 12))
            }
            Section {
                Button { dismiss() } label: {
                    Text(String(localized: "#done"))
                        .font(.custom(AppFonts.medium, size: 16))
                        .foregroundColor(.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom(AppFonts.regular, size: 15))
                .foregroundColor(.textPrimary)
            Spacer()
            Text(value)
                .font(.custom(AppFonts.medium, size: 15))
                .foregroundColor(.textSecondary)
        }
    }

    private func longDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private func span(_ from: Date, _ to: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        let a = f.string(from: from), b = f.string(from: to)
        return a == b ? a : "\(a)–\(b)"
    }

    private func handlePick(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                preview = try DiaryImportService.parse(url: url, as: source)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func runImport(_ preview: ImportPreview) {
        isImporting = true
        progress = (0, preview.entries.count)
        Task {
            let result = await cloudKit.importEntries(preview.entries) { done, total in
                Task { @MainActor in progress = (done, total) }
            }
            await MainActor.run {
                isImporting = false
                summary = result
            }
        }
    }
}
