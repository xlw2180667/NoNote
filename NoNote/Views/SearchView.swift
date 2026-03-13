import SwiftUI

struct SearchView: View {
    @ObservedObject var cloudKit: CloudKitService
    var onSelectDate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var isSearchingCloud = false
    @State private var cloudResults: [(dateString: String, text: String)] = []
    @State private var hasSearchedCloud = false

    private var localResults: [(dateString: String, text: String)] {
        guard !searchText.isEmpty else { return [] }
        let lowered = searchText.lowercased()
        return cloudKit.diaryCache
            .filter { $0.value.text.lowercased().contains(lowered) }
            .map { (dateString: $0.key, text: $0.value.text) }
            .sorted { $0.dateString > $1.dateString }
    }

    private var displayResults: [(dateString: String, text: String)] {
        hasSearchedCloud ? cloudResults : localResults
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.textSecondary)
                    TextField(String(localized: "#searchPlaceholder"), text: $searchText)
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.textPrimary)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color.surfaceCard)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if !searchText.isEmpty && !hasSearchedCloud {
                    Button(action: searchCloud) {
                        HStack {
                            if isSearchingCloud {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(String(localized: "#searchAllMonths"))
                                .font(.custom(AppFonts.medium, size: 14))
                                .foregroundColor(.accent)
                        }
                    }
                    .padding(.top, 8)
                    .disabled(isSearchingCloud)
                }

                if searchText.isEmpty {
                    Spacer()
                    Text(String(localized: "#searchPlaceholder"))
                        .font(.custom(AppFonts.regular, size: 15))
                        .foregroundColor(.textSecondary)
                    Spacer()
                } else if displayResults.isEmpty {
                    Spacer()
                    Text(String(localized: "#noResults"))
                        .font(.custom(AppFonts.regular, size: 15))
                        .foregroundColor(.textSecondary)
                    Spacer()
                } else {
                    List(displayResults, id: \.dateString) { item in
                        Button {
                            dismiss()
                            onSelectDate(item.dateString)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(item.dateString))
                                    .font(.custom(AppFonts.medium, size: 15))
                                    .foregroundColor(.textPrimary)
                                Text(String(item.text.prefix(80)))
                                    .font(.custom(AppFonts.regular, size: 13))
                                    .foregroundColor(.textSecondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.surfaceCard)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.surface.ignoresSafeArea())
            .navigationTitle(String(localized: "#search"))
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
            .onChange(of: searchText) { _ in
                hasSearchedCloud = false
                cloudResults = []
            }
        }
    }

    private func searchCloud() {
        isSearchingCloud = true
        Task {
            do {
                cloudResults = try await cloudKit.searchDiaries(query: searchText)
                hasSearchedCloud = true
            } catch {
                // Fall back to local results
            }
            isSearchingCloud = false
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
