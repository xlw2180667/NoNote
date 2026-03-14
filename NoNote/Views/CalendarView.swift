import SwiftUI
import SheepCalendar

struct CalendarView: View {
    @ObservedObject var cloudKit: CloudKitService
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var selection: SheepSelection = .single(Date())
    @State private var showEditor = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSearch = false
    @State private var showStats = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    private var selectedDateDiary: String {
        cloudKit.diaryText(for: selectedDate)
    }

    var body: some View {
        Group {
            if hSizeClass == .regular {
                iPadBody
            } else {
                phoneBody
            }
        }
        .task {
            await fetchCurrentMonth()
        }
        .onChange(of: displayedMonth) { _ in
            Task { await fetchDisplayedMonth() }
        }
        .alert(String(localized: "#oops"), isPresented: $showError) {
            Button(String(localized: "#ok"), role: .cancel) {}
            Button(String(localized: "#dontShowAlert")) {
                UserDefaults.standard.set(true, forKey: "dontShowAlert")
            }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showSearch) {
            SearchView(cloudKit: cloudKit) { dateString in
                navigateToDate(dateString)
            }
        }
        .sheet(isPresented: $showStats) {
            MonthlyStatsView(
                diaryDates: cloudKit.diaryDates,
                diaryCache: cloudKit.diaryCache,
                displayedMonth: displayedMonth
            )
        }
    }

    // MARK: - iPhone Layout

