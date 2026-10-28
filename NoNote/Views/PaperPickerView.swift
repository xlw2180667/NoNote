import SwiftUI
import UsageKit

/// Paper picker, shown as a short sheet over the editor so each paper is tried on the
/// entry being written. `preview` is the editor's: it shows that paper until the sheet closes,
/// then falls back to the saved one — which, for a free user, is plain.
struct PaperPickerView: View {
    @ObservedObject var storeService: StoreService
    @Binding var preview: PaperTheme?
    @ObservedObject private var synced = SyncedSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    private var active: PaperTheme {
        preview ?? (storeService.isPro ? synced.paperTheme : .plain)
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(String(localized: "#paper"))
                .font(.custom(AppFonts.bold, size: 16))
                .foregroundColor(.textPrimary)
                .padding(.top, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PaperTheme.allCases) { theme in
                        swatch(theme)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 3)
            }

            if !storeService.isPro {
                ProUnlockCard(storeService: storeService, source: .paper) {
                    if let preview { synced.paperTheme = preview }
                }
                .padding(.horizontal, 16)
            }
            Spacer(minLength: 0)
        }
        .background(Color.surface.ignoresSafeArea())
        .usageScreen(DiaryScreen.paper)
    }

    private func swatch(_ theme: PaperTheme) -> some View {
        let isSelected = active == theme
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { preview = theme }
            if storeService.isPro {
                synced.paperTheme = theme
                UsageStats.shared.record(DiaryUsageEvent.paperChanged)
            } else if theme != .plain {
                UsageStats.shared.record(DiaryUsageEvent.lockedPaper)
            }
        } label: {
            VStack(spacing: 6) {
                PaperBackground(theme: theme)
                    .overlay {
                        Text("Aa")
                            .font(theme.font(size: 20))
                            .foregroundColor(theme.ink)
                    }
                    .environment(\.colorScheme, theme.forcedColorScheme ?? colorScheme)
                    .frame(width: 64, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isSelected ? Color.accent : Color.textSecondary.opacity(0.25),
                                    lineWidth: isSelected ? 2.5 : 1)
                    )
                Text(String(localized: String.LocalizationValue(theme.localizedNameKey)))
                    .font(.custom(AppFonts.regular, size: 12))
                    .foregroundColor(isSelected ? .accent : .textSecondary)
            }
        }
    }
}
