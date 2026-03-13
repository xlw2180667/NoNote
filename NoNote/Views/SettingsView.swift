import SwiftUI

struct SettingsView: View {
    @ObservedObject var cloudKit: CloudKitService

    var body: some View {
        List {
            // Phase 5: Daily Reminder
            NavigationLink {
                ReminderSettingsView()
            } label: {
                Label(String(localized: "#dailyReminder"), systemImage: "bell")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }

            // Phase 6: Export
            NavigationLink {
                ExportView(cloudKit: cloudKit)
            } label: {
                Label(String(localized: "#export"), systemImage: "square.and.arrow.up")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.surface)
        .navigationTitle(String(localized: "#settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
