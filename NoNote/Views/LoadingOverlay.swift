import SwiftUI

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .noDiaryGreen))
                .scaleEffect(1.5)
                .padding(40)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
        }
    }
}
