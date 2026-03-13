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

    var body: some View {
        if hSizeClass == .regular {
            CalendarView(cloudKit: cloudKit)
        } else {
            NavigationStack {
                CalendarView(cloudKit: cloudKit)
            }
        }
    }
}
