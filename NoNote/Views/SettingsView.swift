import SwiftUI

struct SettingsView: View {
    @ObservedObject var cloudKit: CloudKitService
    @ObservedObject var storeService: StoreService
    @AppStorage("writingPromptsEnabled") private var promptsEnabled = true

    var body: some View {
        List {
            Toggle(isOn: $promptsEnabled) {
                Label(String(localized: "#writingPrompts"), systemImage: "lightbulb")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }
            .tint(.accent)

            NavigationLink {
                SecuritySettingsView()
            } label: {
                Label(String(localized: "#security"), systemImage: "lock.shield")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }

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

            if storeService.isPro {
                Label(String(localized: "#proUnlocked"), systemImage: "checkmark.seal.fill")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.accent)
            } else {
                Button {
                    Task { try? await storeService.purchase() }
                } label: {
                    Label(String(localized: "#unlockFullFlock"), systemImage: "sparkles")
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.accent)
                }

                Button {
                    Task { await storeService.restore() }
                } label: {
                    Label(String(localized: "#restorePurchases"), systemImage: "arrow.clockwise")
                        .font(.custom(AppFonts.regular, size: 16))
                        .foregroundColor(.textPrimary)
                }
            }

            Link(destination: URL(string: "https://smartkiitos.com/nodiary/privacy/")!) {
                Label(String(localized: "#privacyPolicy"), systemImage: "hand.raised")
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
            }

            #if DEBUG
            Section("Flock Test Scenarios") {
                // Empty: 0 sheep
                Button(action: { cloudKit.generateTestData(count: 3) }) {
                    Label("3 entries — No sheep", systemImage: "0.circle")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.accent)
                }
                // 1 regular sheep (white) — 7 entries, streak 7
                Button(action: { cloudKit.generateTestData(count: 7) }) {
                    Label("7 entries — 1 sheep (White)", systemImage: "1.circle")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.accent)
                }
                // 2 regular + 1 special (star) — 14 entries, streak 14
                Button(action: { cloudKit.generateTestData(count: 14) }) {
                    Label("14 entries — 3 sheep (streak 14)", systemImage: "3.circle")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.accent)
                }
                // 3 regular + 2 special (star+golden) — 50 entries, streak 50
                Button(action: { cloudKit.generateTestData(count: 50) }) {
                    Label("50 entries — 6 sheep (streak 50)", systemImage: "6.circle")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.accent)
                }
                // Full flock — 200 entries, streak 200
                Button(action: { cloudKit.generateTestData(count: 200) }) {
                    Label("200 entries — ALL sheep", systemImage: "star.circle")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.warmAccent)
                }
                // Sleeping sheep — 20 entries but streak broken
                Button(action: { cloudKit.generateTestData(count: 20, breakStreak: true) }) {
                    Label("20 entries — Sleeping (broken streak)", systemImage: "moon.zzz")
                        .font(.custom(AppFonts.regular, size: 14))
                        .foregroundColor(.textSecondary)
                }
            }

            Section("Debug") {
                Button(action: { cloudKit.generateTestData() }) {
                    Label("Generate Default Test Data", systemImage: "wand.and.stars")
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
