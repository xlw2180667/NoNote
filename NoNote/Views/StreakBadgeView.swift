import SwiftUI

struct StreakBadgeView: View {
    let diaryDates: Set<String>

    private var streakCount: Int {
        StatsService.currentStreak(dates: diaryDates)
    }

    var body: some View {
        if streakCount >= 2 {
            HStack(spacing: 4) {
                Text("\u{1F525}")
                    .font(.system(size: 13))
                Text(String(localized: "#streakDays\(streakCount)"))
                    .font(.custom(AppFonts.medium, size: 13))
                    .foregroundColor(.warmAccent)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.warmAccent.opacity(0.15))
            .cornerRadius(12)
        }
    }
}
