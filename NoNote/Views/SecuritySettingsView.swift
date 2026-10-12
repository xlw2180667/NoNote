import SwiftUI
import LocalAuthentication
import UsageKit

struct SecuritySettingsView: View {
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var toggleValue = false

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "#appLock"), isOn: $toggleValue)
                    .font(.custom(AppFonts.regular, size: 16))
                    .foregroundColor(.textPrimary)
                    .tint(.accent)
                    .onChange(of: toggleValue) { newValue in
                        if newValue {
                            enableLock()
                        } else {
                            appLockEnabled = false
                        }
                    }
            } footer: {
                Text(String(localized: "#appLockDescription"))
                    .font(.custom(AppFonts.regular, size: 13))
                    .foregroundColor(.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.surface)
        .navigationTitle(String(localized: "#security"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            toggleValue = appLockEnabled
        }
        .usageScreen(DiaryScreen.security)
    }

    private func enableLock() {
        UsageStats.shared.recordStarted(DiaryFlow.lockSetup)
        Task {
            let success = await BiometricAuthService.authenticate()
            if success {
                UsageStats.shared.recordCompleted(DiaryFlow.lockSetup)
                appLockEnabled = true
            } else {
                toggleValue = false
            }
        }
    }
}
