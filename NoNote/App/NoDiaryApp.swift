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
        .onChange(of: scenePhase) { phase in
            if phase == .background && appLockEnabled {
                isUnlocked = false
            }
        }
    }
}
