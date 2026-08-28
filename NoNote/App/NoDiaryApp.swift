import SwiftUI

@main
struct NoDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    @StateObject private var cloudKit = CloudKitService()
    @StateObject private var storeService = StoreService()
    @StateObject private var weatherService = WeatherService.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isUnlocked = false

    /// Screenshot demo mode seeds its own weather, and a live fetch would pop the
    /// system location prompt over the shot.
    private var isDemoMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-DemoData")
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if appLockEnabled && !isUnlocked {
                LockScreenView { isUnlocked = true }
            } else if hSizeClass == .regular {
                CalendarView(cloudKit: cloudKit, storeService: storeService)
            } else {
                NavigationStack {
                    CalendarView(cloudKit: cloudKit, storeService: storeService)
                }
            }
        }
        .task {
            #if DEBUG
            // Seed demo data for App Store screenshots: launch with -DemoData
            if ProcessInfo.processInfo.arguments.contains("-DemoData") {
                cloudKit.generateTestData(count: 66)
            }
            #endif
            // Delay initial weather fetch so it doesn't block the first frame
            try? await Task.sleep(for: .seconds(1.5))
            if !isDemoMode { weatherService.refresh() }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background && appLockEnabled {
                isUnlocked = false
            }
            if phase == .active && !isDemoMode {
                weatherService.refresh()
            }
        }
    }
}
