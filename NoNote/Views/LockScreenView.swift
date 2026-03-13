import SwiftUI

struct LockScreenView: View {
    var onUnlocked: () -> Void

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
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        Task {
            if await BiometricAuthService.authenticate() {
                await MainActor.run { onUnlocked() }
            }
        }
    }
}
