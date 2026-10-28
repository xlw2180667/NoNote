import SwiftUI
import UsageKit

/// Dress Up: what the mood sheep wear and which icon sits on the home screen.
///
/// Free users can try everything — the previews change as they tap — and only keeping a look
/// needs Pro. Trying first is the point: the first locked sheep in the flock needs a 35-day
/// streak, so until now most free users never saw anything Pro had to offer.
struct AppearanceView: View {
    @ObservedObject var storeService: StoreService
    @ObservedObject private var synced = SyncedSettings.shared

    @State private var previewCostume: SheepCostume?
    @State private var previewIcon: AppIconChoice?
    @State private var currentIcon = AppIconChoice.current

    private var activeCostume: SheepCostume {
        previewCostume ?? (storeService.isPro ? synced.moodSheepCostume : .none)
    }

    private var activeIcon: AppIconChoice { previewIcon ?? currentIcon }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                moodSheepCard
                iconCard
                if !storeService.isPro {
                    ProUnlockCard(storeService: storeService, source: .dressUp) {
                        applyPreviews()
                    }
                }
            }
            .padding(16)
        }
        .background(Color.surface.ignoresSafeArea())
        .navigationTitle(String(localized: "#dressUp"))
        .navigationBarTitleDisplayMode(.inline)
        .usageScreen(DiaryScreen.dressUp)
    }

    // MARK: - Mood sheep

    private var moodSheepCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "#calendarSheep"))
                .font(.custom(AppFonts.bold, size: 16))
                .foregroundColor(.textPrimary)

            HStack {
                ForEach(SheepMood.all, id: \.id) { mood in
                    DressedMoodSheep(mood: mood.id, size: 48, costume: activeCostume)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)

            calendarStrip

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(SheepCostume.allCases, id: \.self) { costume in
                        costumeButton(costume)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    /// The same sheep at calendar size, so nobody is surprised by how small they get there.
    private var calendarStrip: some View {
        HStack {
            ForEach(Array(SheepMood.all.enumerated()), id: \.offset) { index, mood in
                VStack(spacing: 1) {
                    Text("\(index + 12)")
                        .font(.custom(AppFonts.medium, size: 14))
                        .foregroundColor(.textPrimary)
                        .frame(width: 28, height: 28)
                    DressedMoodSheep(mood: mood.id, size: 12, costume: activeCostume)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
        .background(Color.surface)
        .cornerRadius(10)
    }

    private func costumeButton(_ costume: SheepCostume) -> some View {
        let isSelected = activeCostume == costume
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { previewCostume = costume }
            if storeService.isPro {
                synced.moodSheepCostume = costume
                UsageStats.shared.record(DiaryUsageEvent.moodSheepChanged)
            } else if costume != .none {
                UsageStats.shared.record(DiaryUsageEvent.lockedMoodSheep)
            }
        } label: {
            Group {
                if let placement = costume.placement {
                    Image(placement.asset)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "circle.slash")
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Circle().fill(isSelected ? Color.accent.opacity(0.15) : Color.surface))
            .overlay(
                Circle().stroke(isSelected ? Color.accent : Color.textSecondary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1)
            )
        }
        .accessibilityLabel(String(localized: String.LocalizationValue(costume.localizedNameKey)))
    }

    // MARK: - App icon

    private var iconCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "#appIcon"))
                .font(.custom(AppFonts.bold, size: 16))
                .foregroundColor(.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                ForEach(AppIconChoice.allCases) { icon in
                    iconButton(icon)
                }
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }

    private func iconButton(_ icon: AppIconChoice) -> some View {
        let isSelected = activeIcon == icon
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { previewIcon = icon }
            if storeService.isPro {
                setIcon(icon)
            } else if icon != .classic {
                UsageStats.shared.record(DiaryUsageEvent.lockedIcon)
            }
        } label: {
            VStack(spacing: 6) {
                Image(icon.previewAsset)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 2.5)
                            .padding(-3)
                    )
                Text(String(localized: String.LocalizationValue(icon.localizedNameKey)))
                    .font(.custom(AppFonts.regular, size: 12))
                    .foregroundColor(isSelected ? .accent : .textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func setIcon(_ icon: AppIconChoice) {
        guard icon != AppIconChoice.current else { return }
        Task {
            // The system confirms the change with its own alert; nothing to show on failure,
            // the old icon simply stays.
            try? await UIApplication.shared.setAlternateIconName(icon.iconName)
            currentIcon = AppIconChoice.current
            if currentIcon == icon { UsageStats.shared.record(DiaryUsageEvent.iconChanged) }
        }
    }

    /// After buying, keep what was being tried on rather than making the user pick it again.
    private func applyPreviews() {
        if let previewCostume {
            synced.moodSheepCostume = previewCostume
            UsageStats.shared.record(DiaryUsageEvent.moodSheepChanged)
        }
        if let previewIcon { setIcon(previewIcon) }
    }
}

/// The one Pro pitch used by every new look: what you get, and the button.
struct ProUnlockCard: View {
    @ObservedObject var storeService: StoreService
    let source: DiaryPaywallSource
    /// Called once the purchase went through.
    var onUnlocked: () -> Void = {}

    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 10) {
            Text(String(localized: "#proFeature"))
                .font(.custom(AppFonts.bold, size: 13))
                .foregroundColor(.warmAccent)
            Text(String(localized: "#proLooksDescription"))
                .font(.custom(AppFonts.regular, size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                UsageStats.shared.recordPaywall(source)
                Task {
                    do {
                        try await storeService.purchase(source: source)
                        if storeService.isPro { onUnlocked() }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                Text(String(localized: "#unlockPro"))
                    .font(.custom(AppFonts.bold, size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 11)
                    .background(Color.accent)
                    .cornerRadius(10)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.custom(AppFonts.regular, size: 12))
                    .foregroundColor(.danger)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(16)
    }
}
