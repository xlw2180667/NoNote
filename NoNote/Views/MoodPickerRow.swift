import SwiftUI

struct MoodPickerRow: View {
    @Binding var selectedMood: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "#howAreYouFeeling"))
                .font(.custom(AppFonts.medium, size: 14))
                .foregroundColor(.textSecondary)

            HStack(spacing: 10) {
                ForEach(SheepMood.all, id: \.id) { mood in
                    Button(action: {
                        if selectedMood == mood.id {
                            selectedMood = nil
                        } else {
                            selectedMood = mood.id
                        }
                    }) {
                        VStack(spacing: 4) {
                            SheepMoodIcon(mood: mood.id, size: 36)
                            Text(String(localized: String.LocalizationValue(mood.labelKey)))
                                .font(.custom(AppFonts.regular, size: 11))
                                .foregroundColor(selectedMood == mood.id ? .accent : .textSecondary)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedMood == mood.id ? Color.accent.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedMood == mood.id ? Color.accent : Color.clear, lineWidth: 1.5)
                        )
                    }
                }
            }
        }
    }
}
