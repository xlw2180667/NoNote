import SwiftUI

struct FlockDetailView: View {
    let diaryDates: Set<String>
    @Environment(\.dismiss) private var dismiss

    private var flockState: FlockState {
        FlockService.computeFlockState(diaryDates: diaryDates)
    }

    var body: some View {
        let state = flockState
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection(state: state)
                    pastureScene(state: state)
                    regularTrackCard(state: state)
                    specialTrackCard(state: state)
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
        }
    }

    // MARK: - Header

    private func headerSection(state: FlockState) -> some View {
        VStack(spacing: 4) {
            Text("\(state.allUnlocked.count)")
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

    private func pastureScene(state: FlockState) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .bottom) {
                // Sky
                LinearGradient(
                    colors: [
                        Color(red: 0.75, green: 0.88, blue: 0.98),
                        Color(red: 0.82, green: 0.94, blue: 0.82)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Grass
                ZStack(alignment: .bottom) {
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

                // Sheep grid — rows of 5
                let sheep = state.allUnlocked
                let rows = stride(from: 0, to: sheep.count, by: 5).map { i in
                    Array(sheep[i..<min(i + 5, sheep.count)])
                }
                VStack(spacing: 4) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                        HStack(spacing: 8) {
                            ForEach(row, id: \.id) { s in
                                VStack(spacing: 2) {
                                    FlockSheepView(definition: s, isAwake: state.isAwake, size: 40)
                                    Text(String(localized: String.LocalizationValue(s.nameKey)))
                                        .font(.custom(AppFonts.regular, size: 9))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        .offset(y: CGFloat(rowIdx % 2 == 0 ? 0 : 6))
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Regular Track

    private func regularTrackCard(state: FlockState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "#flockTrack"))
                    .font(.custom(AppFonts.bold, size: 17))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(String(localized: "#totalEntriesCount\(state.totalEntries)"))
                    .font(.custom(AppFonts.regular, size: 13))
                    .foregroundColor(.textSecondary)
            }

            // Progress bar
            if let next = state.nextRegularMilestone {
                progressRow(
                    progress: state.progressToNextRegular,
                    label: String(localized: "#nextSheep"),
                    detail: String(localized: "#entriesRemaining\(next.threshold - state.totalEntries)")
                )
                // Preview of next sheep
                HStack(spacing: 8) {
                    FlockSheepView(definition: next, isAwake: true, size: 32)
                        .opacity(0.35)
                    Text(String(localized: String.LocalizationValue(next.nameKey)))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                }
            } else {
                Text(String(localized: "#allSheepUnlocked"))
                    .font(.custom(AppFonts.medium, size: 13))
                    .foregroundColor(.accent)
            }

            // Horizontal scroll of all regular sheep
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FlockService.regularSheep, id: \.id) { sheep in
                        let unlocked = state.unlockedRegular.contains { $0.id == sheep.id }
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottomTrailing) {
                                FlockSheepView(definition: sheep, isAwake: true, size: 36)
                                    .opacity(unlocked ? 1.0 : 0.3)
                                if unlocked {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.accent)
                                        .offset(x: 2, y: 2)
                                }
                            }
                            Text(String(localized: String.LocalizationValue(sheep.nameKey)))
                                .font(.custom(AppFonts.regular, size: 10))
                                .foregroundColor(unlocked ? .textPrimary : .textSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    // MARK: - Special Track

    private func specialTrackCard(state: FlockState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "#specialSheepTrack"))
                    .font(.custom(AppFonts.bold, size: 17))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(String(localized: "#bestStreakCount\(state.bestStreak)"))
                    .font(.custom(AppFonts.regular, size: 13))
                    .foregroundColor(.textSecondary)
            }

            if let next = state.nextSpecialMilestone {
                progressRow(
                    progress: state.progressToNextSpecial,
                    label: String(localized: "#nextSheep"),
                    detail: String(localized: "#streakDaysNeeded\(next.threshold)")
                )
                HStack(spacing: 8) {
                    FlockSheepView(definition: next, isAwake: true, size: 32)
                        .opacity(0.35)
                    Text(String(localized: String.LocalizationValue(next.nameKey)))
                        .font(.custom(AppFonts.regular, size: 12))
                        .foregroundColor(.textSecondary)
                }
            } else {
                Text(String(localized: "#allSheepUnlocked"))
                    .font(.custom(AppFonts.medium, size: 13))
                    .foregroundColor(.accent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(FlockService.specialSheep, id: \.id) { sheep in
                        let unlocked = state.unlockedSpecial.contains { $0.id == sheep.id }
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottomTrailing) {
                                FlockSheepView(definition: sheep, isAwake: true, size: 36)
                                    .opacity(unlocked ? 1.0 : 0.3)
                                if unlocked {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.accent)
                                        .offset(x: 2, y: 2)
                                }
                            }
                            Text(String(localized: String.LocalizationValue(sheep.nameKey)))
                                .font(.custom(AppFonts.regular, size: 10))
                                .foregroundColor(unlocked ? .textPrimary : .textSecondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    // MARK: - Progress Row

    private func progressRow(progress: Double, label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.custom(AppFonts.medium, size: 13))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(detail)
                    .font(.custom(AppFonts.regular, size: 12))
                    .foregroundColor(.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accent)
                        .frame(width: max(geo.size.width * progress, 4), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
