import SwiftUI

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct FlockDetailView: View {
    let diaryDates: Set<String>
    @ObservedObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss
    @State private var sheepScrollOffset: CGFloat = 0
    @State private var purchaseError: String?
    @State private var zoomedSheep: SheepDefinition?
    @State private var previewCostume: SheepCostume?

    private var flockState: FlockState {
        FlockService.computeFlockState(diaryDates: diaryDates, isPro: storeService.isPro)
    }

    var body: some View {
        let state = flockState
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection(state: state)
                    pastureScene(state: state)
                    progressCard(state: state)
                    if !state.ghostSheep.isEmpty {
                        departedCard(state: state)
                    }
                    statsCard(state: state)
                }
                .padding(16)
            }
            .background(Color.surface.ignoresSafeArea())
            .navigationTitle(String(localized: "#myFlock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .overlay {
                if let sheep = zoomedSheep {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                previewCostume = nil
                                zoomedSheep = nil
                            }
                        }
                    wardrobeCard(sheep: sheep, isAwake: state.isAwake)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: zoomedSheep?.id)
        }
    }

    // MARK: - Wardrobe Card

    private func wardrobeCard(sheep: SheepDefinition, isAwake: Bool) -> some View {
        let activeCostume = previewCostume ?? sheep.costume
        var previewDef = sheep
        previewDef.costume = activeCostume

        return VStack(spacing: 16) {
            // Enlarged sheep preview
            FlockSheepView(definition: previewDef, isAwake: isAwake, size: 160)

            // Title
            Text(String(localized: "#chooseCostume"))
                .font(.custom(AppFonts.medium, size: 14))
                .foregroundColor(.textSecondary)

            // Costume selector
            HStack(spacing: 12) {
                ForEach(SheepCostume.allCases, id: \.self) { costume in
                    costumeButton(costume: costume, isSelected: activeCostume == costume, sheepId: sheep.id)
                }
            }

            // Pro unlock button for free users
            if !storeService.isPro {
                VStack(spacing: 8) {
                    Text(String(localized: "#proFeature"))
                        .font(.custom(AppFonts.bold, size: 13))
                        .foregroundColor(.warmAccent)
                    Text(String(localized: "#unlockToUseCostumes"))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                    Button {
                        Task {
                            do {
                                try await storeService.purchase()
                            } catch {
                                purchaseError = error.localizedDescription
                            }
                        }
                    } label: {
                        Text(String(localized: "#unlockFullFlock"))
                            .font(.custom(AppFonts.bold, size: 14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.accent)
                            .cornerRadius(10)
                    }
                }
            }
        }
        .padding(24)
        .background(Color.surfaceCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private func costumeButton(costume: SheepCostume, isSelected: Bool, sheepId: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                previewCostume = costume
            }
            if storeService.isPro {
                FlockService.saveCostume(costume, for: sheepId)
                // Update zoomedSheep so the overlay reflects saved costume
                if var updated = zoomedSheep {
                    updated.costume = costume
                    zoomedSheep = updated
                }
            }
        } label: {
            costumeIcon(costume: costume)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accent.opacity(0.15) : Color.surface)
                )
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accent : Color.textSecondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                )
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private func costumeIcon(costume: SheepCostume) -> some View {
        switch costume {
        case .none:
            Image(systemName: "circle.slash")
                .font(.system(size: 18))
                .foregroundColor(.textSecondary)
        case .scarf:
            Image("costume_scarf")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
        case .sunglasses:
            Image("costume_sunglasses")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
        case .bowtie:
            Image("costume_bowtie")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
        case .santaHat:
            Image("costume_santahat")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 26, height: 26)
        }
    }

    // MARK: - Header

    private func headerSection(state: FlockState) -> some View {
        VStack(spacing: 4) {
            Text("\(state.sheepCount)")
                .font(.custom(AppFonts.bold, size: 48))
                .foregroundColor(.accent)
            if state.isAwake {
                Text(String(localized: "#sheepAllAwake"))
                    .font(.custom(AppFonts.medium, size: 15))
                    .foregroundColor(.textSecondary)
            } else {
                Text(String(localized: "#sheepAllSleeping"))
                    .font(.custom(AppFonts.medium, size: 15))
                    .foregroundColor(.warmAccent)
            }
        }
    }

    // MARK: - Pasture Scene

    private let skyColors = [
        Color(red: 0.75, green: 0.88, blue: 0.98),
        Color(red: 0.82, green: 0.94, blue: 0.82)
    ]

    private func pastureScene(state: FlockState) -> some View {
        GeometryReader { geo in
            let w = geo.size.width

            // Compute grass parallax dimensions
            let sheepSize: CGFloat = 48
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
                detailCloudGroup(at: CGPoint(x: -w * 0.2, y: -30))
                detailCloudGroup(at: CGPoint(x: w * 0.15, y: -20))

                // Grass with parallax — moves slower than sheep
                // .frame(width: w) prevents grass from inflating ZStack layout
                detailGrass(width: grassWidth)
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
                    .padding(.bottom, 40)
                } else {
                    // Sheep scroll at full speed
                    ScrollView(.horizontal, showsIndicators: false) {
                        detailSheepLayout(state: state, minWidth: w)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear.preference(key: ScrollOffsetKey.self,
                                        value: proxy.frame(in: .named("detailScroll")).minX)
                                }
                            )
                    }
                    .coordinateSpace(name: "detailScroll")
                    .onPreferenceChange(ScrollOffsetKey.self) { sheepScrollOffset = $0 }
                }
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func detailSheepLayout(state: FlockState, minWidth: CGFloat) -> some View {
        let allSheep: [(def: SheepDefinition, ghost: Bool)] =
            state.activeSheep.map { ($0, false) } + state.ghostSheep.map { ($0, true) }
        let sheepSize: CGFloat = 48
        let hSpacing: CGFloat = sheepSize * 0.3
        let totalCount = allSheep.count
        let topRow = stride(from: 0, to: totalCount, by: 2).map { allSheep[$0] }
        let bottomRow = stride(from: 1, to: totalCount, by: 2).map { allSheep[$0] }
        let stagger = (sheepSize + hSpacing) / 2
        let topWidth = CGFloat(topRow.count) * (sheepSize + hSpacing)
        let bottomWidth = CGFloat(bottomRow.count) * (sheepSize + hSpacing) + stagger
        let contentWidth = max(minWidth, max(topWidth, bottomWidth) + 80)

        return VStack(alignment: .leading, spacing: 4) {
            Spacer()
            HStack(spacing: hSpacing) {
                ForEach(Array(topRow.enumerated()), id: \.element.def.id) { i, item in
                    FlockSheepView(definition: item.def, isAwake: state.isAwake, size: sheepSize, isGhost: item.ghost)
                        .offset(y: CGFloat(i % 2 == 0 ? -2 : 3))
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { zoomedSheep = item.def } }
                }
            }
            HStack(spacing: hSpacing) {
                ForEach(Array(bottomRow.enumerated()), id: \.element.def.id) { i, item in
                    FlockSheepView(definition: item.def, isAwake: state.isAwake, size: sheepSize, isGhost: item.ghost)
                        .offset(y: CGFloat(i % 2 == 0 ? 0 : 4))
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { zoomedSheep = item.def } }
                }
            }
            .padding(.leading, stagger)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(width: contentWidth, height: 220)
    }

    private func detailCloudGroup(at offset: CGPoint) -> some View {
        ZStack {
            HStack(spacing: -10) {
                Circle().fill(.white.opacity(0.6)).frame(width: 24, height: 24)
                Circle().fill(.white.opacity(0.7)).frame(width: 34, height: 34)
                Circle().fill(.white.opacity(0.6)).frame(width: 22, height: 22)
            }
            .offset(x: -50, y: -12)
            HStack(spacing: -8) {
                Circle().fill(.white.opacity(0.5)).frame(width: 20, height: 20)
                Circle().fill(.white.opacity(0.6)).frame(width: 28, height: 28)
                Circle().fill(.white.opacity(0.5)).frame(width: 18, height: 18)
            }
            .offset(x: 60, y: 4)
        }
        .offset(x: offset.x, y: offset.y)
    }

    private func detailGrass(width w: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Base fill ensures full green coverage at edges
            Rectangle()
                .fill(Color(red: 0.55, green: 0.82, blue: 0.50))
                .frame(height: 45)
            Ellipse()
                .fill(Color(red: 0.55, green: 0.82, blue: 0.50))
                .frame(width: w * 1.4, height: 100)
                .offset(y: 25)
            Ellipse()
                .fill(Color(red: 0.60, green: 0.85, blue: 0.55))
                .frame(width: w * 1.2, height: 80)
                .offset(x: -w * 0.07, y: 18)
        }
        .frame(width: w)
        .clipped()
    }

    // MARK: - Progress Card

    private func progressCard(state: FlockState) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(String(localized: "#nextSheep"))
                    .font(.custom(AppFonts.bold, size: 17))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(String(localized: "#streakDays\(state.currentStreak)"))
                    .font(.custom(AppFonts.regular, size: 13))
                    .foregroundColor(.textSecondary)
            }

            if state.isAwake {
                // Regular sheep progress
                progressRow(
                    progress: state.progressToNextRegular,
                    detail: String(localized: "#entriesRemaining\(state.daysToNextRegular)")
                )
                HStack(spacing: 8) {
                    FlockSheepView(
                        definition: FlockService.regularSheepDefinition(at: state.regularCount),
                        isAwake: true,
                        size: 32
                    )
                    .opacity(0.35)
                    Text(String(localized: "#writeToUnlockSheep"))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                }

                Divider()

                // Special sheep progress
                Text(String(localized: "#nextSpecialSheep"))
                    .font(.custom(AppFonts.bold, size: 17))
                    .foregroundColor(.textPrimary)
                progressRow(
                    progress: state.progressToNextSpecial,
                    detail: String(localized: "#specialEntriesRemaining\(state.daysToNextSpecial)"),
                    tint: Color(red: 1.0, green: 0.85, blue: 0.25)
                )
                HStack(spacing: 8) {
                    FlockSheepView(
                        definition: FlockService.specialSheepDefinition(at: state.specialCount),
                        isAwake: true,
                        size: 32
                    )
                    .opacity(0.35)
                    Text(String(localized: "#writeToUnlockSheep"))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                }
            } else {
                Text(String(localized: "#sheepAllSleeping"))
                    .font(.custom(AppFonts.medium, size: 13))
                    .foregroundColor(.warmAccent)
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    // MARK: - Departed Card

    private func departedCard(state: FlockState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "#departedSheep"))
                .font(.custom(AppFonts.bold, size: 17))
                .foregroundColor(.textPrimary)

            Text(String(localized: "#departedSheepCount\(state.ghostSheep.count)"))
                .font(.custom(AppFonts.regular, size: 13))
                .foregroundColor(.textSecondary)

            HStack(spacing: 8) {
                ForEach(Array(state.ghostSheep.prefix(3).enumerated()), id: \.element.id) { _, sheep in
                    FlockSheepView(definition: sheep, isAwake: state.isAwake, size: 36, isGhost: true)
                }
                if state.ghostSheep.count > 3 {
                    Text("+\(state.ghostSheep.count - 3)")
                        .font(.custom(AppFonts.medium, size: 14))
                        .foregroundColor(.textSecondary)
                }
            }

            Button {
                Task {
                    do {
                        try await storeService.purchase()
                    } catch {
                        purchaseError = error.localizedDescription
                    }
                }
            } label: {
                Text(String(localized: "#unlockFullFlock"))
                    .font(.custom(AppFonts.bold, size: 15))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accent)
                    .cornerRadius(12)
            }

            Button {
                Task { await storeService.restore() }
            } label: {
                Text(String(localized: "#restorePurchases"))
                    .font(.custom(AppFonts.regular, size: 13))
                    .foregroundColor(.accent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
        .alert("Error", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Stats Card

    private func statsCard(state: FlockState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "#stats"))
                .font(.custom(AppFonts.bold, size: 17))
                .foregroundColor(.textPrimary)

            HStack(spacing: 0) {
                statItem(
                    label: String(localized: "#currentStreak"),
                    value: "\(state.currentStreak)"
                )
                Spacer()
                statItem(
                    label: String(localized: "#longestStreak"),
                    value: "\(state.bestStreak)"
                )
                Spacer()
                statItem(
                    label: String(localized: "#totalEntries"),
                    value: "\(state.totalEntries)"
                )
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom(AppFonts.bold, size: 24))
                .foregroundColor(.accent)
            Text(label)
                .font(.custom(AppFonts.regular, size: 12))
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Progress Row

    private func progressRow(progress: Double, detail: String, tint: Color = .accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(detail)
                .font(.custom(AppFonts.regular, size: 12))
                .foregroundColor(.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tint)
                        .frame(width: max(geo.size.width * progress, 4), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
