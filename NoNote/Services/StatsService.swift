import Foundation

enum StatsService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    static func entriesThisMonth(dates: Set<String>, month: Date) -> Int {
        let cal = Calendar.current
        let m = cal.component(.month, from: month)
        let y = cal.component(.year, from: month)
        return dates.filter { dateString in
            guard let date = dateFormatter.date(from: dateString) else { return false }
            return cal.component(.month, from: date) == m && cal.component(.year, from: date) == y
        }.count
    }

    static func totalCharactersThisMonth(cache: [String: DiaryCacheEntry], month: Date) -> Int {
        let cal = Calendar.current
        let m = cal.component(.month, from: month)
        let y = cal.component(.year, from: month)
        return cache.reduce(0) { total, pair in
            guard let date = dateFormatter.date(from: pair.key) else { return total }
            if cal.component(.month, from: date) == m && cal.component(.year, from: date) == y {
                return total + pair.value.text.count
            }
            return total
        }
    }

    static func currentStreak(dates: Set<String>) -> Int {
        let cal = Calendar.current
        var count = 0
        var date = Date()

        while true {
            let dateString = dateFormatter.string(from: date)
            if dates.contains(dateString) {
                count += 1
            } else if count > 0 {
                break
            } else {
                guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = yesterday
                let yString = dateFormatter.string(from: date)
                if dates.contains(yString) {
                    count += 1
                } else {
                    break
                }
                if let prev = cal.date(byAdding: .day, value: -1, to: date) {
                    date = prev
                    continue
                }
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return count
    }

    static func longestStreak(dates: Set<String>) -> Int {
        guard !dates.isEmpty else { return 0 }
        let sortedDates = dates.compactMap { dateFormatter.date(from: $0) }.sorted()
        guard !sortedDates.isEmpty else { return 0 }

        let cal = Calendar.current
        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = cal.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else if diff > 1 {
                current = 1
            }
            // diff == 0 means same day, skip
        }
        return longest
    }

    static func mostActiveWeekday(dates: Set<String>) -> String? {
        guard !dates.isEmpty else { return nil }
        var weekdayCounts = [Int: Int]()
        let cal = Calendar.current

        for dateString in dates {
            if let date = dateFormatter.date(from: dateString) {
                let weekday = cal.component(.weekday, from: date)
                weekdayCounts[weekday, default: 0] += 1
            }
        }

        guard let maxWeekday = weekdayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[maxWeekday - 1]
    }
}
