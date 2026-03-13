import SwiftUI

struct FlockBannerView: View {
    let diaryDates: Set<String>
    @State private var showDetail = false

    private var flockState: FlockState {
        FlockService.computeFlockState(diaryDates: diaryDates)
    }

    var body: some View {
        let state = flockState
        Button(action: { if !state.allUnlocked.isEmpty { showDetail = true } }) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .bottom) {
                    // Sky gradient
                    LinearGradient(
                        colors: [
                            Color(red: 0.75, green: 0.88, blue: 0.98),
                            Color(red: 0.82, green: 0.94, blue: 0.82)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Clouds
                    cloudGroup
                        .offset(y: -20)

                    // Grass hills
                    grassHills(width: w)

                    // Sheep or empty state
                    if state.allUnlocked.isEmpty {
                        emptyState
                    } else {
                        sheepRow(state: state)
                    }
                }
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            FlockDetailView(diaryDates: diaryDates)
        }
    }

    // MARK: - Clouds

    private var cloudGroup: some View {
        ZStack {
            // Cloud 1
            HStack(spacing: -8) {
                Circle().fill(.white.opacity(0.6)).frame(width: 20, height: 20)
                Circle().fill(.white.opacity(0.7)).frame(width: 28, height: 28)
                Circle().fill(.white.opacity(0.6)).frame(width: 18, height: 18)
            }
            .offset(x: -60, y: -15)

            // Cloud 2
            HStack(spacing: -6) {
                Circle().fill(.white.opacity(0.5)).frame(width: 16, height: 16)
                Circle().fill(.white.opacity(0.6)).frame(width: 22, height: 22)
                Circle().fill(.white.opacity(0.5)).frame(width: 14, height: 14)
            }
            .offset(x: 70, y: -5)
        }
    }

    // MARK: - Grass

    private func grassHills(width w: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color(red: 0.55, green: 0.82, blue: 0.50))
                .frame(width: w * 1.3, height: 80)
                .offset(y: 20)
            Ellipse()
                .fill(Color(red: 0.60, green: 0.85, blue: 0.55))
                .frame(width: w * 1.1, height: 60)
                .offset(x: -w * 0.1, y: 15)
            Ellipse()
                .fill(Color(red: 0.65, green: 0.88, blue: 0.58))
                .frame(width: w * 0.95, height: 50)
                .offset(x: w * 0.12, y: 10)
        }
        .frame(width: w)
        .clipped()
    }

    // MARK: - Sheep Row

    private func sheepRow(state: FlockState) -> some View {
        let count = state.allUnlocked.count
        let sheepSize: CGFloat = count <= 3 ? 48 : (count <= 6 ? 40 : 32)

        return HStack(spacing: sheepSize * 0.15) {
            ForEach(Array(state.allUnlocked.enumerated()), id: \.element.id) { index, sheep in
                FlockSheepView(definition: sheep, isAwake: state.isAwake, size: sheepSize)
                    .offset(y: CGFloat(index % 2 == 0 ? -2 : 3))
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "signpost.right")
                .font(.system(size: 22))
                .foregroundColor(.white.opacity(0.8))
            Text(String(localized: "#writeToWelcomeSheep"))
                .font(.custom(AppFonts.medium, size: 13))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.bottom, 20)
    }
}
