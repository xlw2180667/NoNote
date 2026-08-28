import SwiftUI

/// Jump straight to a month instead of stepping through them one at a time.
///
/// This became necessary with import: a diary that only ever grew a month at a time was
/// fine to page through, but someone who brings in five years of history should not have to
/// tap sixty times to reach the start of it.
///
/// Months that hold entries are marked, so after an import you can see at a glance where
/// your history actually landed.
struct MonthPickerView: View {
    @Binding var displayedMonth: Date
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.dismiss) private var dismiss

    @State private var year: Int

    private let calendar = Calendar.current
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    init(displayedMonth: Binding<Date>, cloudKit: CloudKitService) {
        _displayedMonth = displayedMonth
        self.cloudKit = cloudKit
        _year = State(initialValue: Calendar.current.component(.year, from: displayedMonth.wrappedValue))
    }

    private var diaryDates: Set<String> { cloudKit.diaryDates }

    /// How far back the stepper may go.
    ///
    /// Deliberately NOT derived from `diaryDates`: that set only holds months already fetched
    /// from CloudKit, so on a fresh install it would pin the range to a single year and lock
    /// the user out of their own history. A generous floor costs nothing — an empty year just
    /// shows no marks — while a tight one is a dead end.
    private var yearRange: ClosedRange<Int> {
        let thisYear = calendar.component(.year, from: Date())
        let cachedOldest = diaryDates.compactMap { Int($0.split(separator: "-").last ?? "") }.min()
        return min(cachedOldest ?? thisYear, thisYear - 20)...thisYear
    }

    private var monthSymbols: [String] {
        let f = DateFormatter()
        f.locale = .current
        return f.shortStandaloneMonthSymbols ?? f.shortMonthSymbols
    }

    private func hasEntries(month: Int) -> Bool {
        let suffix = "-\(year)"
        let prefix = "\(month)-"
        return diaryDates.contains { $0.hasPrefix(prefix) && $0.hasSuffix(suffix) }
    }

    private func isFuture(month: Int) -> Bool {
        let now = Date()
        let thisYear = calendar.component(.year, from: now)
        let thisMonth = calendar.component(.month, from: now)
        return year > thisYear || (year == thisYear && month > thisMonth)
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button { year -= 1 } label: {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .medium))
                }
                .disabled(year <= yearRange.lowerBound)
                .opacity(year <= yearRange.lowerBound ? 0.25 : 1)

                Spacer()
                Text(String(year))
                    .font(.custom(AppFonts.bold, size: 20))
                    .foregroundColor(.textPrimary)
                    .monospacedDigit()
                Spacer()

                Button { year += 1 } label: {
                    Image(systemName: "chevron.right").font(.system(size: 16, weight: .medium))
                }
                .disabled(year >= yearRange.upperBound)
                .opacity(year >= yearRange.upperBound ? 0.25 : 1)
            }
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 8)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...12, id: \.self) { month in
                    let future = isFuture(month: month)
                    let marked = hasEntries(month: month)
                    Button {
                        var parts = DateComponents()
                        parts.year = year
                        parts.month = month
                        parts.day = 1
                        if let date = calendar.date(from: parts) {
                            displayedMonth = date
                            dismiss()
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text(monthSymbols[month - 1])
                                .font(.custom(AppFonts.medium, size: 15))
                            Circle()
                                .fill(marked ? Color.accent : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(marked ? Color.accent.opacity(0.10) : Color.surfaceCard))
                        .foregroundColor(.textPrimary)
                    }
                    .disabled(future)
                    .opacity(future ? 0.3 : 1)
                }
            }
        }
        .padding(20)
        .presentationDetents([.height(320)])
        .background(Color.surface.ignoresSafeArea())
        .task(id: year) { await cloudKit.prefetchYear(year) }
    }
}
