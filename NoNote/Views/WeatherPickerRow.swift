import SwiftUI

struct WeatherPickerRow: View {
    @Binding var selectedWeather: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "#weather"))
                .font(.custom(AppFonts.medium, size: 14))
                .foregroundColor(.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WeatherCondition.allCases, id: \.self) { condition in
                        let code = condition.wmoCode
                        let isSelected = selectedWeather == code
                        Button(action: {
                            if isSelected {
                                selectedWeather = nil
                            } else {
                                selectedWeather = code
                            }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: condition.sfSymbol)
                                    .font(.system(size: 22))
                                    .foregroundColor(isSelected ? condition.color : .textSecondary)
                                    .frame(width: 24, height: 24)
                                Text(String(localized: String.LocalizationValue(condition.labelKey)))
                                    .font(.custom(AppFonts.regular, size: 10))
                                    .foregroundColor(isSelected ? .accent : .textSecondary)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.accent.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.accent : Color.clear, lineWidth: 1.5)
                            )
                        }
                    }
                }
            }
        }
    }
}
