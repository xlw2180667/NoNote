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
    @StateObject private var weatherService = WeatherService.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isUnlocked = false

    var body: some View {
        Group {
            if appLockEnabled && !isUnlocked {
                LockScreenView { isUnlocked = true }
            } else if hSizeClass == .regular {
                CalendarView(cloudKit: cloudKit)
            } else {
                NavigationStack {
                    CalendarView(cloudKit: cloudKit)
                }
            }
        }
        .task {
            // Delay initial weather fetch so it doesn't block the first frame
            try? await Task.sleep(for: .seconds(1.5))
            weatherService.refresh()
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background && appLockEnabled {
                isUnlocked = false
            }
            if phase == .active {
                weatherService.refresh()
            }
        }
    }
}
