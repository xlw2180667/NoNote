import SwiftUI

struct MonthlyStatsView: View {
    let diaryDates: Set<String>
    let diaryCache: [String: DiaryCacheEntry]
    let displayedMonth: Date
    @Environment(\.dismiss) private var dismiss

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Month title
                    Text(monthTitle)
                        .font(.custom(AppFonts.bold, size: 20))
                        .foregroundColor(.textPrimary)
                        .padding(.top, 8)

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        statCard(
                            title: String(localized: "#entriesThisMonth"),
                            value: "\(StatsService.entriesThisMonth(dates: diaryDates, month: displayedMonth))",
                            icon: "doc.text"
                        )

                        statCard(
                            title: String(localized: "#totalCharacters"),
                            value: "\(StatsService.totalCharactersThisMonth(cache: diaryCache, month: displayedMonth))",
                            icon: "character.cursor.ibeam"
                        )

                        statCard(
                            title: String(localized: "#currentStreak"),
                            value: "\(StatsService.currentStreak(dates: diaryDates))",
                            icon: "flame"
                        )

                        statCard(
                            title: String(localized: "#longestStreak"),
                            value: "\(StatsService.longestStreak(dates: diaryDates))",
                            icon: "trophy"
                        )
                    }

                    // Most active weekday
                    if let weekday = StatsService.mostActiveWeekday(dates: diaryDates) {
                        statCard(
                            title: String(localized: "#mostActiveDay"),
                            value: weekday,
                            icon: "calendar"
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.surface.ignoresSafeArea())
            .navigationTitle(String(localized: "#stats"))
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
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.accent)

            Text(value)
                .font(.custom(AppFonts.bold, size: 24))
                .foregroundColor(.textPrimary)

            Text(title)
                .font(.custom(AppFonts.regular, size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}
