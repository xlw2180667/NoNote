import SwiftUI

@main
struct NoDiaryApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                CalendarView()
            }
        }
    }
}
