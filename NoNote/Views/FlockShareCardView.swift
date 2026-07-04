import SwiftUI

/// Static flock share card rendered offscreen via ImageRenderer.
/// Mirrors the pasture look of FlockDetailView with a fixed layout and
/// no animations so it renders cleanly to an image.
struct FlockShareCardView: View {
    let state: FlockState

    static let cardSize = CGSize(width: 340, height: 460)

    private let skyColors = [
        Color(red: 0.75, green: 0.88, blue: 0.98),
        Color(red: 0.82, green: 0.94, blue: 0.82)
    ]
    private let ink = Color(red: 0.35, green: 0.30, blue: 0.28)
    private let grassGreen = Color(red: 0.55, green: 0.82, blue: 0.50)

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)

            cloudGroup
                .position(x: 70, y: 60)
            cloudGroup
                .position(x: 260, y: 110)

            grass

            VStack(spacing: 0) {
                header
                    .padding(.top, 26)
                Spacer()
                sheepField
                    .padding(.bottom, 44)
            }

            Text(String(localized: "#shareCardTagline"))
                .font(.custom(AppFonts.medium, size: 12))
                .foregroundColor(.white)
                .padding(.bottom, 14)
        }
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image("sheepIcon")
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("NoDiary")
                    .font(.custom(AppFonts.bold, size: 15))
                    .foregroundColor(ink.opacity(0.7))
            }

            Text("\(state.sheepCount)")
                .font(.custom(AppFonts.bold, size: 54))
                .foregroundColor(ink)

            Text(String(localized: "#myFlock"))
                .font(.custom(AppFonts.medium, size: 16))
                .foregroundColor(ink.opacity(0.8))

            HStack(spacing: 10) {
                statChip(value: state.currentStreak, label: String(localized: "#currentStreak"))
                statChip(value: state.totalEntries, label: String(localized: "#totalEntries"))
            }
            .padding(.top, 10)
        }
    }

    private func statChip(value: Int, label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(value)")
                .font(.custom(AppFonts.bold, size: 15))
                .foregroundColor(ink)
            Text(label)
                .font(.custom(AppFonts.regular, size: 11))
                .foregroundColor(ink.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.75)))
    }

    // MARK: - Sheep

    private var sheepField: some View {
        let maxShown = 12
        let shown = Array(state.activeSheep.prefix(maxShown))
        let extra = state.activeSheep.count - shown.count
        let rows = stride(from: 0, to: shown.count, by: 4).map {
            Array(shown[$0..<min($0 + 4, shown.count)])
        }

        return VStack(alignment: .leading, spacing: -8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 16) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { i, sheep in
                        FlockSheepView(definition: sheep, isAwake: true, size: 54)
                            .offset(y: CGFloat((i + rowIndex) % 2 == 0 ? -3 : 3))
                    }
                    if rowIndex == rows.count - 1 && extra > 0 {
                        Text("+\(extra)")
                            .font(.custom(AppFonts.bold, size: 16))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(.white.opacity(0.3)))
                    }
                }
                .padding(.leading, rowIndex % 2 == 1 ? 30 : 0)
            }
        }
    }

    // MARK: - Scenery

    private var cloudGroup: some View {
        HStack(spacing: -10) {
            Circle().fill(.white.opacity(0.6)).frame(width: 24, height: 24)
            Circle().fill(.white.opacity(0.7)).frame(width: 34, height: 34)
            Circle().fill(.white.opacity(0.6)).frame(width: 22, height: 22)
        }
    }

    private var grass: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(grassGreen)
                .frame(height: 70)
            Ellipse()
                .fill(grassGreen)
                .frame(width: Self.cardSize.width * 1.4, height: 150)
                .offset(y: 40)
            Ellipse()
                .fill(Color(red: 0.60, green: 0.85, blue: 0.55))
                .frame(width: Self.cardSize.width * 1.2, height: 120)
                .offset(x: -24, y: 30)
        }
        .frame(width: Self.cardSize.width)
    }
}
