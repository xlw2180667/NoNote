import SwiftUI

struct ExportView: View {
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = 0 // 0 = text, 1 = PDF
    @State private var exportURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showNoEntries = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Format picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "#exportFormat"))
                        .font(.custom(AppFonts.medium, size: 14))
                        .foregroundColor(.textSecondary)

                    Picker("", selection: $exportFormat) {
                        Text(String(localized: "#plainText")).tag(0)
                        Text(String(localized: "#pdf")).tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                // Export button
                Button(action: exportDiaries) {
                    Text(String(localized: "#export"))
                        .font(.custom(AppFonts.bold, size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accent)
                        .cornerRadius(12)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.surface.ignoresSafeArea())
            .navigationTitle(String(localized: "#export"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "#done")) {
                        dismiss()
                    }
                    .font(.custom(AppFonts.medium, size: 16))
                    .foregroundColor(.accent)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert(String(localized: "#oops"), isPresented: $showNoEntries) {
                Button(String(localized: "#ok"), role: .cancel) {}
            } message: {
                Text(String(localized: "#noEntriesToExport"))
            }
        }
    }

    private func exportDiaries() {
        let entries = cloudKit.diaryCache.map { (dateString: $0.key, text: $0.value.text, mood: $0.value.mood) }
        guard !entries.isEmpty else {
            showNoEntries = true
            return
        }

        let url: URL?
        if exportFormat == 0 {
            url = ExportService.exportAsText(entries: entries)
        } else {
            url = ExportService.exportAsPDF(entries: entries)
        }

        if let url = url {
            exportURL = url
            showShareSheet = true
        }
    }
}

// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
