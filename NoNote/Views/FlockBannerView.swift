import SwiftUI

private struct BannerScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FlockBannerView: View {
    let diaryDates: Set<String>
    @ObservedObject var storeService: StoreService
    @State private var showDetail = false
    @State private var sheepScrollOffset: CGFloat = 0

    private var flockState: FlockState {
        FlockService.computeFlockState(diaryDates: diaryDates, isPro: storeService.isPro)
    }

    private let skyColors = [
        Color(red: 0.75, green: 0.88, blue: 0.98),
        Color(red: 0.82, green: 0.94, blue: 0.82)
    ]

    var body: some View {
        let state = flockState
        Button(action: { if !state.sheep.isEmpty { showDetail = true } }) {
            GeometryReader { geo in
                let w = geo.size.width

                // Compute grass parallax dimensions
                let sheepSize: CGFloat = 44
                let hSpacing: CGFloat = sheepSize * 0.3
                let topCount = (state.sheepCount + 1) / 2
                let bottomCount = state.sheepCount / 2
                let stagger = (sheepSize + hSpacing) / 2
                let topWidth = CGFloat(topCount) * (sheepSize + hSpacing)
                let bottomWidth = CGFloat(bottomCount) * (sheepSize + hSpacing) + stagger
                let sheepContentWidth = max(w, max(topWidth, bottomWidth) + 80)
                let parallax: CGFloat = 0.3
                let totalScroll = max(0, sheepContentWidth - w)
                let grassWidth = w + 2 * totalScroll * parallax + 40

                ZStack(alignment: .bottom) {
                    // Fixed sky
                    LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)
                    cloudGroup(at: CGPoint(x: -w * 0.2, y: -20))
                    cloudGroup(at: CGPoint(x: w * 0.15, y: -15))

                    // Grass with parallax
                    // .frame(width: w) prevents grass from inflating ZStack layout
                    grassHills(width: grassWidth)
                        .offset(x: sheepScrollOffset * parallax)
                        .frame(width: w)

                    if state.sheep.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "signpost.right")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.8))
                            Text(String(localized: "#writeToWelcomeSheep"))
                                .font(.custom(AppFonts.medium, size: 13))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.bottom, 20)
                    } else {
                        // Sheep scroll at full speed
                        ScrollView(.horizontal, showsIndicators: false) {
                            bannerSheepLayout(state: state, minWidth: w)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear.preference(key: BannerScrollOffsetKey.self,
                                            value: proxy.frame(in: .named("bannerScroll")).minX)
                                    }
                                )
                        }
                        .coordinateSpace(name: "bannerScroll")
                        .onPreferenceChange(BannerScrollOffsetKey.self) { sheepScrollOffset = $0 }
                    }
                }
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            FlockDetailView(diaryDates: diaryDates, storeService: storeService)
        }
    }

    // MARK: - Sheep Layout

    private func bannerSheepLayout(state: FlockState, minWidth: CGFloat) -> some View {
        let allSheep: [(def: SheepDefinition, ghost: Bool)] =
            state.activeSheep.map { ($0, false) } + state.ghostSheep.map { ($0, true) }
        let sheepSize: CGFloat = 44
        let hSpacing: CGFloat = sheepSize * 0.3
        let totalCount = allSheep.count
        let topRow = stride(from: 0, to: totalCount, by: 2).map { allSheep[$0] }
        let bottomRow = stride(from: 1, to: totalCount, by: 2).map { allSheep[$0] }
        let stagger = (sheepSize + hSpacing) / 2
        let topWidth = CGFloat(topRow.count) * (sheepSize + hSpacing)
        let bottomWidth = CGFloat(bottomRow.count) * (sheepSize + hSpacing) + stagger
        let contentWidth = max(minWidth, max(topWidth, bottomWidth) + 80)

        return VStack(alignment: .leading, spacing: 0) {
            Spacer()
            HStack(spacing: hSpacing) {
                ForEach(Array(topRow.enumerated()), id: \.element.def.id) { i, item in
                    FlockSheepView(definition: item.def, isAwake: state.isAwake, size: sheepSize, isGhost: item.ghost)
                        .offset(y: CGFloat(i % 2 == 0 ? -1 : 2))
                }
            }
            HStack(spacing: hSpacing) {
                ForEach(Array(bottomRow.enumerated()), id: \.element.def.id) { i, item in
                    FlockSheepView(definition: item.def, isAwake: state.isAwake, size: sheepSize, isGhost: item.ghost)
                        .offset(y: CGFloat(i % 2 == 0 ? 0 : 3))
                }
            }
            .padding(.leading, stagger)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 6)
        .frame(width: contentWidth, height: 130)
    }

    // MARK: - Clouds

    private func cloudGroup(at offset: CGPoint) -> some View {
        ZStack {
            HStack(spacing: -8) {
                Circle().fill(.white.opacity(0.6)).frame(width: 20, height: 20)
                Circle().fill(.white.opacity(0.7)).frame(width: 28, height: 28)
                Circle().fill(.white.opacity(0.6)).frame(width: 18, height: 18)
            }
            .offset(x: -40, y: -10)
            HStack(spacing: -6) {
                Circle().fill(.white.opacity(0.5)).frame(width: 16, height: 16)
                Circle().fill(.white.opacity(0.6)).frame(width: 22, height: 22)
                Circle().fill(.white.opacity(0.5)).frame(width: 14, height: 14)
            }
            .offset(x: 50, y: 5)
        }
        .offset(x: offset.x, y: offset.y)
    }

    // MARK: - Grass

    private func grassHills(width w: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.55, green: 0.82, blue: 0.50))
                .frame(height: 35)
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
}
