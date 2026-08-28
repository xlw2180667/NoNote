#if DEBUG
import SwiftUI

/// QA-only sheet: every costume on the same sheep, so the placement table in
/// `SheepCostume.placement` can be eyeballed at once. Reachable with
/// `-DemoScreen costumes`. Never compiled into a release build.
struct CostumeGalleryView: View {
    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(SheepCostume.allCases, id: \.self) { costume in
                    VStack(spacing: 4) {
                        FlockSheepView(
                            definition: SheepDefinition(
                                id: "gallery_\(costume.rawValue)",
                                woolColor: Color(red: 0.98, green: 0.96, blue: 0.90),
                                accessory: .none,
                                isSpecial: false,
                                costume: costume),
                            isAwake: true,
                            size: 84)
                        Text(String(localized: String.LocalizationValue(costume.localizedNameKey)))
                            .font(.custom(AppFonts.regular, size: 11))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(height: 118)
                }
            }
            .padding(16)
        }
        .background(Color.surface.ignoresSafeArea())
    }
}
#endif
