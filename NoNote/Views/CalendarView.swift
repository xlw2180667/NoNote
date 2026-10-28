import SwiftUI
import SheepCalendar
import UsageKit

struct CalendarView: View {
    @ObservedObject var cloudKit: CloudKitService
    @ObservedObject var storeService: StoreService
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @State private var selection: SheepSelection = .single(Date())
    @State private var showEditor = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSearch = false
    @State private var showStats = false
    @State private var showDressUp = false
    @State private var showMonthPicker = false
    #if DEBUG
    @State private var showDemoFlock = false
    @State private var showDemoStats = false
    @State private var showDemoShareCard = false
    @State private var showDemoLock = false
    @State private var showDemoImport = false
    @State private var showDemoCostumes = false
    #endif

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M-d-yyyy"
        return f
    }()

    /// Narrower than this, the calendar and the editor share the screen by navigation instead.
    private static let minSplitWidth: CGFloat = 700

    private var selectedDateDiary: String {
        cloudKit.diaryText(for: selectedDate)
    }

    var body: some View {
        GeometryReader { proxy in
            // Width, not just size class: an open iPhone Duo held upright is "regular" at 669pt,
            // and two 330pt panes there lost the editor's title and stacked "Today" letter by letter.
            if hSizeClass == .regular && proxy.size.width >= Self.minSplitWidth {
                iPadBody
            } else {
                phoneBody
            }
        }
        .task {
            #if DEBUG
            // Auto-open a screen for App Store screenshots: -DemoScreen editor|stats|flock
            if let screen = UserDefaults.standard.string(forKey: "DemoScreen") {
                try? await Task.sleep(for: .seconds(0.8))
                switch screen {
                case "editor", "paper": showEditor = true
                case "stats":
                    demoShowLastMonth()
                    showDemoStats = true
                case "flock": showDemoFlock = true
                case "sharecard": showDemoShareCard = true
                case "lock": showDemoLock = true
                case "import": showDemoImport = true
                case "costumes": showDemoCostumes = true
                case "monthpicker": showMonthPicker = true
                case "dressup": showDressUp = true
                case "lastMonth": demoShowLastMonth()
                default: break
                }
            }
            #endif
            await fetchCurrentMonth()
        }
        .usageScreen(DiaryScreen.calendar)
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
        .sheet(isPresented: $showDressUp) {
            NavigationStack {
                AppearanceView(storeService: storeService)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button { showDressUp = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchView(cloudKit: cloudKit) { dateString in
                navigateToDate(dateString)
            }
        }
        .sheet(isPresented: $showMonthPicker) {
            MonthPickerView(displayedMonth: $displayedMonth, cloudKit: cloudKit)
        }
        .sheet(isPresented: $showStats) {
            MonthlyStatsView(
                diaryDates: cloudKit.diaryDates,
                diaryCache: cloudKit.diaryCache,
                displayedMonth: displayedMonth
            )
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showDemoFlock) {
            FlockDetailView(diaryDates: cloudKit.diaryDates, storeService: storeService)
        }
        .fullScreenCover(isPresented: $showDemoStats) {
            MonthlyStatsView(
                diaryDates: cloudKit.diaryDates,
                diaryCache: cloudKit.diaryCache,
                displayedMonth: displayedMonth
            )
        }
        .fullScreenCover(isPresented: $showDemoLock) {
            LockScreenView { }
        }
        .sheet(isPresented: $showDemoImport) {
            NavigationStack { ImportView(cloudKit: cloudKit) }
        }
        .sheet(isPresented: $showDemoCostumes) { CostumeGalleryView() }
        .fullScreenCover(isPresented: $showDemoShareCard) {
            FlockShareCardView(state: FlockService.computeFlockState(
                diaryDates: cloudKit.diaryDates, isPro: storeService.isPro))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.surface)
        }
        #endif
    }

    // MARK: - iPhone Layout

    private var phoneBody: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // Scrolls only when it doesn't fit: on short screens (SE, the folded iPhone Duo)
                // the preview card used to end up under the pencil button, out of reach.
                ScrollView {
                    VStack(spacing: 12) {
                        topBar
                        StreakBadgeView(diaryDates: cloudKit.diaryDates)
                        FlockBannerView(diaryDates: cloudKit.diaryDates, storeService: storeService)
                        calendarCard(dayCellHeight: 40)
                        diarySection(opensEditor: true)
                    }
                    .padding(.horizontal, 16)
                    // Room to scroll the last card clear of the pencil button.
                    .padding(.bottom, 88)
                }
                .scrollBounceBehavior(.basedOnSize)

                fab
            }
            .background(Color.surface.ignoresSafeArea())
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showEditor) {
                DiaryEditorView(date: selectedDate, cloudKit: cloudKit, storeService: storeService)
            }
        }
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        GeometryReader { proxy in
            let fold = verticalFold(in: proxy)
            HStack(spacing: 0) {
                // Left pane: calendar + preview
                NavigationStack {
                    // Scrolls only when it doesn't fit: with the keyboard up on an open
                    // iPhone Duo, the pane is shorter than the calendar and was pushed off the top.
                    ScrollView {
                        VStack(spacing: 12) {
                            topBar
                            StreakBadgeView(diaryDates: cloudKit.diaryDates)
                            FlockBannerView(diaryDates: cloudKit.diaryDates, storeService: storeService)
                            calendarCard(dayCellHeight: 48)
                            // The editor is already beside it.
                            diarySection(opensEditor: false)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .background(Color.surface.ignoresSafeArea())
                    .navigationBarHidden(true)
                }
                .noVerticalToolbar()
                .frame(width: fold?.minX)
                .frame(maxWidth: fold == nil ? 420 : nil)

                // On an open iPhone Duo the panes meet at the fold, so neither the calendar
                // nor a line of the diary sits across the crease.
                if let fold, fold.width > 0 {
                    Color.surface.frame(width: fold.width)
                } else {
                    Divider()
                }

                // Right pane: editor
                NavigationStack {
                    DiaryEditorView(date: selectedDate, cloudKit: cloudKit, storeService: storeService, isPane: true)
                        .id(dateFormatter.string(from: selectedDate))
                }
            }
        }
        .background(Color.surface.ignoresSafeArea())
    }

    /// The crease of an open iPhone Duo, when it runs top to bottom through this view.
    private func verticalFold(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return proxy.reservedRegions(kind: .division)
            .map(\.frame)
            .first { $0.height > $0.width && $0.minX > 0 && $0.maxX < proxy.size.width }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("NoDiary")
                .font(.custom(AppFonts.bold, size: 24))
                .foregroundColor(.textPrimary)
                // The wordmark never wraps; the spacer gives way first.
                .lineLimit(1)
                .fixedSize()

            Spacer()

            Button(action: { showDressUp = true }) {
                Image(systemName: "tshirt")
                    .font(.system(size: 17))
                    .foregroundColor(.textPrimary)
            }
            .accessibilityLabel(String(localized: "#dressUp"))

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
                SettingsView(cloudKit: cloudKit, storeService: storeService)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.textPrimary)
            }

            Button(action: goToToday) {
                Text(String(localized: "#today"))
                    .font(.custom(AppFonts.medium, size: 14))
                    .lineLimit(1)
                    .fixedSize()
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
                    // Tappable: stepping a month at a time does not scale to an imported history
                    Button { showMonthPicker = true } label: {
                        HStack(spacing: 4) {
                            Text(monthYearString(for: date))
                                .font(.custom(AppFonts.regular, size: 17))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textSecondary)
                        }
                        .foregroundColor(.textPrimary)
                        .contentShape(Rectangle())
                    }
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
                                DressedMoodSheep(mood: mood, size: 12)
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

    private func diarySection(opensEditor: Bool) -> some View {
        Group {
            if selectedDateDiary.isEmpty {
                EmptyStateView()
                    .onTapGesture {
                        if opensEditor { showEditor = true }
                    }
            } else {
                let entry = cloudKit.diaryCacheEntry(for: selectedDate)
                let mood = entry?.mood
                let weather = entry?.weather
                let photoURLs = entry?.photoFileURLs ?? []
                DiaryPreviewCard(date: selectedDate, diaryText: selectedDateDiary, mood: mood, weather: weather, photoURLs: photoURLs)
                    .onTapGesture {
                        if opensEditor { showEditor = true }
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

    #if DEBUG
    /// Screenshot helper: show the previous (fully written) month.
    private func demoShowLastMonth() {
        let cal = Calendar.current
        guard let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) else { return }
        displayedMonth = lastMonth
        var comps = cal.dateComponents([.year, .month], from: lastMonth)
        comps.day = 20
        if let day = cal.date(from: comps) {
            selectedDate = day
            selection = .single(day)
        }
    }
    #endif

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

    /// Pauses before each quiet retry of a transient fetch error.
    private static let fetchRetryDelays: [Duration] = [.seconds(2), .seconds(5)]

    private func fetchMonth(monthAndYear: String) async {
        // Retried quietly first: on a mainland-China install the first requests fail until the
        // "allow network data" prompt is answered, and those new users were greeted with
        // "can't connect to iCloud" on day one while writing worked fine from the local cache.
        var retries = Self.fetchRetryDelays[...]
        while true {
            do {
                try await cloudKit.fetchDiaries(monthAndYear: monthAndYear)
                return
            } catch {
                let reason = DiaryFailureReason(cloudKitError: error)
                if reason.isTransient, let delay = retries.popFirst() {
                    try? await Task.sleep(for: delay)
                    if Task.isCancelled { return }
                    continue
                }
                // Counted even when the alert is muted: the month's sheep are missing either way.
                UsageStats.shared.recordFailure(DiaryFailure.icloudFetch, reason)
                if !UserDefaults.standard.bool(forKey: "dontShowAlert") {
                    errorMessage = String(localized: "#cannotConnectToICloud")
                    showError = true
                }
                return
            }
        }
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

private extension View {
    /// The calendar pane hides its navigation bar, but on iPhone Duo (iOS 27.1) a navigation
    /// stack still keeps a strip down its trailing edge for a vertical toolbar — 84pt of empty
    /// space beside the calendar, which squeezed the top bar until "Today" wrapped.
    @ViewBuilder func noVerticalToolbar() -> some View {
        if #available(iOS 27.1, *) {
            toolbarVerticalBehavior(.disabled)
        } else {
            self
        }
    }
}
