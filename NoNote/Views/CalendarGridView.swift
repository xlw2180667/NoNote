import SwiftUI

struct CalendarGridView: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let diaryDates: Set<String>

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    var body: some View {
        VStack(spacing: 10) {
            headerView
            weekdayLabels
            dayGrid
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.noDiaryBlack)
            }
            Spacer()
            Text(monthYearString)
                .font(.custom("Roboto-Regular", size: 17))
                .foregroundColor(.noDiaryBlack)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.noDiaryBlack)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var weekdayLabels: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(weekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.custom("Roboto-Bold", size: 14))
                    .foregroundColor(.noDiaryBlack)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
    }

    private var dayGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, day in
                if let day = day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 50)
                }
            }
        }
        .padding(.horizontal, 10)
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        changeMonth(by: 1)
                    } else if value.translation.width > 50 {
                        changeMonth(by: -1)
                    }
                }
        )
    }

    private func dayCell(_ date: Date) -> some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let isSelected = cal.isDate(date, inSameDayAs: selectedDate)
        let dateString = dateFormatter.string(from: date)
        let hasDiary = diaryDates.contains(dateString)

        return Button(action: { selectedDate = date }) {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.custom("Roboto-Medium", size: 15))
                    .foregroundColor(isSelected ? .white : .noDiaryBlack)
                    .frame(width: 32, height: 32)
                    .background(isSelected ? Color.noDiaryGreen : Color.clear)
                    .clipShape(Circle())

                if hasDiary {
                    Image("sheepIcon")
                        .resizable()
                        .frame(width: 14, height: 14)
                } else {
                    Color.clear.frame(width: 14, height: 14)
                }
            }
        }
        .frame(height: 50)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.shortWeekdaySymbols
        return Array(symbols[1...]) + [symbols[0]]
    }

    private func changeMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private var daysInMonth: [Date?] {
        let cal = Calendar.current
        let range = cal.range(of: .day, in: .month, for: displayedMonth)!

        var components = cal.dateComponents([.year, .month], from: displayedMonth)
        components.day = 1
        let firstDay = cal.date(from: components)!

        let weekday = cal.component(.weekday, from: firstDay)
        let offset = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            components.day = day
            if let date = cal.date(from: components) {
                days.append(date)
            }
        }
        return days
    }
}
