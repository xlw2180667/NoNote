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

            Link(destination: URL(string: "https://smartkiitos.com/nodairy/privacy/")!) {
                Label(String(localized: "#privacyPolicy"), systemImage: "hand.raised")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }

            #if DEBUG
            Section("Debug") {
                Button(action: { cloudKit.generateTestData() }) {
                    Label("Generate Test Data", systemImage: "wand.and.stars")
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.accent)
                }
                Button(action: { cloudKit.clearTestData() }) {
                    Label("Clear Test Data", systemImage: "trash")
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.danger)
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Color.surface)
        .navigationTitle(String(localized: "#settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
