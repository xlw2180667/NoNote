import SwiftUI
import UsageKit

struct LockScreenView: View {
    var onUnlocked: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    /// Face ID is offered by itself once per trip to the foreground. Its own sheet makes the
    /// scene inactive and active again, so without this a cancel would re-prompt forever.
    @State private var hasAutoPrompted = false
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("sheep")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)

            Text("NoDiary")
                .font(.custom(AppFonts.bold, size: 28))
                .foregroundColor(.textPrimary)

            Button {
                authenticate()
            } label: {
                Label(String(localized: "#unlock"), systemImage: "lock.open")
                    .font(.custom(AppFonts.medium, size: 18))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.accent)
                    .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surface.ignoresSafeArea())
        // Not onAppear: RootView locks as the app goes to the background, so this view
        // usually appears while backgrounded, where Face ID can't be shown. Asking then failed
        // at once and, coming back, nothing asked again — every return needed a tap on Unlock.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .background:
                hasAutoPrompted = false
            case .active where !hasAutoPrompted:
                #if DEBUG
                // Screenshot demo mode: show the lock screen itself, no system prompt
                if UserDefaults.standard.string(forKey: "DemoScreen") == "lock" { return }
                #endif
                hasAutoPrompted = true
                authenticate()
            default:
                break
            }
        }
        .usageScreen(DiaryScreen.lockScreen)
    }

    private func authenticate() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task { @MainActor in
            defer { isAuthenticating = false }
            switch await BiometricAuthService.evaluate() {
            case .success:
                onUnlocked()
            case .cancelled:
                break
            case .failed(let code):
                UsageStats.shared.recordFailure(DiaryFailure.unlock, DiaryFailureReason(authError: code))
            }
        }
    }
}
