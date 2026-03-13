import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("sheepIcon")
                .resizable()
                .frame(width: 60, height: 60)
                .opacity(0.7)

            Text(String(localized: "#noDiaryYet"))
                .font(.custom(AppFonts.medium, size: 17))
                .foregroundColor(.textPrimary)

            Text(String(localized: "#tapToWrite"))
                .font(.custom(AppFonts.regular, size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color.surfaceCard)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}