    private var phoneBody: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 12) {
                topBar
                StreakBadgeView(diaryDates: cloudKit.diaryDates)
                FlockBannerView(diaryDates: cloudKit.diaryDates)
                calendarCard(dayCellHeight: 40)
                diarySection
                Spacer()
            }
            .padding(.horizontal, 16)

            fab
        }
        .background(Color.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showEditor) {
            DiaryEditorView(date: selectedDate, cloudKit: cloudKit)
        }
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        HStack(spacing: 0) {
            // Left pane: calendar + preview
            NavigationStack {
                VStack(spacing: 12) {
                    topBar
                    StreakBadgeView(diaryDates: cloudKit.diaryDates)
                    FlockBannerView(diaryDates: cloudKit.diaryDates)
                    calendarCard(dayCellHeight: 48)
                    diarySection
                    Spacer()
                }
                .padding(.horizontal, 16)
                .background(Color.surface.ignoresSafeArea())
                .navigationBarHidden(true)
            }
            .frame(maxWidth: 420)

            Divider()

            // Right pane: editor
            NavigationStack {
                DiaryEditorView(date: selectedDate, cloudKit: cloudKit)
                    .id(dateFormatter.string(from: selectedDate))
            }
        }
        .background(Color.surface.ignoresSafeArea())
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("NoDiary")
                .font(.custom(AppFonts.bold, size: 24))
                .foregroundColor(.textPrimary)

            Spacer()

            Button(action: { showSearch = true }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.textPrimary)
            }

            Button(action: { showStats = true }) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 18))
                    .foregroundColor(.textPrimary)
            }

            NavigationLink {
                SettingsView(cloudKit: cloudKit)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.textPrimary)
            }

            Button(action: goToToday) {
                Text(String(localized: "#today"))
                    .font(.custom(AppFonts.medium, size: 14))
                    .foregroundColor(.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accent, lineWidth: 1.5)
                    )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Calendar Card

    private func calendarCard(dayCellHeight: CGFloat) -> some View {
        SheepCalendarView(displayedMonth: $displayedMonth, selection: $selection)
            .sheepCalendarFirstWeekday(.monday)
            .sheepCalendarPlaceholder(.fillHeadTail)
            .sheepCalendarDateRange(max: Date())
            .sheepCalendarTheme(SheepCalendarTheme(
                selectionColor: .accent,
                todayColor: .warmAccent,
                defaultTextColor: .textPrimary,
                weekendTextColor: .textPrimary,
                headerTextColor: .textPrimary,
                weekdayLabelColor: .textSecondary,
                dayFont: .custom(AppFonts.medium, size: 15),
                weekdayFont: .custom(AppFonts.bold, size: 14),
                headerFont: .custom(AppFonts.regular, size: 17),
                dayCellHeight: dayCellHeight
            ))
            .sheepCalendarHeader { date, back, forward in
                HStack {
                    Button(action: back) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.textPrimary)
                    }
                    Spacer()
                    Text(monthYearString(for: date))
                        .font(.custom(AppFonts.regular, size: 17))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Button(action: forward) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.textPrimary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .sheepCalendarDayCell { date, state in
                let dateString = dateFormatter.string(from: date)
                let hasDiary = cloudKit.diaryDates.contains(dateString)
                let mood = cloudKit.moodForDateString(dateString)
                let weatherCode = cloudKit.diaryCache[dateString]?.weather
                VStack(spacing: 1) {
                    Text("\(state.dayNumber)")
                        .font(.custom(AppFonts.medium, size: 14))
                        .foregroundColor(dayTextColor(state: state))
                        .frame(width: 28, height: 28)
                        .background(state.isSelected ? Color.accent : Color.clear)
                        .clipShape(Circle())

                    if hasDiary && state.belongsToDisplayedMonth {
                        HStack(spacing: 2) {
                            if let mood = mood, SheepMood.isSheepMood(mood) {
                                SheepMoodIcon(mood: mood, size: 12)
                            } else if let mood = mood {
                                Text(mood)
                                    .font(.system(size: 10))
                                    .frame(width: 12, height: 12)
                            } else {
                                Image("sheepIcon")
                                    .resizable()
                                    .frame(width: 12, height: 12)
                            }
                            if let code = weatherCode {
                                Image(systemName: WeatherCondition.symbolForCode(code))
                                    .font(.system(size: 8))
                                    .foregroundColor(WeatherCondition.colorForCode(code))
                            }
                        }
                        .frame(height: 12)
                    } else {
                        Color.clear.frame(width: 12, height: 12)
                    }
                }
                .opacity(state.isDisabled ? 0.3 : 1.0)
            }
            .onSheepDateSelect { date in
                selectedDate = date
            }
            .onSheepPageChange { month in
                displayedMonth = month
            }
            .background(Color.surfaceCard)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Diary Section

    private var diarySection: some View {
        Group {
            if selectedDateDiary.isEmpty {
                EmptyStateView()
                    .onTapGesture {
                        if hSizeClass != .regular { showEditor = true }
                    }
            } else {
                let entry = cloudKit.diaryCacheEntry(for: selectedDate)
                let mood = entry?.mood
                let weather = entry?.weather
                let photoURLs = entry?.photoFileURLs ?? []
                DiaryPreviewCard(date: selectedDate, diaryText: selectedDateDiary, mood: mood, weather: weather, photoURLs: photoURLs)
                    .onTapGesture {
                        if hSizeClass != .regular { showEditor = true }
                    }
            }
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button(action: { showEditor = true }) {
            Image(systemName: "pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accent)
                .clipShape(Circle())
                .shadow(color: Color.accent.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Helpers

    private func dayTextColor(state: DayState) -> Color {
        if state.isSelected {
            return .white
        } else if state.belongsToDisplayedMonth {
            return .textPrimary
        } else {
            return .gray.opacity(0.5)
        }
    }

    private func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
        selection = .single(Date())
    }

    private func navigateToDate(_ dateString: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d-yyyy"
        if let date = formatter.date(from: dateString) {
            selectedDate = date
            displayedMonth = date
            selection = .single(date)
            showEditor = true
        }
    }

    private func fetchCurrentMonth() async {
        let cal = Calendar.current
        let month = cal.component(.month, from: Date())
        let year = cal.component(.year, from: Date())
        await fetchMonth(monthAndYear: "\(month)-\(year)")
    }

    private func fetchDisplayedMonth() async {
        let cal = Calendar.current
        let month = cal.component(.month, from: displayedMonth)
        let year = cal.component(.year, from: displayedMonth)
        await fetchMonth(monthAndYear: "\(month)-\(year)")
    }

    private func fetchMonth(monthAndYear: String) async {
        do {
            try await cloudKit.fetchDiaries(monthAndYear: monthAndYear)
        } catch {
            if !UserDefaults.standard.bool(forKey: "dontShowAlert") {
                errorMessage = String(localized: "#cannotConnectToICloud")
                showError = true
            }
        }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
